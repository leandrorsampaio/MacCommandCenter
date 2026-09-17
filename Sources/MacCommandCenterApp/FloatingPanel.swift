import AppKit
import SwiftUI

/// The skinned window that the menu bar item opens.
///
/// Borderless, because the skin paints its own chassis and a macOS title bar would sit
/// around it. It is an ordinary movable window rather than a dropdown: you can park it
/// wherever you like and, by default, it stays above everything else — which is how
/// Winamp behaved, and what you want from a panel you glance at while work runs.
final class FloatingPanelWindow: NSPanel {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = true
        // Dragging an empty part of the chassis moves it, exactly like the real thing.
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    /// Borderless windows refuse key status by default; the shortcuts inside need it.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}

/// A transparent strip that drags its window. Placed behind the titlebar's contents, so
/// the close box still receives its own clicks.
struct WindowDragHandle: NSViewRepresentable {

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }

    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

@MainActor
final class FloatingPanelController {

    private let panel = FloatingPanelWindow()
    private let hosting: NSHostingController<ControlPanelView>
    private var hasPositioned = false
    /// Whether a saved frame was restored. Checked at init, because `fitToContent()`
    /// moves the window and would otherwise make every launch look like a restore.
    private var hasRestoredFrame = false
    private static let autosaveName = "MacCommandCenterPanel"

    var isVisible: Bool { panel.isVisible }

    init(rootView: ControlPanelView, floatsOnTop: Bool) {
        hosting = NSHostingController(rootView: rootView)
        hosting.sizingOptions = [.preferredContentSize]
        panel.contentViewController = hosting
        panel.setFrameAutosaveName(Self.autosaveName)
        hasRestoredFrame = panel.setFrameUsingName(Self.autosaveName)
        setFloatsOnTop(floatsOnTop)
    }

    // MARK: - Showing

    func show(anchoredTo button: NSStatusBarButton?, activating: Bool) {
        panel.layoutIfNeeded()
        fitToContent()

        if !hasPositioned {
            if !hasRestoredFrame { positionUnderMenuBar(button) }
            hasPositioned = true
        }
        clampToScreen()

        if activating {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    func toggle(anchoredTo button: NSStatusBarButton?, activating: Bool) {
        isVisible ? hide() : show(anchoredTo: button, activating: activating)
    }

    func setFloatsOnTop(_ floats: Bool) {
        panel.level = floats ? .floating : .normal
    }

    /// Keeps the window snug around the skin, which may change size when a skin loads.
    func fitToContent() {
        let fitting = hosting.view.fittingSize
        guard fitting.width > 1, fitting.height > 1 else { return }

        // Grow downward from the top edge so the window does not appear to jump.
        let topLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        panel.setContentSize(fitting)
        panel.setFrameTopLeftPoint(topLeft)
        clampToScreen()
    }

    /// Keeps the window reachable. A restored frame, or one grown downward by a taller
    /// skin, can otherwise sit partly or wholly off-screen with no way to drag it back.
    private func clampToScreen() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = panel.frame

        frame.size.width = min(frame.width, visible.width)
        frame.size.height = min(frame.height, visible.height)
        frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)

        if frame != panel.frame {
            panel.setFrame(frame, display: false)
        }
    }

    /// First run only: drop it just under the menu bar item.
    private func positionUnderMenuBar(_ button: NSStatusBarButton?) {
        let size = panel.frame.size
        var origin = NSPoint(x: 0, y: 0)

        if let button, let buttonWindow = button.window {
            let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            origin = NSPoint(
                x: buttonFrame.midX - size.width / 2, y: buttonFrame.minY - size.height - 6)
        } else if let screen = NSScreen.main {
            origin = NSPoint(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.maxY - size.height - 20)
        }

        if let screen = button?.window?.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
            origin.y = max(origin.y, visible.minY + 8)
        }

        panel.setFrameOrigin(origin)
    }
}
