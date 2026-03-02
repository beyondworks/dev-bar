import ApplicationServices
import Foundation

enum PermissionChecker {
    static func checkAccessibility() -> String {
        let trusted = AXIsProcessTrusted()
        return "{\"accessibility\": \(trusted)}"
    }
}
