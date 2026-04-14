import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var screenRefreshTick: Int = 0

    var body: some View {
        Form {
            Section("위치") {
                Picker("바 위치", selection: $settings.barPosition) {
                    ForEach(BarPosition.allCases) { pos in
                        Text(pos.displayName).tag(pos)
                    }
                }
                .pickerStyle(.segmented)

                Picker("디스플레이", selection: $settings.targetDisplayName) {
                    Text("자동 (주 디스플레이)").tag(String?.none)
                    ForEach(NSScreen.screens, id: \.localizedName) { screen in
                        Text(screen.localizedName).tag(String?.some(screen.localizedName))
                    }
                }
                .id(screenRefreshTick)
            }

            Section("외형") {
                Picker("테마", selection: $settings.themePreset) {
                    ForEach(ThemePreset.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }

                HStack {
                    Text("투명도")
                    Slider(value: $settings.backgroundOpacity, in: 0.2...1.0)
                    Text(String(format: "%.0f%%", settings.backgroundOpacity * 100))
                        .frame(width: 48, alignment: .trailing)
                        .monospacedDigit()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 320)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screenRefreshTick &+= 1
        }
    }
}
