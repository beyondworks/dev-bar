import AppKit
import ApplicationServices
import UserNotifications

/// Observes AX-level window events for each registered slot and bumps the
/// slot's badge when activity happens while the window is not frontmost.
///
/// Current signals (MVP):
/// - Window title change (`kAXTitleChangedNotification`) — works for terminals
///   that set window title on command completion, VS Code dirty indicator, etc.
@MainActor
final class ActivityMonitor {
    static let shared = ActivityMonitor()
    private init() {}

    private final class Entry {
        let slotID: UUID
        let pid: pid_t
        let observer: AXObserver
        let element: AXUIElement
        var lastTitle: String
        var idleTimer: DispatchSourceTimer?
        init(slotID: UUID, pid: pid_t, observer: AXObserver, element: AXUIElement, lastTitle: String) {
            self.slotID = slotID
            self.pid = pid
            self.observer = observer
            self.element = element
            self.lastTitle = lastTitle
        }
    }

    /// Time without title changes after which a slot is reset from .working → .idle.
    private let idleResetSeconds: TimeInterval = 3.0

    private var entries: [UUID: Entry] = [:]
    private weak var store: BarStore?
    private var notificationsAuthorized = false
    private var appTerminateObserver: NSObjectProtocol?

    func configure(store: BarStore) {
        self.store = store
        requestNotificationAuthorization()
        observeAppTermination()
    }

