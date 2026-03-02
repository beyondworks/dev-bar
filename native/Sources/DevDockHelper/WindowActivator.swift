import AppKit
import ApplicationServices
import Foundation

enum WindowActivator {
    static func activate(pid: Int, windowTitle: String? = nil) -> String {
        guard let app = NSRunningApplication(processIdentifier: pid_t(pid)) else {
            return "{\"error\": \"No application found with PID \(pid)\"}"
        }

        // First, activate the app itself
        let appSuccess = app.activate(options: .activateIgnoringOtherApps)

        // If a specific window title is given, try to raise that window via AX API
        if let title = windowTitle, !title.isEmpty {
            let appRef = AXUIElementCreateApplication(pid_t(pid))
            var windowsRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef)
            if result == .success, let windows = windowsRef as? [AXUIElement] {
                for window in windows {
                    var titleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
                       let wTitle = titleRef as? String, wTitle == title {
                        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                        return "{\"success\": true, \"pid\": \(pid), \"raised\": \"\(title)\"}"
                    }
                }
                // Fuzzy match: title contains the search string
                for window in windows {
                    var titleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
                       let wTitle = titleRef as? String, wTitle.contains(title) || title.contains(wTitle) {
                        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                        return "{\"success\": true, \"pid\": \(pid), \"raised\": \"\(wTitle)\"}"
                    }
                }
            }
        }

        if appSuccess {
            return "{\"success\": true, \"pid\": \(pid)}"
        } else {
            return "{\"error\": \"Failed to activate application with PID \(pid)\"}"
        }
    }

    // MARK: - Window lookup helper

    private static func findWindow(pid: Int, windowTitle: String?) -> AXUIElement? {
        let appRef = AXUIElementCreateApplication(pid_t(pid))
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef)
        guard result == .success, let windows = windowsRef as? [AXUIElement] else { return nil }

        if let title = windowTitle, !title.isEmpty {
            // Exact match
            for window in windows {
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let wTitle = titleRef as? String, wTitle == title {
                    return window
                }
            }
            // Fuzzy match
            for window in windows {
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let wTitle = titleRef as? String, wTitle.contains(title) || title.contains(wTitle) {
                    return window
                }
            }
        }

        // No title specified or no match: return first window
        return windows.first
    }

    // MARK: - Minimize

    static func minimizeWindow(pid: Int, windowTitle: String? = nil) -> String {
        guard let window = findWindow(pid: pid, windowTitle: windowTitle) else {
            return "{\"error\": \"No window found for PID \(pid)\"}"
        }
        let result = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, true as CFTypeRef)
        if result == .success {
            return "{\"success\": true, \"pid\": \(pid), \"action\": \"minimized\"}"
        } else {
            return "{\"error\": \"Failed to minimize window for PID \(pid)\"}"
        }
    }

    // MARK: - Is Minimized

    static func isWindowMinimized(pid: Int, windowTitle: String? = nil) -> String {
        guard let window = findWindow(pid: pid, windowTitle: windowTitle) else {
            return "{\"error\": \"No window found for PID \(pid)\"}"
        }
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &valueRef)
        if result == .success, let minimized = valueRef as? Bool {
            return "{\"minimized\": \(minimized)}"
        }
        return "{\"minimized\": false}"
    }

    // MARK: - Toggle

    static func toggleWindow(pid: Int, windowTitle: String? = nil) -> String {
        guard let window = findWindow(pid: pid, windowTitle: windowTitle) else {
            return "{\"error\": \"No window found for PID \(pid)\"}"
        }

        // Check if minimized
        var valueRef: CFTypeRef?
        let minResult = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &valueRef)
        let isMinimized = (minResult == .success) && (valueRef as? Bool == true)

        if isMinimized {
            // Unminimize
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, false as CFTypeRef)
            // Activate the app to bring it forward
            if let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
                app.activate(options: .activateIgnoringOtherApps)
            }
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            return "{\"success\": true, \"pid\": \(pid), \"action\": \"unminimized\"}"
        }

        // Check if this app is frontmost
        if let app = NSRunningApplication(processIdentifier: pid_t(pid)), app.isActive {
            // Frontmost -> minimize
            let setResult = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, true as CFTypeRef)
            if setResult == .success {
                return "{\"success\": true, \"pid\": \(pid), \"action\": \"minimized\"}"
            } else {
                return "{\"error\": \"Failed to minimize window for PID \(pid)\"}"
            }
        }

        // Not minimized and not frontmost -> activate
        return activate(pid: pid, windowTitle: windowTitle)
    }
}
