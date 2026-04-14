import AppKit
import SwiftUI
import Combine

@MainActor
final class BarPanelController {
    let store: BarStore
    let settings: SettingsStore
    let onOpenSettings: () -> Void

    private var primaryPanel: NSPanel?
    private var primaryHost: NSHostingView<BarView>?
    private var primarySize: CGSize = .init(width: 720, height: 56)

    private var cancellables = Set<AnyCancellable>()

    private let minorDim: CGFloat = 56
    private let screenMargin: CGFloat = 8

    init(store: BarStore, settings: SettingsStore, onOpenSettings: @escaping () -> Void) {
        self.store = store
        self.settings = settings
        self.onOpenSettings = onOpenSettings
    }

    func start() {
        buildPrimary()
        observeSettings()
    }

    func toggle() {
        guard let panel = primaryPanel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    // MARK: - Build

    private func buildPrimary() {
        let panel = makePanel()
        let host = NSHostingView(rootView: makePrimaryBarView(screen: resolvedScreen()))
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        primaryPanel = panel
        primaryHost = host
        positionPrimary()
        panel.orderFrontRegardless()
    }

    private func observeSettings() {
        settings.$barPosition
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in self?.rebuildPrimaryRootView(); self?.positionPrimary() }
            }
            .store(in: &cancellables)

        settings.$targetDisplayName
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in self?.rebuildPrimaryRootView(); self?.positionPrimary() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildPrimaryRootView()
                self?.positionPrimary()
            }
        }
    }

    // MARK: - Screen resolution

    private func resolvedScreen() -> NSScreen? {
        if let name = settings.targetDisplayName,
           let match = NSScreen.screens.first(where: { $0.localizedName == name }) {
            return match
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    // MARK: - View factory

    private func makePrimaryBarView(screen: NSScreen?) -> BarView {
        BarView(
            store: store,
            settings: settings,
            forcedPosition: nil,
            maxContentLength: maxContentLength(for: settings.barPosition, screen: screen),
            onTotalSizeChange: { [weak self] size in
                Task { @MainActor in
                    guard let self else { return }
                    self.primarySize = size
                    self.positionPrimary()
                }
            },
            onOpenSettings: onOpenSettings
        )
    }

    private func rebuildPrimaryRootView() {
        guard let host = primaryHost else { return }
        host.rootView = makePrimaryBarView(screen: resolvedScreen())
    }

    // MARK: - Panels

    private func makePanel() -> NSPanel {
        let rect = NSRect(x: 0, y: 0, width: 720, height: 56)
        let panel = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        return panel
    }

    // MARK: - Positioning

    private func maxContentLength(for position: BarPosition, screen: NSScreen?) -> CGFloat {
        let frame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1400, height: 900)
        return (position.isVertical ? frame.height : frame.width) - 120
    }

    private func positionPrimary() {
        guard let panel = primaryPanel, let screen = resolvedScreen() else { return }
        let frame = calcFrame(
            for: settings.barPosition,
            content: primarySize,
            screenFrame: screen.visibleFrame
        )
        guard !panel.frame.equalTo(frame) else { return }

        if panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true, animate: false)
        }
    }

    private func calcFrame(for position: BarPosition, content: CGSize, screenFrame: CGRect) -> NSRect {
        let maxW = screenFrame.width - 20
        let maxH = screenFrame.height - 20
        switch position {
        case .top:
            let w = min(max(content.width, minorDim), maxW)
            let h = max(content.height, minorDim)
            return NSRect(
                x: screenFrame.midX - w / 2,
                y: screenFrame.maxY - h - screenMargin,
                width: w, height: h
            )
        case .bottom:
            let w = min(max(content.width, minorDim), maxW)
            let h = max(content.height, minorDim)
            return NSRect(
                x: screenFrame.midX - w / 2,
                y: screenFrame.minY + screenMargin,
                width: w, height: h
            )
        case .left:
            let w = max(content.width, minorDim)
            let h = min(max(content.height, minorDim), maxH)
            return NSRect(
                x: screenFrame.minX + screenMargin,
                y: screenFrame.midY - h / 2,
                width: w, height: h
            )
        case .right:
            let w = max(content.width, minorDim)
            let h = min(max(content.height, minorDim), maxH)
            return NSRect(
                x: screenFrame.maxX - w - screenMargin,
                y: screenFrame.midY - h / 2,
                width: w, height: h
            )
        }
    }
}
