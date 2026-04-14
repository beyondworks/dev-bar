import AppKit

final class AppMonitor {
    static let shared = AppMonitor()
    private init() {}

    func start() {
        // Future: subscribe to NSWorkspace.didLaunchApplicationNotification etc.
    }

    func runningAppsWithUI() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
}