    private func observeAppTermination() {
        guard appTerminateObserver == nil else { return }
        appTerminateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let pid = app.processIdentifier
            Task { @MainActor in
                self?.store?.removeSlots(matchingPID: pid)
            }
        }
    }

    // MARK: - Public API

    func watch(_ slot: BarSlot) {
        guard entries[slot.id] == nil else { return }
        guard let window = WindowManager.findAXWindow(pid: slot.pid, windowTitle: slot.windowTitle, cgWindowID: slot.cgWindowID) else {
            NSLog("[DevBar] ActivityMonitor.watch: no AX window for pid=\(slot.pid) title=\(slot.windowTitle)")
            return
        }

        var observer: AXObserver?
        let createResult = AXObserverCreate(slot.pid, axCallback, &observer)
        guard createResult == .success, let obs = observer else {
            NSLog("[DevBar] ActivityMonitor.watch: AXObserverCreate failed rc=\(createResult.rawValue) pid=\(slot.pid)")
            return
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let addResult = AXObserverAddNotification(obs, window, kAXTitleChangedNotification as CFString, refcon)
        guard addResult == .success else {
            NSLog("[DevBar] ActivityMonitor.watch: AXObserverAddNotification failed rc=\(addResult.rawValue) title=\(slot.windowTitle)")
            return
        }

        // Additional signals:
        //  - focused-window change (ambient activity)
        //  - window destroyed (user closed the window while the app is alive;
        //    app-level termination is caught by NSWorkspace above).
        _ = AXObserverAddNotification(obs, window, kAXFocusedWindowChangedNotification as CFString, refcon)
        _ = AXObserverAddNotification(obs, window, kAXUIElementDestroyedNotification as CFString, refcon)

        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(obs),
            .defaultMode
        )

        entries[slot.id] = Entry(
            slotID: slot.id,
            pid: slot.pid,
            observer: obs,
            element: window,
            lastTitle: titleOf(window) ?? slot.windowTitle
        )
        NSLog("[DevBar] ActivityMonitor.watch: subscribed pid=\(slot.pid) title=\(slot.windowTitle)")
    }

    func unwatch(_ slotID: UUID) {
        guard let entry = entries.removeValue(forKey: slotID) else { return }
        entry.idleTimer?.cancel()
        AXObserverRemoveNotification(entry.observer, entry.element, kAXTitleChangedNotification as CFString)
        CFRunLoopRemoveSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(entry.observer),
            .defaultMode
        )
    }

    // MARK: - Callback entry point

    /// Called by the C callback when the window element is destroyed.
    func handleWindowDestroyed(pid: pid_t, element: AXUIElement) {
        // AX element identity may not be stable; also remove by pid+entry id
        // fallback. We pick the first matching entry by pid.
        let matched = entries.values.first(where: { $0.pid == pid && CFEqual($0.element, element) })
            ?? entries.values.first(where: { $0.pid == pid })
        guard let entry = matched else { return }
        store?.removeSlot(id: entry.slotID)
    }

    /// Called by the C callback (hopped to main actor).
    func handleTitleChange(pid: pid_t, element: AXUIElement) {
        // Be lenient: some apps re-create the AXUIElement so CFEqual may fail.
        // Fall back to matching by pid alone if the element identity doesn't match.
        let entry = entries.values.first(where: { $0.pid == pid && CFEqual($0.element, element) })
            ?? entries.values.first(where: { $0.pid == pid })
        guard let entry else {
            NSLog("[DevBar] ActivityMonitor.handleTitleChange: no entry for pid=\(pid)")
            return
        }
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let newTitle = titleOf(entry.element) ?? entry.lastTitle
        NSLog("[DevBar] ActivityMonitor.handleTitleChange: pid=\(pid) old=\(entry.lastTitle) new=\(newTitle) front=\(frontPID ?? -1)")
        defer { entry.lastTitle = newTitle }
        guard newTitle != entry.lastTitle else { return }

        // Any title change = activity. Mark as working (green dot) and schedule
        // a reset back to .idle after `idleResetSeconds` of no further changes.
        store?.updateStatus(id: entry.slotID, status: .working)
        scheduleIdleReset(for: entry)

        // Badge bump + system notification only when the slot's window isn't
        // currently frontmost — avoids noise from the user actively working.
        guard pid != frontPID else { return }
        store?.bumpBadge(id: entry.slotID)
        postSystemNotification(for: entry.slotID, title: newTitle)
    }

    private func scheduleIdleReset(for entry: Entry) {
        entry.idleTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + idleResetSeconds)
        let slotID = entry.slotID
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.store?.updateStatus(id: slotID, status: .idle)
            }
        }
        timer.resume()
        entry.idleTimer = timer
    }

    // MARK: - Helpers

    private func titleOf(_ element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    // MARK: - System notifications

    /// UserNotifications requires an .app bundle. SwiftPM raw binaries crash
    /// when calling `UNUserNotificationCenter.current()`, so we disable the
    /// popup path unless the process has a bundle identifier.
    private var notificationsAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    private func requestNotificationAuthorization() {
        guard notificationsAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            Task { @MainActor in self?.notificationsAuthorized = granted }
        }
    }

    private func postSystemNotification(for slotID: UUID, title newTitle: String) {
        guard notificationsAvailable, notificationsAuthorized else { return }
        guard let slot = store?.slots.first(where: { $0.id == slotID }) else { return }
        let content = UNMutableNotificationContent()
        content.title = slot.label.isEmpty ? slot.appName : slot.label
        content.body = newTitle
        content.sound = .default
        let request = UNNotificationRequest(identifier: slotID.uuidString + "-" + String(Int(Date().timeIntervalSince1970)),
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

// C callback — must be a function, not a closure.
private func axCallback(observer: AXObserver, element: AXUIElement, notification: CFString, refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    let monitor = Unmanaged<ActivityMonitor>.fromOpaque(refcon).takeUnretainedValue()
    var pid: pid_t = 0
    AXUIElementGetPid(element, &pid)

    let notifName = notification as String
    if notifName == (kAXUIElementDestroyedNotification as String) {
        Task { @MainActor in
            monitor.handleWindowDestroyed(pid: pid, element: element)
        }
        return
    }
    // Default: treat any other observed notification as "activity" and drive
    // the title-change path (also covers focused-window changes as a hint).
    Task { @MainActor in
        monitor.handleTitleChange(pid: pid, element: element)
    }
}
