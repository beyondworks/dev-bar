import ApplicationServices
import AppKit

enum PermissionsHelper {
    static func requestAccessibilityIfNeeded() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [key: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        if !trusted {
            NSLog("Dev-bar: Accessibility permission required. Grant it in System Settings → Privacy & Security → Accessibility.")
        }
    }

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }
}
