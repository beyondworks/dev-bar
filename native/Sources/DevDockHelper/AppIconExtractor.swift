import AppKit
import Foundation

enum AppIconExtractor {
    static func extractIcon(bundleId: String) -> String {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return "{\"error\": \"Application not found for bundleId: \(bundleId)\"}"
        }

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        let size = NSSize(width: 32, height: 32)
        icon.size = size

        // Render into exact 32x32 bitmap to avoid oversized output
        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        icon.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: icon.size),
                  operation: .sourceOver, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return "{\"error\": \"Failed to convert icon to PNG for bundleId: \(bundleId)\"}"
        }

        let base64 = pngData.base64EncodedString()
        return "{\"bundleId\": \"\(bundleId)\", \"icon\": \"\(base64)\"}"
    }
}
