import Foundation
import SwiftUI
import AppKit
import Combine

enum BarPosition: String, CaseIterable, Codable, Identifiable {
    case top, bottom, left, right
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .top: return "상단"
        case .bottom: return "하단"
        case .left: return "왼쪽"
        case .right: return "오른쪽"
        }
    }
    var isVertical: Bool { self == .left || self == .right }
}

enum ThemePreset: String, CaseIterable, Codable, Identifiable {
    case liquidGlass
    case macOSDark
    case macOSLight
    case vscodeDark
    case vscodeLight
    case dracula
    case solarizedDark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .liquidGlass: return "Liquid Glass (macOS 26+)"
        case .macOSDark: return "macOS Dark"
        case .macOSLight: return "macOS Light"
        case .vscodeDark: return "VSCode Dark"
        case .vscodeLight: return "VSCode Light"
        case .dracula: return "Dracula"
        case .solarizedDark: return "Solarized Dark"
        }
    }

    var theme: Theme {
        switch self {
        case .liquidGlass:
            return Theme(
                background: .clear,
                foreground: .primary,
                secondaryForeground: .secondary,
                border: Color.white.opacity(0.22),
                slotBackground: Color.white.opacity(0.12),
                slotBackgroundActive: Color.white.opacity(0.28),
                accent: .blue,
                isGlass: true
            )
        case .macOSDark:
            return Theme(
                background: Color(red: 0.10, green: 0.10, blue: 0.12),
                foreground: .white,
                secondaryForeground: Color.white.opacity(0.65),
                border: Color.white.opacity(0.10),
                slotBackground: Color.white.opacity(0.08),
                slotBackgroundActive: Color.white.opacity(0.18),
                accent: Color.blue
            )
        case .macOSLight:
            return Theme(
                background: Color(red: 0.97, green: 0.97, blue: 0.98),
                foreground: Color.black.opacity(0.88),
                secondaryForeground: Color.black.opacity(0.55),
                border: Color.black.opacity(0.10),
                slotBackground: Color.black.opacity(0.06),
                slotBackgroundActive: Color.black.opacity(0.14),
                accent: Color.blue
            )
        case .vscodeDark:
            return Theme(
                background: Color(red: 0.118, green: 0.118, blue: 0.118),
                foreground: Color(red: 0.80, green: 0.80, blue: 0.80),
                secondaryForeground: Color(red: 0.55, green: 0.55, blue: 0.55),
                border: Color(red: 0.20, green: 0.20, blue: 0.20),
                slotBackground: Color(red: 0.20, green: 0.20, blue: 0.22),
                slotBackgroundActive: Color(red: 0.30, green: 0.30, blue: 0.34),
                accent: Color(red: 0.0, green: 0.48, blue: 0.84)
            )
        case .vscodeLight:
            return Theme(
                background: Color(red: 0.93, green: 0.93, blue: 0.94),
                foreground: Color(red: 0.13, green: 0.13, blue: 0.13),
                secondaryForeground: Color(red: 0.42, green: 0.42, blue: 0.42),
                border: Color(red: 0.85, green: 0.85, blue: 0.85),
                slotBackground: Color.white,
                slotBackgroundActive: Color(red: 0.88, green: 0.88, blue: 0.90),
                accent: Color(red: 0.0, green: 0.48, blue: 0.84)
            )
        case .dracula:
            return Theme(
                background: Color(red: 0.157, green: 0.165, blue: 0.212),
                foreground: Color(red: 0.945, green: 0.976, blue: 0.949),
                secondaryForeground: Color(red: 0.388, green: 0.427, blue: 0.510),
                border: Color(red: 0.267, green: 0.278, blue: 0.353),
                slotBackground: Color(red: 0.267, green: 0.278, blue: 0.353),
                slotBackgroundActive: Color(red: 0.341, green: 0.351, blue: 0.443),
                accent: Color(red: 0.741, green: 0.576, blue: 0.976)
            )
        case .solarizedDark:
            return Theme(
                background: Color(red: 0.000, green: 0.169, blue: 0.212),
                foreground: Color(red: 0.514, green: 0.580, blue: 0.588),
                secondaryForeground: Color(red: 0.345, green: 0.431, blue: 0.459),
                border: Color(red: 0.027, green: 0.212, blue: 0.259),
                slotBackground: Color(red: 0.027, green: 0.212, blue: 0.259),
                slotBackgroundActive: Color(red: 0.137, green: 0.294, blue: 0.329),
                accent: Color(red: 0.149, green: 0.545, blue: 0.824)
            )
        }
    }
}

struct Theme {
    let background: Color
    let foreground: Color
    let secondaryForeground: Color
    let border: Color
    let slotBackground: Color
    let slotBackgroundActive: Color
    let accent: Color
    let isGlass: Bool

    init(
        background: Color,
        foreground: Color,
        secondaryForeground: Color,
        border: Color,
        slotBackground: Color,
        slotBackgroundActive: Color,
        accent: Color,
        isGlass: Bool = false
    ) {
        self.background = background
        self.foreground = foreground
        self.secondaryForeground = secondaryForeground
        self.border = border
        self.slotBackground = slotBackground
        self.slotBackgroundActive = slotBackgroundActive
        self.accent = accent
        self.isGlass = isGlass
    }
}

private enum SettingsKey {
    static let position = "dev-bar.position"
    static let theme = "dev-bar.theme"
    static let opacity = "dev-bar.opacity"
    static let targetDisplay = "dev-bar.targetDisplayName"
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var barPosition: BarPosition {
        didSet { UserDefaults.standard.set(barPosition.rawValue, forKey: SettingsKey.position) }
    }
    @Published var themePreset: ThemePreset {
        didSet { UserDefaults.standard.set(themePreset.rawValue, forKey: SettingsKey.theme) }
    }
    @Published var backgroundOpacity: Double {
        didSet { UserDefaults.standard.set(backgroundOpacity, forKey: SettingsKey.opacity) }
    }
    /// Target display's localizedName. nil = auto (primary display).
    @Published var targetDisplayName: String? {
        didSet {
            if let name = targetDisplayName {
                UserDefaults.standard.set(name, forKey: SettingsKey.targetDisplay)
            } else {
                UserDefaults.standard.removeObject(forKey: SettingsKey.targetDisplay)
            }
        }
    }

    init() {
        let defaults = UserDefaults.standard
        self.barPosition = BarPosition(rawValue: defaults.string(forKey: SettingsKey.position) ?? "") ?? .top
        self.themePreset = ThemePreset(rawValue: defaults.string(forKey: SettingsKey.theme) ?? "") ?? .macOSDark
        if let stored = defaults.object(forKey: SettingsKey.opacity) as? Double {
            self.backgroundOpacity = stored
        } else {
            self.backgroundOpacity = 0.55
        }
        self.targetDisplayName = defaults.string(forKey: SettingsKey.targetDisplay)
    }

    var theme: Theme { themePreset.theme }
}
