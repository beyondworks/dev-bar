import AppKit
import ApplicationServices

/// Private API: stable across macOS releases for many years; used by yabai,
/// Rectangle, etc. to get the CGWindowID backing an AXUIElement. We use it as
/// a stable identity for slots so that matching survives title changes
/// (e.g. VS Code retitles windows when switching active files).
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ axElement: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

enum WindowManager {
    static let offscreenAnchor = CGPoint(x: -32000, y: -32000)

    // MARK: - Lookups

    /// Returns the stable CGWindowID for the given (pid, title) — call this at
    /// slot creation time and persist it into `BarSlot.cgWindowID`.
    static func cgWindowID(pid: pid_t, windowTitle: String) -> CGWindowID? {
        guard let win = findWindow(pid: pid, windowTitle: windowTitle, cgWindowID: nil) else { return nil }
        return windowID(of: win)
    }

    static func listWindowTitles(pid: pid_t) -> [String] {
        guard let windows = copyWindows(pid: pid) else { return [] }
        return windows.compactMap { title(of: $0) }.filter { !$0.isEmpty }
    }

    // MARK: - Mutations

    @discardableResult
    static func focus(pid: pid_t, windowTitle: String?, cgWindowID: CGWindowID? = nil) -> Bool {
        guard let runningApp = NSRunningApplication(processIdentifier: pid) else { return false }
        let target = findWindow(pid: pid, windowTitle: windowTitle, cgWindowID: cgWindowID)
        runningApp.activate()
        guard let win = target else { return false }

        ensureOnScreen(win)

        var minimized: CFTypeRef?
        if AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minimized) == .success,
           let isMin = minimized as? Bool, isMin {
            AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        AXUIElementSetAttributeValue(win, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(win, kAXRaiseAction as CFString)
        return true
    }

    static func minimize(pid: pid_t, windowTitle: String?, cgWindowID: CGWindowID? = nil) {
        guard let win = findWindow(pid: pid, windowTitle: windowTitle, cgWindowID: cgWindowID) else { return }
        AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }

    static func getPosition(pid: pid_t, windowTitle: String?, cgWindowID: CGWindowID? = nil) -> CGPoint? {
        guard let win = findWindow(pid: pid, windowTitle: windowTitle, cgWindowID: cgWindowID) else { return nil }
        return position(of: win)
    }

    @discardableResult
    static func setPosition(pid: pid_t, windowTitle: String?, cgWindowID: CGWindowID? = nil, position: CGPoint) -> Bool {
        guard let win = findWindow(pid: pid, windowTitle: windowTitle, cgWindowID: cgWindowID) else { return false }
        var p = position
        guard let axValue = AXValueCreate(.cgPoint, &p) else { return false }
        return AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, axValue) == .success
    }

    static func isMinimized(pid: pid_t, windowTitle: String?, cgWindowID: CGWindowID? = nil) -> Bool {
        guard let win = findWindow(pid: pid, windowTitle: windowTitle, cgWindowID: cgWindowID) else { return false }
        var minimized: CFTypeRef?
        guard AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minimized) == .success,
              let isMin = minimized as? Bool else { return false }
        return isMin
    }

    /// Expose the matching function so callers (e.g. ActivityMonitor) can
    /// obtain the AXUIElement directly.
    static func findAXWindow(pid: pid_t, windowTitle: String?, cgWindowID: CGWindowID? = nil) -> AXUIElement? {
        findWindow(pid: pid, windowTitle: windowTitle, cgWindowID: cgWindowID)
    }

    // MARK: - Internals

    /// Prefer CGWindowID match (stable ID). Fall back to title. Last-resort
    /// falls back to the first window, but only when neither identifier is set
    /// — never when cgWindowID was provided but didn't match, since that
    /// would silently target the wrong window (the original bug for two
    /// VS Code windows).
    private static func findWindow(pid: pid_t, windowTitle: String?, cgWindowID: CGWindowID?) -> AXUIElement? {
        guard let windows = copyWindows(pid: pid) else { return nil }

        if let wantedID = cgWindowID {
            if let match = windows.first(where: { windowID(of: $0) == wantedID }) {
                return match
            }
            // cgWindowID was specified but not found — don't silently pick
            // another window. Fall through to title match only.
        }

        if let wantedTitle = windowTitle,
           let match = windows.first(where: { title(of: $0) == wantedTitle }) {
            return match
        }

        // Only use "first window" fallback when caller provided no identifier.
        if cgWindowID == nil && windowTitle == nil {
            return windows.first
        }
        return nil
    }

    private static func copyWindows(pid: pid_t) -> [AXUIElement]? {
        let appElement = AXUIElementCreateApplication(pid)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return nil }
        return windows
    }

    private static func windowID(of element: AXUIElement) -> CGWindowID? {
        var wid: CGWindowID = 0
        let result = _AXUIElementGetWindow(element, &wid)
        return (result == .success && wid != 0) ? wid : nil
    }

    private static func title(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func position(of element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success,
              let axValue = value else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    /// If the window sits entirely outside every connected screen (e.g. stashed
    /// via off-screen move but Dev-bar forgot the stash position across a
    /// relaunch), move it to the center of the primary display so the user
    /// can actually see it again.
    private static func ensureOnScreen(_ window: AXUIElement) {
        guard let point = position(of: window) else { return }
        let union = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        let tolerant = union.insetBy(dx: -50, dy: -50)
        guard !tolerant.contains(point) else { return }

        guard let main = NSScreen.main else { return }
        var newPoint = CGPoint(x: main.frame.midX - 400, y: main.frame.midY - 300)
        guard let axValue = AXValueCreate(.cgPoint, &newPoint) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axValue)
    }
}
