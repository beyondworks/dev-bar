import CoreGraphics
import AppKit
import Foundation
import ApplicationServices

struct WindowInfo: Codable {
    let windowId: Int
    let ownerName: String
    let windowName: String
    let bundleId: String
    let pid: Int
    let bounds: WindowBounds
    let isOnScreen: Bool
}

struct WindowBounds: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

enum WindowLister {
    // Get window titles via AX API (works with Accessibility permission only)
    private static func getAXWindowTitles(pid: Int) -> [(title: String, bounds: CGRect)] {
        let appRef = AXUIElementCreateApplication(pid_t(pid))
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef)
        guard result == .success, let windows = windowsRef as? [AXUIElement] else { return [] }

        var entries: [(title: String, bounds: CGRect)] = []
        for window in windows {
            var titleRef: CFTypeRef?
            var posRef: CFTypeRef?
            var sizeRef: CFTypeRef?

            let title: String
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
               let t = titleRef as? String {
                title = t
            } else {
                title = ""
            }

            var pos = CGPoint.zero
            var size = CGSize.zero
            if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success {
                AXValueGetValue(posRef as! AXValue, .cgPoint, &pos)
            }
            if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success {
                AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
            }

            entries.append((title: title, bounds: CGRect(origin: pos, size: size)))
        }
        return entries
    }

    static func listWindows() -> [WindowInfo] {
        // Use .optionAll to include minimized / off-screen windows too
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        // Build maps from running apps
        var pidToBundleId: [Int: String] = [:]
        var pidToLocalizedName: [Int: String] = [:]
        var regularAppPids: Set<Int> = []
        for app in NSWorkspace.shared.runningApplications {
            let p = Int(app.processIdentifier)
            if let bundleId = app.bundleIdentifier {
                pidToBundleId[p] = bundleId
            }
            if let name = app.localizedName {
                pidToLocalizedName[p] = name
            }
            if app.activationPolicy == .regular {
                regularAppPids.insert(p)
            }
        }

        // Get our own pid to exclude DevDock itself
        let ownPid = Int(ProcessInfo.processInfo.processIdentifier)

        // Pre-fetch AX window titles per pid (cache to avoid duplicate calls)
        var axCache: [Int: [(title: String, bounds: CGRect)]] = [:]

        var results: [WindowInfo] = []

        for info in windowList {
            let layer = info[kCGWindowLayer as String] as? Int ?? -1
            guard layer == 0 else { continue }

            let pid = info[kCGWindowOwnerPID as String] as? Int ?? 0
            guard pid != ownPid else { continue }
            guard regularAppPids.contains(pid) else { continue }

            let windowId = info[kCGWindowNumber as String] as? Int ?? 0
            let cgOwnerName = info[kCGWindowOwnerName as String] as? String ?? ""
            let cgWindowName = info[kCGWindowName as String] as? String ?? ""
            let isOnScreen = info[kCGWindowIsOnscreen as String] as? Bool ?? false
            let bundleId = pidToBundleId[pid] ?? ""

            var bounds = WindowBounds(x: 0, y: 0, width: 0, height: 0)
            if let boundsDict = info[kCGWindowBounds as String] as? [String: Any] {
                let rect = CGRect(
                    x: boundsDict["X"] as? Double ?? 0,
                    y: boundsDict["Y"] as? Double ?? 0,
                    width: boundsDict["Width"] as? Double ?? 0,
                    height: boundsDict["Height"] as? Double ?? 0
                )
                bounds = WindowBounds(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height)
            }

            // Skip tiny windows (menu bar extras, status items, etc.)
            guard bounds.width >= 100 && bounds.height >= 100 else { continue }

            // Use localizedName (e.g., "Visual Studio Code") instead of process name ("Code")
            let ownerName = pidToLocalizedName[pid] ?? cgOwnerName

            // Try to get window title from AX API when CG returns empty
            var windowName = cgWindowName
            if windowName.isEmpty {
                if axCache[pid] == nil {
                    axCache[pid] = getAXWindowTitles(pid: pid)
                }
                let axWindows = axCache[pid] ?? []
                let cgRect = CGRect(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height)
                // Pass 1: tight match (position + size)
                for ax in axWindows {
                    if abs(ax.bounds.origin.x - cgRect.origin.x) < 10 &&
                       abs(ax.bounds.origin.y - cgRect.origin.y) < 40 &&
                       abs(ax.bounds.size.width - cgRect.size.width) < 10 &&
                       abs(ax.bounds.size.height - cgRect.size.height) < 10 {
                        windowName = ax.title
                        break
                    }
                }
                // Pass 2: generous tolerance for dual-monitor coordinate drift
                if windowName.isEmpty {
                    for ax in axWindows {
                        if abs(ax.bounds.origin.x - cgRect.origin.x) < 30 &&
                           abs(ax.bounds.size.width - cgRect.size.width) < 30 &&
                           abs(ax.bounds.size.height - cgRect.size.height) < 30 {
                            windowName = ax.title
                            break
                        }
                    }
                }
                // Pass 3: size-only match (when only one AX window has similar size)
                if windowName.isEmpty {
                    let sizeMatches = axWindows.filter {
                        abs($0.bounds.size.width - cgRect.size.width) < 50 &&
                        abs($0.bounds.size.height - cgRect.size.height) < 50
                    }
                    if sizeMatches.count == 1 {
                        windowName = sizeMatches[0].title
                    }
                }
                // Pass 4: single window fallback (app has only one window)
                if windowName.isEmpty && axWindows.count == 1 {
                    windowName = axWindows[0].title
                }
            }

            // Skip auxiliary windows: offscreen with no meaningful title
            if windowName.isEmpty && !isOnScreen { continue }

            results.append(WindowInfo(
                windowId: windowId,
                ownerName: ownerName,
                windowName: windowName,
                bundleId: bundleId,
                pid: pid,
                bounds: bounds,
                isOnScreen: isOnScreen
            ))
        }

        return results
    }

    static func jsonOutput() -> String {
        let windows = listWindows()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(windows), let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "[]"
    }

    // MARK: - Installed Apps

    private struct InstalledApp: Codable {
        let bundleId: String
        let appName: String
    }

    static func listInstalledApps() -> String {
        let fileManager = FileManager.default
        var appDirs = ["/Applications", "/Applications/Utilities"]
        if let home = ProcessInfo.processInfo.environment["HOME"] {
            appDirs.append("\(home)/Applications")
        }

        var seen = Set<String>()
        var apps: [InstalledApp] = []

        for dir in appDirs {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents {
                guard item.hasSuffix(".app") else { continue }
                let appPath = "\(dir)/\(item)"

                // Filter out helper apps (bundles nested inside other bundles)
                // Only process top-level .app bundles in the scanned directories
                let plistPath = "\(appPath)/Contents/Info.plist"
                guard let plistData = fileManager.contents(atPath: plistPath),
                      let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
                      let bundleId = plist["CFBundleIdentifier"] as? String else {
                    continue
                }

                // Skip duplicates
                guard !seen.contains(bundleId) else { continue }
                seen.insert(bundleId)

                let appName = (plist["CFBundleDisplayName"] as? String)
                    ?? (plist["CFBundleName"] as? String)
                    ?? item.replacingOccurrences(of: ".app", with: "")

                apps.append(InstalledApp(bundleId: bundleId, appName: appName))
            }
        }

        // Sort by app name for consistent output
        apps.sort { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(apps), let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "[]"
    }

    static func frontmostWindow() -> String {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return "{\"error\": \"No frontmost application\"}"
        }

        let pid = Int(frontApp.processIdentifier)
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return "{\"error\": \"Could not list windows\"}"
        }

        let localizedName = frontApp.localizedName ?? ""
        let axWindows = getAXWindowTitles(pid: pid)

        for info in windowList {
            let windowPid = info[kCGWindowOwnerPID as String] as? Int ?? 0
            let layer = info[kCGWindowLayer as String] as? Int ?? -1
            guard windowPid == pid, layer == 0 else { continue }

            let windowId = info[kCGWindowNumber as String] as? Int ?? 0
            let cgOwnerName = info[kCGWindowOwnerName as String] as? String ?? ""
            var windowName = info[kCGWindowName as String] as? String ?? ""
            let bundleId = frontApp.bundleIdentifier ?? ""
            let isOnScreen = info[kCGWindowIsOnscreen as String] as? Bool ?? false
            let ownerName = localizedName.isEmpty ? cgOwnerName : localizedName

            var bounds = WindowBounds(x: 0, y: 0, width: 0, height: 0)
            if let boundsDict = info[kCGWindowBounds as String] as? [String: Any] {
                let rect = CGRect(
                    x: boundsDict["X"] as? Double ?? 0,
                    y: boundsDict["Y"] as? Double ?? 0,
                    width: boundsDict["Width"] as? Double ?? 0,
                    height: boundsDict["Height"] as? Double ?? 0
                )
                bounds = WindowBounds(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height)
            }

            // Try AX API title match (same multi-pass as listWindows)
            if windowName.isEmpty {
                let cgRect = CGRect(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height)
                // Pass 1: tight match
                for ax in axWindows {
                    if abs(ax.bounds.origin.x - cgRect.origin.x) < 10 &&
                       abs(ax.bounds.origin.y - cgRect.origin.y) < 40 &&
                       abs(ax.bounds.size.width - cgRect.size.width) < 10 &&
                       abs(ax.bounds.size.height - cgRect.size.height) < 10 {
                        windowName = ax.title
                        break
                    }
                }
                // Pass 2: generous tolerance
                if windowName.isEmpty {
                    for ax in axWindows {
                        if abs(ax.bounds.origin.x - cgRect.origin.x) < 30 &&
                           abs(ax.bounds.size.width - cgRect.size.width) < 30 &&
                           abs(ax.bounds.size.height - cgRect.size.height) < 30 {
                            windowName = ax.title
                            break
                        }
                    }
                }
                // Pass 3: size-only match
                if windowName.isEmpty {
                    let sizeMatches = axWindows.filter {
                        abs($0.bounds.size.width - cgRect.size.width) < 50 &&
                        abs($0.bounds.size.height - cgRect.size.height) < 50
                    }
                    if sizeMatches.count == 1 {
                        windowName = sizeMatches[0].title
                    }
                }
                // Pass 4: single window fallback
                if windowName.isEmpty && axWindows.count == 1 {
                    windowName = axWindows[0].title
                }
            }

            let windowInfo = WindowInfo(
                windowId: windowId,
                ownerName: ownerName,
                windowName: windowName,
                bundleId: bundleId,
                pid: pid,
                bounds: bounds,
                isOnScreen: isOnScreen
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(windowInfo), let json = String(data: data, encoding: .utf8) {
                return json
            }
        }

        return "{\"error\": \"No window found for frontmost app\"}"
    }
}
