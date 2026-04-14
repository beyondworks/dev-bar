import SwiftUI
import AppKit

struct SlotView: View {
    let slot: BarSlot
    let theme: Theme
    let axis: Axis
    let onRemove: () -> Void
    let onRename: (String) -> Void

    @State private var isEditing = false
    @State private var editingLabel = ""

    var body: some View {
        content
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(slot.stashedPosition != nil ? theme.accent.opacity(0.25) : theme.slotBackground)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .help(slot.windowTitle)
            .contextMenu {
                Button("이름 변경…") { startEditing() }
                Divider()
                Button("제거", role: .destructive, action: onRemove)
            }
            .sheet(isPresented: $isEditing) { renameSheet }
    }

    @ViewBuilder
    private var content: some View {
        if axis == .horizontal {
            HStack(spacing: 6) { iconView; labelStack; badge; statusDot }
        } else {
            VStack(spacing: 4) {
                HStack(spacing: 4) { iconView; badge }
                Text(slot.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.foreground)
                    .lineLimit(1)
                    .frame(maxWidth: 48)
                statusDot
            }
        }
    }

    private var iconView: some View {
        Group {
            if let icon = appIcon() {
                Image(nsImage: icon).resizable().frame(width: 22, height: 22)
            } else {
                RoundedRectangle(cornerRadius: 4).fill(theme.slotBackgroundActive).frame(width: 22, height: 22)
            }
        }
    }

    private var labelStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(slot.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.foreground)
                .lineLimit(1)
            Text(slot.appName)
                .font(.system(size: 9))
                .foregroundColor(theme.secondaryForeground)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var badge: some View {
        if slot.badgeCount > 0 {
            Text("\(slot.badgeCount)")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Capsule().fill(Color.red))
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private var statusDot: some View {
        if slot.status != .idle {
            Circle().fill(statusColor).frame(width: 6, height: 6)
        } else {
            EmptyView()
        }
    }

    private var statusColor: Color {
        switch slot.status {
        case .idle: return .gray
        case .working: return .green
        case .waitingInput: return .yellow
        case .error: return .red
        case .done: return .green
        }
    }

    private func appIcon() -> NSImage? {
        NSRunningApplication(processIdentifier: slot.pid)?.icon
    }

    private func startEditing() {
        editingLabel = slot.label
        isEditing = true
    }

    private var renameSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("슬롯 이름 변경").font(.headline)
            TextField("라벨", text: $editingLabel)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
            HStack {
                Spacer()
                Button("취소") { isEditing = false }
                Button("저장") {
                    onRename(editingLabel)
                    isEditing = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
    }
}
