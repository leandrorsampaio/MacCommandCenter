import AppKit
import CommandCore
import Observation
import SkinKit
import SwiftUI

/// The menu bar item: left-click opens the panel, right-click opens the menu.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {

    private let model: AppModel
    private let statusItem: NSStatusItem
    private let panel: FloatingPanelController
    private let settings: SettingsWindowController

    init(model: AppModel) {
        self.model = model
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.panel = FloatingPanelController(
            rootView: ControlPanelView(model: model),
            floatsOnTop: model.floatsOnTop
        )
        self.settings = SettingsWindowController(model: model)
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("Mac Command Center")
        }

        model.requestClose = { [weak self] in self?.panel.hide() }
        model.requestSettings = { [weak self] in self?.settings.show() }
        model.floatingLevelDidChange = { [weak self] floats in self?.panel.setFloatsOnTop(floats) }

        updateIcon()
        observeIcon()
        observeLayout()
    }

    // MARK: - Clicks

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            togglePanel(activating: false)
        }
    }

    func togglePanel(activating: Bool) {
        panel.toggle(anchoredTo: statusItem.button, activating: activating)
    }

    func showSettings() {
        settings.show()
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: model.statusSummary, action: nil, keyEquivalent: "").isEnabled =
            false
        menu.addItem(.separator())

        let toggle = NSMenuItem(
            title: panel.isVisible ? "Hide Panel" : "Show Panel",
            action: #selector(menuTogglePanel),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        let float = NSMenuItem(
            title: "Keep Panel on Top",
            action: #selector(menuToggleFloat),
            keyEquivalent: ""
        )
        float.target = self
        float.state = model.floatsOnTop ? .on : .off
        menu.addItem(float)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…", action: #selector(menuSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let reload = NSMenuItem(
            title: "Reload Skins & Configs", action: #selector(menuReload), keyEquivalent: "r")
        reload.target = self
        menu.addItem(reload)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit Mac Command Center", action: #selector(menuQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        // Attaching the menu makes the next click open it; detaching restores the action.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func menuTogglePanel() { togglePanel(activating: true) }
    @objc private func menuToggleFloat() { model.floatsOnTop.toggle() }
    @objc private func menuSettings() { settings.show() }
    @objc private func menuQuit() { model.quit() }

    @objc private func menuReload() {
        model.skins.reload()
        model.configs.reload()
    }

    // MARK: - Icon

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let image = NSImage(
            systemSymbolName: model.menuBarSymbol,
            accessibilityDescription: model.statusSummary
        )
        image?.isTemplate = true
        button.image = image
        button.toolTip = "Mac Command Center — \(model.statusSummary)"
    }

    /// Bridges `@Observable` back to AppKit: re-arms itself after every change.
    private func observeIcon() {
        withObservationTracking {
            _ = model.menuBarSymbol
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.updateIcon()
                self.observeIcon()
            }
        }
    }

    /// A skin or a config can change how big the panel needs to be.
    private func observeLayout() {
        withObservationTracking {
            _ = model.skins.current
            _ = model.center.descriptors
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.panel.fitToContent()
                self.observeLayout()
            }
        }
    }
}
