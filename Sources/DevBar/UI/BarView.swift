import SwiftUI
import AppKit

private struct BarBackgroundModifier: ViewModifier {
    let theme: Theme
    let opacity: Double

    func body(content: Content) -> some View {
        if theme.isGlass {
            if #available(macOS 26.0, *) {
                content
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
            } else {
                content.background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(theme.border, lineWidth: 1)
                        )
                )
            }
        } else {
            content.background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.background.opacity(opacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
            )
        }
    }
}

private struct InnerContentLengthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct TotalSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        value = CGSize(width: max(value.width, next.width), height: max(value.height, next.height))
    }
}

struct BarView: View {
    @ObservedObject var store: BarStore
    @ObservedObject var settings: SettingsStore
    /// If set, overrides settings.barPosition (used for the secondary/dock bar).
    var forcedPosition: BarPosition? = nil
    let maxContentLength: CGFloat
    var onTotalSizeChange: (CGSize) -> Void = { _ in }
    var onOpenSettings: () -> Void = {}

    @State private var innerContentLength: CGFloat = 0
    @State private var showingPicker = false
    @State private var scrollAnchorIndex: Int = 0

    private var position: BarPosition { forcedPosition ?? settings.barPosition }
    private var axis: Axis { position.isVertical ? .vertical : .horizontal }
    private var theme: Theme { settings.theme }
    private var emptyLength: CGFloat { axis == .horizontal ? 720 : 200 }

    private var needsScroll: Bool { innerContentLength > maxContentLength + 0.5 }
    private var scrollAreaLength: CGFloat { min(max(innerContentLength, 40), maxContentLength) }

