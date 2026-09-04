import AppKit
import Combine
import SwiftUI

@MainActor
final class PanelPresentation: ObservableObject {
    @Published var isExpanded = false
    var setExpanded: (Bool) -> Void = { _ in }
    var setHovered: (Bool) -> Void = { _ in }
    var close: () -> Void = {}
}

final class EdgePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class EdgePanelController: NSObject, NSWindowDelegate {
    let model = TimekeepingModel()
    let presentation = PanelPresentation()

    private var panel: EdgePanel!
    private var subscriptions = Set<AnyCancellable>()
    private var collapseTask: Task<Void, Never>?
    private let expandedSize = NSSize(width: 266, height: 428)

    private var collapsedSize: NSSize {
        if model.hideCountdownWhenIdle {
            return NSSize(width: 56, height: 98)
        }
        return NSSize(width: 56, height: 154)
    }

    override init() {
        super.init()
        configurePanel()
        presentation.setExpanded = { [weak self] expanded in self?.setExpanded(expanded) }
        presentation.setHovered = { [weak self] hovering in self?.handleHover(hovering) }
        presentation.close = { [weak self] in self?.panel.orderOut(nil) }

        model.$behavior
            .removeDuplicates()
            .sink { [weak self] behavior in self?.apply(behavior: behavior) }
            .store(in: &subscriptions)

        Publishers.CombineLatest(model.$section, model.$hideCountdownWhenIdle)
            .removeDuplicates { previous, current in
                previous.0 == current.0 && previous.1 == current.1
            }
            .sink { [weak self] _ in
                guard let self, !presentation.isExpanded else { return }
                reposition(animated: true)
            }
            .store(in: &subscriptions)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.reposition(animated: false) }
            .store(in: &subscriptions)
    }

    func showPanel(expanded: Bool) {
        if expanded || model.behavior == .alwaysOnTop {
            setExpanded(true, animated: false)
        } else {
            reposition(animated: false)
        }
        panel.orderFrontRegardless()
        if expanded {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKey()
        }
    }

    private func configurePanel() {
        panel = EdgePanel(
            contentRect: NSRect(origin: .zero, size: collapsedSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.contentViewController = NSHostingController(
            rootView: PanelView(model: model, presentation: presentation)
                .environment(\.colorScheme, .dark)
        )
        apply(behavior: model.behavior)
        reposition(animated: false)
    }

    private func apply(behavior: PanelBehavior) {
        if behavior == .alwaysOnTop {
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            setExpanded(true)
        } else {
            panel.level = .floating
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            if behavior == .autoHide { setExpanded(false) }
        }
    }

    private func handleHover(_ hovering: Bool) {
        collapseTask?.cancel()
        if hovering {
            setExpanded(true)
        } else if model.behavior == .autoHide {
            collapseTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                self?.setExpanded(false)
            }
        }
    }

    private func setExpanded(_ expanded: Bool, animated: Bool = true) {
        guard !(model.behavior == .alwaysOnTop && !expanded) else { return }
        presentation.isExpanded = expanded
        reposition(animated: animated)
    }

    private func reposition(animated: Bool) {
        let screen = panel.screen ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }
        let size = presentation.isExpanded ? expandedSize : collapsedSize
        let rightInset: CGFloat = presentation.isExpanded ? 8 : 0
        let origin = NSPoint(
            x: visibleFrame.maxX - size.width + rightInset,
            y: visibleFrame.midY - size.height / 2
        )
        let frame = NSRect(origin: origin, size: size)
        if animated, panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
