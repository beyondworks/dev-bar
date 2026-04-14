import AppKit
import ApplicationServices

enum WindowManager {
    @discardableResult
    static func focus(pid: pid_t, windowTitle: String?) -> Bool {
        guard let runningApp = NSRunningApplication(processIdentifier: pid) else { return false }
        let appElement = AXUIElementCreateApplication(pid)

        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)

        runningApp.activate()

        guard result == .success, let windows = windowsValue as? [AXUIElement] else {
            return false
        }

        let target = windows.first { window in
            guard let t = title(of: window), let wanted = windowTitle else { return false }
            return t == wanted
        } ?? windows.first

        guard let win = target else { return false }

        var minimized: CFTypeRef?
        if AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minimized) == .success,
           let isMin = minimized as? Bool, isMin {
            AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        AXUIElementSetAttributeValue(win, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(win, kAXRaiseAction as CFString)
        return true
    }

    static func minimize(pid: pid_t, windowTitle: String?) {
        let appElement = AXUIElementCreateApplication(pid)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return }
        let target = windows.first { window in
            guard let t = title(of: window), let wanted = windowTitle else { return false }
            return t == wanted
        } ?? windows.first
        if let win = target {
            AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        }
    }

    /// Offscreen anchor far outside any realistic display arrangement.
    static let offscreenAnchor = CGPoint(x: -32000, y: -32000)

    static func getPosition(pid: pid_t, windowTitle: String?) -> CGPoint? {
        guard let win = findWindow(pid: pid, windowTitle: windowTitle) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &value) == .success,
              let axValue = value else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    @discardableResult
    static func setPosition(pid: pid_t, windowTitle: String?, position: CGPoint) -> Bool {
        guard let win = findWindow(pid: pid, windowTitle: windowTitle) else { return false }
        var p = position
        guard let axValue = AXValueCreate(.cgPoint, &p) else { return false }
        return AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, axValue) == .success
    }

    private static func findWindow(pid: pid_t, windowTitle: String?) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(pid)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return nil }
        return windows.first { window in
            guard let t = title(of: window), let wanted = windowTitle else { return false }
            return t == wanted
        } ?? windows.first
    }

    static func isMinimized(pid: pid_t, windowTitle: String?) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return false }
        let target = windows.first { window in
            guard let t = title(of: window), let wanted = windowTitle else { return false }
            return t == wanted
        } ?? windows.first
        guard let win = target else { return false }
        var minimized: CFTypeRef?
        guard AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minimized) == .success,
              let isMin = minimized as? Bool else { return false }
        return isMin
    }

    static func listWindowTitles(pid: pid_t) -> [String] {
        let appElement = AXUIElementCreateApplication(pid)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return [] }
        return windows.compactMap { title(of: $0) }.filter { !$0.isEmpty }
    }

    private static func title(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