    var body: some View {
        Group {
            if store.slots.isEmpty {
                emptyBody
            } else {
                compactBody
            }
        }
        .padding(axis == .horizontal ? .horizontal : .vertical, 12)
        .padding(axis == .horizontal ? .vertical : .horizontal, 6)
        .frame(minWidth: axis == .vertical ? 56 : nil, minHeight: axis == .horizontal ? 56 : nil)
        .modifier(BarBackgroundModifier(theme: theme, opacity: settings.backgroundOpacity))
        .animation(.easeOut(duration: 0.22), value: store.slots)
        .fixedSize(horizontal: axis == .horizontal, vertical: axis == .vertical)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: TotalSizeKey.self, value: geo.size)
            }
        )
        .onPreferenceChange(TotalSizeKey.self) { size in
            Task { @MainActor in onTotalSizeChange(size) }
        }
    }

    @ViewBuilder
    private var emptyBody: some View {
        if axis == .horizontal {
            HStack(spacing: 6) { plusButton; Spacer(minLength: 0); settingsButton }
                .frame(width: emptyLength - 24)
        } else {
            VStack(spacing: 6) { plusButton; Spacer(minLength: 0); settingsButton }
                .frame(height: emptyLength - 24)
        }
    }

    @ViewBuilder
    private var compactBody: some View {
        if axis == .horizontal {
            HStack(spacing: 4) {
                if needsScroll { arrowButton(systemImage: "chevron.left", direction: -1) }
                horizontalScroll
                if needsScroll { arrowButton(systemImage: "chevron.right", direction: 1) }
                settingsButton
            }
        } else {
            VStack(spacing: 4) {
                if needsScroll { arrowButton(systemImage: "chevron.up", direction: -1) }
                verticalScroll
                if needsScroll { arrowButton(systemImage: "chevron.down", direction: 1) }
                settingsButton
            }
        }
    }

    private var horizontalScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(store.slots) { slot in slotItem(for: slot).id(slot.id) }
                    plusButton
                }
                .padding(.horizontal, 2)
                .background(lengthProbe(axis: .horizontal))
            }
            .frame(width: scrollAreaLength)
            .onPreferenceChange(InnerContentLengthKey.self) { len in
                Task { @MainActor in innerContentLength = len }
            }
            .onChange(of: scrollAnchorIndex) { _, newValue in
                guard store.slots.indices.contains(newValue) else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(store.slots[newValue].id, anchor: .leading)
                }
            }
        }
    }

    private var verticalScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(store.slots) { slot in slotItem(for: slot).id(slot.id) }
                    plusButton
                }
                .padding(.vertical, 2)
                .background(lengthProbe(axis: .vertical))
            }
            .frame(height: scrollAreaLength)
            .onPreferenceChange(InnerContentLengthKey.self) { len in
                Task { @MainActor in innerContentLength = len }
            }
            .onChange(of: scrollAnchorIndex) { _, newValue in
                guard store.slots.indices.contains(newValue) else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(store.slots[newValue].id, anchor: .top)
                }
            }
        }
    }

    private func lengthProbe(axis: Axis) -> some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: InnerContentLengthKey.self,
                value: axis == .horizontal ? geo.size.width : geo.size.height
            )
        }
    }

    private func slotItem(for slot: BarSlot) -> some View {
        SlotView(
            slot: slot,
            theme: theme,
            axis: axis,
            onActivate: { activate(slot) },
            onRemove: { store.removeSlot(id: slot.id) },
            onRename: { newLabel in store.updateLabel(id: slot.id, label: newLabel) }
        )
        .draggable(slot.id.uuidString)
        .dropDestination(for: String.self) { items, _ in
            guard let idString = items.first,
                  let sourceID = UUID(uuidString: idString) else { return false }
            return store.move(sourceID: sourceID, beforeID: slot.id)
        }
    }

    private var plusButton: some View {
        Button(action: { showingPicker.toggle() }) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(theme.foreground.opacity(0.75))
        }
        .buttonStyle(.plain)
        .help("창 추가")
        .popover(isPresented: $showingPicker, arrowEdge: axis == .horizontal ? .bottom : .leading) {
            AppPickerView(store: store, isPresented: $showingPicker)
        }
    }

    private var settingsButton: some View {
        Button(action: onOpenSettings) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16))
                .foregroundColor(theme.foreground.opacity(0.65))
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(theme.slotBackground)
                )
        }
        .buttonStyle(.plain)
        .help("설정")
    }

    private func arrowButton(systemImage: String, direction: Int) -> some View {
        Button(action: { moveAnchor(by: direction) }) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.foreground.opacity(0.8))
                .frame(
                    width: axis == .horizontal ? 22 : 40,
                    height: axis == .horizontal ? 40 : 22
                )
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.slotBackground)
                )
        }
        .buttonStyle(.plain)
    }

    private func moveAnchor(by delta: Int) {
        let last = max(0, store.slots.count - 1)
        scrollAnchorIndex = max(0, min(last, scrollAnchorIndex + delta))
    }

    private func activate(_ slot: BarSlot) {
        guard let runningApp = NSRunningApplication(processIdentifier: slot.pid) else { return }

        if let stashedPos = slot.stashedPosition {
            if runningApp.isHidden { runningApp.unhide() }
            WindowManager.setPosition(pid: slot.pid, windowTitle: slot.windowTitle, position: stashedPos)
            WindowManager.focus(pid: slot.pid, windowTitle: slot.windowTitle)
            store.setStashedPosition(id: slot.id, nil)
            store.clearBadge(id: slot.id)
            return
        }

        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        if frontPID == slot.pid {
            guard let currentPos = WindowManager.getPosition(pid: slot.pid, windowTitle: slot.windowTitle) else {
                WindowManager.minimize(pid: slot.pid, windowTitle: slot.windowTitle)
                return
            }
            store.setStashedPosition(id: slot.id, currentPos)
            WindowManager.setPosition(pid: slot.pid, windowTitle: slot.windowTitle, position: WindowManager.offscreenAnchor)
        } else {
            if runningApp.isHidden { runningApp.unhide() }
            WindowManager.focus(pid: slot.pid, windowTitle: slot.windowTitle)
            store.clearBadge(id: slot.id)
        }
    }
}
