import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = BarStore()
    private let settings = SettingsStore()
    private var barController: BarPanelController?
    private var settingsController: SettingsWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        PermissionsHelper.requestAccessibilityIfNeeded()
        AppMonitor.shared.start()
        ActivityMonitor.shared.configure(store: store)

        settingsController = SettingsWindowController(settings: settings)

        let controller = BarPanelController(
            store: store,
            settings: settings,
            onOpenSettings: { [weak self] in self?.settingsController?.show() }
        )
        controller.start()
        barController = controller

        installStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "▦"
            button.toolTip = "Dev-bar"
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show / Hide Bar", action: #selector(toggleBar), keyEquivalent: "b"))
        menu.addItem(NSMenuItem(title: "설정…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Dev-bar", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    @objc private func toggleBar() {
        barController?.toggle()
    }

    @objc private func openSettings() {
        settingsController?.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
