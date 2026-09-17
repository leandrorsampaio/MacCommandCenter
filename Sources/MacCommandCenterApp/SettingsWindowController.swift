import AppKit
import SwiftUI

/// A normal macOS window, deliberately unskinned.
///
/// The panel is the instrument; this is the workshop. Menu bar apps have no app menu, so
/// SwiftUI's `Settings` scene is not available — an ordinary window opened from the
/// status item menu is the native equivalent.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {

    private let model: AppModel
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
        super.init()
    }

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: SettingsView(model: model))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Mac Command Center Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 760, height: 520))
        window.contentMinSize = NSSize(width: 680, height: 460)
        window.setFrameAutosaveName("MacCommandCenterSettings")
        window.isReleasedWhenClosed = false
        window.delegate = self
        // Only centre when there is nothing to restore; centring unconditionally
        // discarded wherever the user had put it, every single time.
        if !window.setFrameUsingName("MacCommandCenterSettings") {
            window.center()
        }

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
