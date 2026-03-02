import Foundation

func printError(_ message: String) {
    print("{\"error\": \"\(message)\"}")
}

let args = CommandLine.arguments

guard args.count >= 2 else {
    printError("Usage: DevDockHelper <subcommand> [args]. Subcommands: list, frontmost, activate <pid>, minimize <pid>, toggle <pid>, is-minimized <pid>, check-perms, app-icon <bundleId>, list-apps")
    exit(1)
}

let subcommand = args[1]

switch subcommand {
case "list":
    print(WindowLister.jsonOutput())

case "frontmost":
    print(WindowLister.frontmostWindow())

case "activate":
    guard args.count >= 3, let pid = Int(args[2]) else {
        printError("activate requires a valid integer PID argument")
        exit(1)
    }
    let windowTitle = args.count >= 4 ? args[3] : nil
    print(WindowActivator.activate(pid: pid, windowTitle: windowTitle))

case "check-perms":
    print(PermissionChecker.checkAccessibility())

case "minimize":
    guard args.count >= 3, let pid = Int(args[2]) else {
        printError("minimize requires a valid integer PID argument")
        exit(1)
    }
    let windowTitle = args.count >= 4 ? args[3] : nil
    print(WindowActivator.minimizeWindow(pid: pid, windowTitle: windowTitle))

case "toggle":
    guard args.count >= 3, let pid = Int(args[2]) else {
        printError("toggle requires a valid integer PID argument")
        exit(1)
    }
    let windowTitle = args.count >= 4 ? args[3] : nil
    print(WindowActivator.toggleWindow(pid: pid, windowTitle: windowTitle))

case "is-minimized":
    guard args.count >= 3, let pid = Int(args[2]) else {
        printError("is-minimized requires a valid integer PID argument")
        exit(1)
    }
    let windowTitle = args.count >= 4 ? args[3] : nil
    print(WindowActivator.isWindowMinimized(pid: pid, windowTitle: windowTitle))

case "app-icon":
    guard args.count >= 3 else {
        printError("app-icon requires a bundleId argument")
        exit(1)
    }
    let bundleId = args[2]
    print(AppIconExtractor.extractIcon(bundleId: bundleId))

case "list-apps":
    print(WindowLister.listInstalledApps())

default:
    printError("Unknown subcommand: \(subcommand). Valid: list, frontmost, activate <pid>, minimize <pid>, toggle <pid>, is-minimized <pid>, check-perms, app-icon <bundleId>, list-apps")
    exit(1)
}
