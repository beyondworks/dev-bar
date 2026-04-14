import Foundation

struct BarSlot: Identifiable, Hashable {
    let id: UUID
    var label: String
    var pid: pid_t
    var bundleIdentifier: String?
    var appName: String
    var windowTitle: String
    var status: SlotStatus
    var badgeCount: Int
    /// Non-nil means the window is currently stashed off-screen; value is the
    /// on-screen position to restore to when the user shows it again.
    var stashedPosition: CGPoint?

    init(
        id: UUID = UUID(),
        label: String,
        pid: pid_t,
        bundleIdentifier: String?,
        appName: String,
        windowTitle: String,
        status: SlotStatus = .idle,
        badgeCount: Int = 0,
        stashedPosition: CGPoint? = nil
    ) {
        self.id = id
        self.label = label
        self.pid = pid
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.windowTitle = windowTitle
        self.status = status
        self.badgeCount = badgeCount
        self.stashedPosition = stashedPosition
    }
}

enum SlotStatus: String, Codable, CaseIterable {
    case idle
    case working
    case waitingInput
    case error
    case done
}

struct WorkspaceGroup: Identifiable, Hashable {
    let id: UUID
    var name: String
    var slotIDs: [UUID]
}
