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

private struct SlotSizeKey: PreferenceKey {
    static var defaultValue: [UUID: CGSize] = [:]
    static func reduce(value: inout [UUID: CGSize], nextValue: () -> [UUID: CGSize]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
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

    // Drag-reorder state (Dock-style long-press + drag with push-away).
    @State private var draggingID: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var slotSizes: [UUID: CGSize] = [:]

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
                .animation(.spring(response: 0.32, dampingFraction: 0.78), value: store.slots.map(\.id))
                .onPreferenceChange(SlotSizeKey.self) { sizes in
                    Task { @MainActor in slotSizes = sizes }
                }
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
                .animation(.spring(response: 0.32, dampingFraction: 0.78), value: store.slots.map(\.id))
                .onPreferenceChange(SlotSizeKey.self) { sizes in
                    Task { @MainActor in slotSizes = sizes }
                }
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
        let isDragged = draggingID == slot.id
        return SlotView(
            slot: slot,
            theme: theme,
            axis: axis,
            onRemove: { store.removeSlot(id: slot.id) },
            onRename: { newLabel in store.updateLabel(id: slot.id, label: newLabel) }
        )
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: SlotSizeKey.self, value: [slot.id: geo.size])
            }
        )
        .offset(
            x: axis == .horizontal ? pushOffset(for: slot) : 0,
            y: axis == .vertical ? pushOffset(for: slot) : 0
        )
        .scaleEffect(isDragged ? 1.06 : 1.0)
        .shadow(color: Color.black.opacity(isDragged ? 0.28 : 0), radius: 8, y: 4)
        .zIndex(isDragged ? 1 : 0)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: draggingID)
        .contentShape(Rectangle())
        .gesture(unifiedClickDrag(for: slot))
        .transition(.asymmetric(
            insertion: .scale(scale: 0.6).combined(with: .opacity),
            removal: .scale(scale: 0.6).combined(with: .opacity)
        ))
    }

    // MARK: - Click / drag (Dock-style, single gesture)

    private static let dragThreshold: CGFloat = 6

    /// Single gesture covers both "click" (tap) and "drag" (reorder).
    /// onEnded decides which one fired based on total translation.
    private func unifiedClickDrag(for slot: BarSlot) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let movedEnough = abs(value.translation.width) >= Self.dragThreshold
                    || abs(value.translation.height) >= Self.dragThreshold
                guard movedEnough else { return }
                if draggingID != slot.id { draggingID = slot.id }
                dragOffset = (axis == .horizontal) ? value.translation.width : value.translation.height
            }
            .onEnded { value in
                let translation = (axis == .horizontal) ? value.translation.width : value.translation.height
                let movedEnough = abs(translation) >= Self.dragThreshold
                let steps = reorderStepCount(for: translation)
                if movedEnough && steps != 0 {
                    commitReorder(slotID: slot.id, translation: translation)
                    resetDrag()
                } else {
                    resetDrag()
                    // ⌥+click ⇒ Dock minimize; plain click ⇒ off-screen stash.
                    let method: HideMethod = NSEvent.modifierFlags.contains(.option) ? .minimize : .stash
                    activate(slot, hideMethod: method)
                }
            }
    }

    private enum HideMethod { case stash, minimize }

    private func commitReorder(slotID: UUID, translation: CGFloat) {
        guard let sourceIndex = store.slots.firstIndex(where: { $0.id == slotID }) else { return }
        let steps = reorderStepCount(for: translation)
        guard steps != 0 else { return }
        let targetIndex = max(0, min(store.slots.count - 1, sourceIndex + steps))
        guard targetIndex != sourceIndex else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            _ = store.move(sourceID: slotID, toIndex: targetIndex)
        }
    }

    private func resetDrag() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            draggingID = nil
            dragOffset = 0
        }
    }

    /// Average slot size along the active axis, with a sane fallback.
    private func averageSlotExtent() -> CGFloat {
        let extents: [CGFloat] = slotSizes.values.map { axis == .horizontal ? $0.width : $0.height }
        guard !extents.isEmpty else { return 80 }
        return max(40, extents.reduce(0, +) / CGFloat(extents.count))
    }

    /// Number of index positions the user has dragged past.
    private func reorderStepCount(for translation: CGFloat) -> Int {
        let unit = averageSlotExtent() + 6 // spacing
        return Int((translation / unit).rounded())
    }

    /// Visual offset applied to each slot — makes non-dragged slots slide to
    /// make room for the dragged one (Dock magnetic effect).
    private func pushOffset(for slot: BarSlot) -> CGFloat {
        guard let draggingID else { return 0 }
        if slot.id == draggingID { return dragOffset }

        guard let sourceIndex = store.slots.firstIndex(where: { $0.id == draggingID }),
              let thisIndex = store.slots.firstIndex(where: { $0.id == slot.id }),
              let draggedSize = slotSizes[draggingID] else { return 0 }

        let draggedExtent = (axis == .horizontal ? draggedSize.width : draggedSize.height) + 6
        let steps = reorderStepCount(for: dragOffset)
        let targetIndex = max(0, min(store.slots.count - 1, sourceIndex + steps))

        if sourceIndex < targetIndex && thisIndex > sourceIndex && thisIndex <= targetIndex {
            return -draggedExtent
        }
        if sourceIndex > targetIndex && thisIndex < sourceIndex && thisIndex >= targetIndex {
            return draggedExtent
        }
        return 0
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

    private func activate(_ slot: BarSlot, hideMethod: HideMethod = .stash) {
        guard let runningApp = NSRunningApplication(processIdentifier: slot.pid) else { return }
        let wid = slot.cgWindowID

        // 1) Dev-bar-stashed (off-screen) → restore to saved position.
        if let stashedPos = slot.stashedPosition {
            if runningApp.isHidden { runningApp.unhide() }
            WindowManager.setPosition(pid: slot.pid, windowTitle: slot.windowTitle, cgWindowID: wid, position: stashedPos)
            WindowManager.focus(pid: slot.pid, windowTitle: slot.windowTitle, cgWindowID: wid)
            store.setStashedPosition(id: slot.id, nil)
            store.clearBadge(id: slot.id)
            return
        }

        // 2) Dock-minimized → un-minimize + focus.
        if WindowManager.isMinimized(pid: slot.pid, windowTitle: slot.windowTitle, cgWindowID: wid) {
            if runningApp.isHidden { runningApp.unhide() }
            WindowManager.focus(pid: slot.pid, windowTitle: slot.windowTitle, cgWindowID: wid)
            store.clearBadge(id: slot.id)
            return
        }

        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let currentPos = WindowManager.getPosition(pid: slot.pid, windowTitle: slot.windowTitle, cgWindowID: wid)
        // Window sitting outside every screen = leftover stash from a previous
        // Dev-bar session (we don't persist stash state yet).
        let isAlreadyOffscreen: Bool = {
            guard let p = currentPos else { return false }
            let union = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
            return !union.insetBy(dx: -50, dy: -50).contains(p)
        }()
        if isAlreadyOffscreen {
            if runningApp.isHidden { runningApp.unhide() }
            WindowManager.focus(pid: slot.pid, windowTitle: slot.windowTitle, cgWindowID: wid)
            store.clearBadge(id: slot.id)
            return
        }

        if frontPID == slot.pid {
            // Hide — method chosen by click modifier.
            switch hideMethod {
            case .stash:
                guard let pos = currentPos else {
                    WindowManager.minimize(pid: slot.pid, windowTitle: slot.windowTitle, cgWindowID: wid)
                    return
                }
                store.setStashedPosition(id: slot.id, pos)
                WindowManager.setPosition(pid: slot.pid, windowTitle: slot.windowTitle, cgWindowID: wid, position: WindowManager.offscreenAnchor)
            case .minimize:
                WindowManager.minimize(pid: slot.pid, windowTitle: slot.windowTitle, cgWindowID: wid)
            }
        } else {
            if runningApp.isHidden { runningApp.unhide() }
            WindowManager.focus(pid: slot.pid, windowTitle: slot.windowTitle, cgWindowID: wid)
            store.clearBadge(id: slot.id)
        }
    }
}
