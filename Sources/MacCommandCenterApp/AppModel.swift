import AppKit
import AppSupport
import CommandCore
import ConfigKit
import ConsoleKit
import ConsoleRuntime
import Foundation
import Observation
import PK4Skin
import ServiceManagement
import SkinKit
import TelemetryKit

/// Owns everything long-lived: the command registry, the two catalogs, the control
/// server and the user's preferences.
///
/// Commands are not written here any more — they are built from the selected config, so
/// changing a JSON file changes the buttons.
@MainActor
@Observable
final class AppModel {

    let center = CommandCenter()
    let signals = SignalCenter()
    let skins = SkinCatalog()
    let configs = ConfigCatalog()
    let runtime = ActionRuntime()
    let server: ControlServer

    private(set) var powerStatus: PowerStatus = .current

    var powerSource: PowerSource { powerStatus.source }

    /// Set by the app delegate once the global shortcut is registered.
    var isHotKeyRegistered = false
    var hotKeyDisplay: String { GlobalHotKey.Shortcut.default.display }

    /// Set by the window controllers.
    @ObservationIgnored var requestClose: (() -> Void)?
    @ObservationIgnored var requestSettings: (() -> Void)?
    @ObservationIgnored var requestConsole: (() -> Void)?

    @ObservationIgnored private var refreshTimer: Timer?
    /// Hook events are parsed here: a PostToolUse carries the tool's whole output.
    @ObservationIgnored private let hookQueue = DispatchQueue(
        label: "com.maccommandcenter.hooks", qos: .utility)
    /// Everything the hooks reported, as readings. The PK-4 console listens here.
    @ObservationIgnored var hookReadings: (([Reading]) -> Void)?

    /// The PK-4 console, while its window is open. Nothing of it runs otherwise: no
    /// `claude agents`, no transcript tails, no timer.
    private(set) var console: PK4Console?
    @ObservationIgnored private var appliedConfig: AppConfig?

    private enum Keys {
        static let controlServerEnabled = "controlServerEnabled"
        static let floatsOnTop = "floatsOnTop"
        static let consoleSound = "consoleSound"
        static let consoleVolume = "consoleVolume"
        static let consoleLampCodes = "consoleLampCodes"
        static let consoleAtLaunch = "consoleAtLaunch"
    }

    init() {
        let defaults = UserDefaults.standard
        isControlServerEnabled = defaults.bool(forKey: Keys.controlServerEnabled)
        floatsOnTop = defaults.object(forKey: Keys.floatsOnTop) as? Bool ?? true
        consoleSound = defaults.object(forKey: Keys.consoleSound) as? Bool ?? true
        consoleVolume = defaults.object(forKey: Keys.consoleVolume) as? Double ?? 0.8
        consoleLampCodes = defaults.object(forKey: Keys.consoleLampCodes) as? Bool ?? true
        openConsoleAtLaunch = defaults.bool(forKey: Keys.consoleAtLaunch)
        launchesAtLogin = SMAppService.mainApp.status == .enabled

        server = ControlServer(center: center, signals: signals)

        // Reading what another tool leaves in the home folder is a direct-build thing:
        // the App Store build is sandboxed and has no business outside its container.
        #if !APP_STORE
        signals.add(ClaudeCodeSource())
        #endif
        signals.start()

        server.events = { [weak self] source, body in
            self?.receive(source: source, body: body)
        }

        runtime.consentPrompt = { [weak self] action in
            await self?.requestShellConsent(action) ?? .deny
        }
        runtime.urlConsentPrompt = { [weak self] url in
            await self?.requestURLConsent(url) ?? .deny
        }

        applyCurrentConfig()
        observeConfigSelection()

        if isControlServerEnabled {
            server.start()
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            MainActor.assumeIsolated {
                self.powerStatus = .current
                self.center.refresh()
            }
        }
    }

    // MARK: - Config

    /// Rebuilds the registry from the selected config. Everything downstream — the panel,
    /// the HTTP API, the CLI — picks the change up without knowing a config exists.
    private func applyCurrentConfig() {
        let config = configs.current
        // The folder watcher fires for any change in the directory, and a reload hands
        // back a fresh array every time. Without this, saving an unrelated file would
        // rebuild the registry for no reason.
        guard config != appliedConfig else { return }
        appliedConfig = config
        let handlers = config.groups.flatMap { group in
            group.commands.map { command in
                ConfiguredCommand(definition: command, group: group.title, runtime: runtime)
            }
        }
        center.replaceAll(with: handlers)
    }

