import AppKit
import CommandCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var model: AppModel!
    private var statusItem: StatusItemController!
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel()
        self.model = model
        statusItem = StatusItemController(model: model)

        hotKey = GlobalHotKey(shortcut: .default) { [weak self] in
            self?.statusItem.togglePanel(activating: true)
        }
        model.isHotKeyRegistered = (hotKey != nil)

        if model.openConsoleAtLaunch {
            model.requestConsole?()
        } else {
            model.consoleHost.startIfItWasRunning()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.consoleHost.close()
        model?.center.deactivateAll()
        model?.server.stop()
    }

    /// Clicking the app in Finder while it is already running reopens the panel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        statusItem?.togglePanel(activating: true)
        return true
    }
}
