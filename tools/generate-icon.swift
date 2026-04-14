#!/usr/bin/env swift

// Generates macOS .iconset PNGs for Dev-bar. Run:
//   swift tools/generate-icon.swift [output-dir]
// Default output-dir = build/AppIcon.iconset

import AppKit
import CoreGraphics
import Foundation

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "build/AppIcon.iconset"

try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

private func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }
    guard let ctx = NSGraphicsContext.current?.cgContext else { return image }

    // Squircle body (macOS app icon template bounds ~= 82% of canvas).
    let inset = size * 0.08
    let rect = CGRect(x: inset, y: inset, width: size - 2*inset, height: size - 2*inset)
    let corner = rect.width * 0.2237
    let bodyPath = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)

    // Background gradient: deep indigo → near-black, top-to-bottom.
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let grad = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            CGColor(red: 0.20, green: 0.22, blue: 0.42, alpha: 1) as CFTypeRef,
            CGColor(red: 0.07, green: 0.08, blue: 0.22, alpha: 1) as CFTypeRef
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])

    // Subtle top-edge highlight for depth.
    let highlight = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.22) as CFTypeRef,
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.0) as CFTypeRef
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        highlight,
        start: CGPoint(x: 0, y: rect.maxY),
        end: CGPoint(x: 0, y: rect.maxY - rect.height * 0.55),
        options: []
    )
    ctx.restoreGState()

    // Outer ring on the squircle for crisp edge at small sizes.
    ctx.addPath(bodyPath)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.06))
    ctx.setLineWidth(size * 0.005)
    ctx.strokePath()

    // Central "bar" (capsule shape).
    let barWidth = rect.width * 0.78
    let barHeight = rect.height * 0.26
    let barX = rect.midX - barWidth / 2
    let barY = rect.midY - barHeight / 2
    let barRect = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)
    let barCorner = barHeight * 0.5  // full capsule
    let barPath = CGPath(roundedRect: barRect, cornerWidth: barCorner, cornerHeight: barCorner, transform: nil)

    // Soft drop shadow under the bar.
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.01),
        blur: size * 0.04,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45)
    )
    ctx.addPath(barPath)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.14))
    ctx.fillPath()
    ctx.restoreGState()

    // Bar rim.
    ctx.addPath(barPath)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.32))
    ctx.setLineWidth(max(1, size * 0.006))
    ctx.strokePath()

    // Three status dots (left→right: red / yellow / green) — the slot signals.
    let dotD = barHeight * 0.58
    let dotY = barRect.midY - dotD / 2
    let gap = barHeight * 0.42
    let totalWidth = 3 * dotD + 2 * gap
    let startX = barRect.midX - totalWidth / 2

    let dotColors: [CGColor] = [
        CGColor(red: 1.00, green: 0.42, blue: 0.38, alpha: 1),
        CGColor(red: 1.00, green: 0.80, blue: 0.25, alpha: 1),
        CGColor(red: 0.36, green: 0.82, blue: 0.45, alpha: 1)
    ]
    for (i, color) in dotColors.enumerated() {
        let x = startX + CGFloat(i) * (dotD + gap)
        let frame = CGRect(x: x, y: dotY, width: dotD, height: dotD)
        // Dot highlight (soft top glow).
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: dotD * 0.35, color: color.copy(alpha: 0.6))
        ctx.setFillColor(color)
        ctx.fillEllipse(in: frame)
        ctx.restoreGState()

        // Sheen on top of dot.
        ctx.saveGState()
        ctx.addEllipse(in: frame)
        ctx.clip()
        let sheen = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                CGColor(red: 1, green: 1, blue: 1, alpha: 0.55) as CFTypeRef,
                CGColor(red: 1, green: 1, blue: 1, alpha: 0.0) as CFTypeRef
            ] as CFArray,
            locations: [0, 1]
        )!
        ctx.drawLinearGradient(
            sheen,
            start: CGPoint(x: frame.midX, y: frame.maxY),
            end: CGPoint(x: frame.midX, y: frame.midY),
            options: []
        )
        ctx.restoreGState()
    }

    return image
}

private func savePNG(_ image: NSImage, path: String) {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("Failed to encode \(path)\n".data(using: .utf8)!)
        return
    }
    do {
        try png.write(to: URL(fileURLWithPath: path))
        print("  \(path)")
    } catch {
        FileHandle.standardError.write("Write failed for \(path): \(error)\n".data(using: .utf8)!)
    }
}

// Apple's required iconset contents.
let variants: [(size: CGFloat, filename: String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

print("Generating iconset → \(outputDir)")
for v in variants {
    let img = drawIcon(size: v.size)
    savePNG(img, path: "\(outputDir)/\(v.filename)")
}
print("done.")