    private func observeConfigSelection() {
        withObservationTracking {
            _ = configs.current
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.applyCurrentConfig()
                self.observeConfigSelection()
            }
        }
    }

    // MARK: - PK-4 console

    func openConsole() {
        guard console == nil else { return }
        let console = PK4Console(commands: consoleCommands()) { [weak self] in
            self?.keepAwakeReadings() ?? []
        }
        self.console = console
        hookReadings = { [weak console] readings in console?.ingest(readings) }
        observeKeepAwake()
    }

    /// Writes the desk's memory and stops every source. Also called on quit.
    func closeConsole() {
        console?.shutDown()
        console = nil
        hookReadings = nil
    }

    /// Everything on the desk that reaches outside it. F1 to F10 are still to be defined,
    /// and answer nothing.
    private func consoleCommands() -> ConsoleCommands {
        var actions: [InstrumentID: CommandAction] = [
            PK4.fc1: keepAwakeAction(.systemAndDisplay),
            PK4.fc2: keepAwakeAction(.systemOnly),
        ]
        #if !APP_STORE
        actions[PK4.sleepMode] = SystemCommands.sleepMode()
        actions[PK4.monitorOff] = SystemCommands.monitorOff()
        #endif
        return ConsoleCommands(actions: actions)
    }

    /// FC1 and FC2 are the two Keep Awake modes of whatever config is selected, found by
    /// what their buttons do. Looked up when pressed, so switching configs needs nothing.
    private func keepAwakeAction(_ mode: KeepAwakeMode) -> CommandAction {
        CommandAction { [weak self] _, reply in
            guard let self, let option = configs.current.keepAwakeOption(mode) else {
                reply(false)
                return
            }
            do {
                try center.perform(.toggle(optionID: option.option), on: CommandID(option.command))
            } catch {
                reply(false)
                return
            }
            // The registry's new state is the answer, reported as a reading — on the next
            // turn of the run loop, not from inside the press that asked for it.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                console?.ingest(keepAwakeReadings())
            }
        }
    }

    /// Which Keep Awake mode is on, for FC1's and FC2's lenses. A config without that mode
    /// reports nothing, and those lenses stay dark.
    private func keepAwakeReadings() -> [Reading] {
        let now = Date()
        let modes: [(KeepAwakeMode, Field)] = [
            (.systemAndDisplay, .keepAwakeDisplayOn), (.systemOnly, .keepAwakeDisplayOff),
        ]
        return modes.compactMap { mode, field in
            guard let option = configs.current.keepAwakeOption(mode) else { return nil }
            let active =
                center.state(for: CommandID(option.command)).activeOptionID == option.option
            return Reading(.machine, field, .flag(active), at: now, ttl: MachineSource.ttl)
        }
    }

    /// Keep Awake switched from the menu bar panel, the CLI or a macro pad shows on the
    /// console's lenses at once.
    private func observeKeepAwake() {
        guard console != nil else { return }
        withObservationTracking {
            _ = center.states
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, let console = self.console else { return }
                console.ingest(self.keepAwakeReadings())
                self.observeKeepAwake()
            }
        }
    }

    // MARK: - Hook events

    private func receive(source: String, body: Data) {
        guard source == "claude" else { return }
        hookQueue.async {
            let readings = ClaudeHooks.readings(from: body, at: Date())
            guard !readings.isEmpty else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.apply(readings) }
            }
        }
    }

    /// The hooks used to push `claude.waiting`, `claude.done` and `claude.agent` one
    /// curl at a time. They now send their whole event instead, so the same three
    /// signals are derived here and every skin that binds to them keeps working.
    private func apply(_ readings: [Reading]) {
        for reading in readings {
            switch reading.field {
            case .waiting:
                push("claude.waiting", "Waiting", ttl: 1800)
            case .turnDone:
                push("claude.done", "Done", ttl: 1800)
                signals.clear(id: "claude.waiting")
            case .agentDone:
                push("claude.agent", "Agent", ttl: 900)
            case .promptSubmitted:
                signals.clear(id: "claude.waiting")
                signals.clear(id: "claude.done")
            case .toolUsed:
                // A tool ran, so a permission it was waiting on has been granted.
                signals.clear(id: "claude.waiting")
            default:
                break
            }
        }
        hookReadings?(readings)
    }

    private func push(_ id: String, _ label: String, ttl: TimeInterval) {
        signals.push(id: id, label: label, fraction: nil, text: nil, isActive: true, ttl: ttl)
    }

    // MARK: - Shell consent

    /// Shown before an unapproved shell command runs. A shared config must not be able to
    /// execute anything the user has not read first.
    private func requestShellConsent(_ action: ShellAction) async -> ShellConsent {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Run this command?"
        alert.informativeText = """
            The config “\(configs.current.name)” wants to run:

            \(action.command)

            Only allow commands you understand.
            """
        alert.addButton(withTitle: "Run Once")
        alert.addButton(withTitle: "Always Allow")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .allowOnce
        case .alertSecondButtonReturn: return .allowAlways
        default: return .deny
        }
    }

    /// Shown before a privileged URL is handed to Launch Services. A `file:` or
    /// `shortcuts:` URL can start an app or an automation, so a shared config must not be
    /// able to open one unseen.
    private func requestURLConsent(_ url: URL) async -> ShellConsent {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Open this?"
        alert.informativeText = """
            The config "\(configs.current.name)" wants to open:

            \(url.absoluteString)

            This can start an app or an automation. Only allow what you recognise.
            """
        alert.addButton(withTitle: "Open Once")
        alert.addButton(withTitle: "Always Allow")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .allowOnce
        case .alertSecondButtonReturn: return .allowAlways
        default: return .deny
        }
    }

    // MARK: - Preferences

    // These are stored, not computed. `@Observable` only tracks stored properties, so a
    // computed wrapper around UserDefaults changed the setting without ever redrawing the
    // switch that changed it.

    /// Off by default: it needs a network entitlement, and most people never want it.
    var isControlServerEnabled: Bool {
        didSet {
            guard oldValue != isControlServerEnabled else { return }
            UserDefaults.standard.set(isControlServerEnabled, forKey: Keys.controlServerEnabled)
            server.setEnabled(isControlServerEnabled)
        }
    }

    var floatsOnTop: Bool {
        didSet {
            guard oldValue != floatsOnTop else { return }
            UserDefaults.standard.set(floatsOnTop, forKey: Keys.floatsOnTop)
            floatingLevelDidChange?(floatsOnTop)
        }
    }

    @ObservationIgnored var floatingLevelDidChange: ((Bool) -> Void)?

    // Console preferences that belong to whoever is looking, not to the desk: the desk's
    // own — its finish, the buzzer — live in its memory with everything else it keeps.

    var consoleSound: Bool {
        didSet {
            UserDefaults.standard.set(consoleSound, forKey: Keys.consoleSound)
            consoleSoundDevice?.isEnabled = consoleSound
        }
    }

    var consoleVolume: Double {
        didSet {
            UserDefaults.standard.set(consoleVolume, forKey: Keys.consoleVolume)
            consoleSoundDevice?.volume = Float(consoleVolume)
        }
    }

    /// Whether lamp windows carry their HL designators.
    var consoleLampCodes: Bool {
        didSet { UserDefaults.standard.set(consoleLampCodes, forKey: Keys.consoleLampCodes) }
    }

    /// For a console that lives full screen on a second display. Also readable as a
    /// one-off launch argument, `-consoleAtLaunch YES`, which is not saved.
    var openConsoleAtLaunch: Bool {
        didSet { UserDefaults.standard.set(openConsoleAtLaunch, forKey: Keys.consoleAtLaunch) }
    }

    @ObservationIgnored private weak var consoleSoundDevice: PK4Sound?

    func applyConsoleSoundSettings(to sound: PK4Sound) {
        consoleSoundDevice = sound
        sound.isEnabled = consoleSound
        sound.volume = Float(consoleVolume)
    }

    var isLaunchAtLoginSupported: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    /// Mirrors `SMAppService`, which is the source of truth. If registering fails the
    /// switch goes back to where it was rather than lying about the state.
    var launchesAtLogin: Bool {
        didSet {
            guard oldValue != launchesAtLogin, !isSyncingLoginItem else { return }
            do {
                if launchesAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                launchAtLoginError = nil
            } catch {
                launchAtLoginError = error.localizedDescription
                isSyncingLoginItem = true
                launchesAtLogin = oldValue
                isSyncingLoginItem = false
            }
        }
    }

    @ObservationIgnored private var isSyncingLoginItem = false

    var launchAtLoginError: String?

    // MARK: - Skins

    func cycleSkin(by offset: Int) {
        let all = skins.skins
        guard !all.isEmpty else { return }
        let index = all.firstIndex { $0.id == skins.selectedID } ?? 0
        let next = ((index + offset) % all.count + all.count) % all.count
        skins.selectedID = all[next].id
    }

    // MARK: - Presentation

    var menuBarSymbol: String {
        center.isAnythingActive ? "cup.and.saucer.fill" : "cup.and.saucer"
    }

    var statusSummary: String {
        let active = center.activeCommands
        guard let first = active.first else { return "Everything off" }
        return active.count == 1 ? first.title : "\(active.count) commands active"
    }

    /// True when this binary can run shell actions at all.
    var supportsShellActions: Bool {
        #if APP_STORE
        false
        #else
        true
        #endif
    }

    var buildChannel: String {
        supportsShellActions ? "Direct download" : "App Store"
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
