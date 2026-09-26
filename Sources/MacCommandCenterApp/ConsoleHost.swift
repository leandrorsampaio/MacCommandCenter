import CommandCore
import ConfigKit
import ConsoleKit
import ConsoleRuntime
import FakeSources
import Foundation
import Observation
import SkinKit
import TelemetryKit

/// Everything between the app and the PK-4 console: when it runs, what it reads, what its
/// outside buttons do.
///
/// - **One reader of `~/.claude`.** The menu bar panel's `claude.*` signals and the console
///   read the same feed, and it runs only while one of them wants it: a skin that binds a
///   `claude.` signal, or the console with MAINS on.
/// - **The console keeps running with its window closed** once it has been opened, so its
///   drum totals and hours in service count what happened while nobody was looking. A
///   preference turns that off.
/// - **The scripted day** can stand in for Claude Code, in a folder of its own, so a demo
///   never touches the real totals or the real safety log.
@MainActor
@Observable
final class ConsoleHost {

    private(set) var console: PK4Console?
    /// When a hook event last arrived, for Settings: the desk itself has no instrument for
    /// it and gets none.
    private(set) var lastHookEvent: Date?

    var keepRunning: Bool {
        didSet {
            UserDefaults.standard.set(keepRunning, forKey: Keys.keepRunning)
            if !keepRunning, !windowOpen { close() }
        }
    }

    var demo: Bool {
        didSet {
            guard demo != oldValue else { return }
            UserDefaults.standard.set(demo, forKey: Keys.demo)
            // A different desk: close this one and open the other where it was.
            guard console != nil else { return }
            close()
            open()
        }
    }

    @ObservationIgnored private let center: CommandCenter
    @ObservationIgnored private let configs: ConfigCatalog
    @ObservationIgnored private let signals: SignalCenter
    @ObservationIgnored private let skins: SkinCatalog
    @ObservationIgnored private var windowOpen = false
    @ObservationIgnored private var consolePowered = false
    @ObservationIgnored private var panelWantsClaude = false
    @ObservationIgnored private var demoFeed: DemoFeed?
    #if !APP_STORE
    @ObservationIgnored private var claude: ClaudeCodeFeed?
    #endif

    private enum Keys {
        static let keepRunning = "consoleKeepsRunning"
        static let demo = "consoleDemo"
        static let everOpened = "consoleEverOpened"
    }

    init(center: CommandCenter, configs: ConfigCatalog, signals: SignalCenter, skins: SkinCatalog) {
        self.center = center
        self.configs = configs
        self.signals = signals
        self.skins = skins
        let defaults = UserDefaults.standard
        keepRunning = defaults.object(forKey: Keys.keepRunning) as? Bool ?? true
        demo = defaults.bool(forKey: Keys.demo)
        observeSkin()
    }

    /// Called at launch: a console that was in use keeps running without its window.
    func startIfItWasRunning() {
        if UserDefaults.standard.bool(forKey: Keys.everOpened), keepRunning { open() }
    }

    // MARK: - Lifecycle

    func open() {
        guard console == nil else { return }
        UserDefaults.standard.set(true, forKey: Keys.everOpened)
        let folder =
            demo
            ? ConsoleFolder.url.appendingPathComponent("Demo", isDirectory: true)
            : ConsoleFolder.url
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var created: PK4Console?
        let console = PK4Console(
            directory: folder, commands: commands(for: { created }), readsMachine: !demo,
            extras: { [weak self] in self?.keepAwakeReadings() ?? [] },
            onPower: { [weak self] on in
                self?.consolePowered = on
                self?.updateFeeds()
            })
        created = console
        self.console = console
        observeKeepAwake()
        updateFeeds()
    }

    /// Writes the desk's memory and stops everything it was reading.
    func close() {
        console?.shutDown()
        console = nil
        consolePowered = false
        updateFeeds()
    }

    func windowDidOpen() {
        windowOpen = true
        open()
    }

    func windowDidClose() {
        windowOpen = false
        if !keepRunning { close() }
    }

    // MARK: - Feeds

    /// Starts and stops the one reader of `~/.claude`, and the scripted day, to match who
    /// wants them.
    private func updateFeeds() {
        #if !APP_STORE
        let consoleWantsClaude = console != nil && consolePowered && !demo
        if consoleWantsClaude || panelWantsClaude {
            if claude == nil {
                let feed = ClaudeCodeFeed { [weak self] batch in self?.received(batch) }
                feed.start()
                claude = feed
            }
        } else {
            claude?.stop()
            claude = nil
        }
        #endif

        if console != nil, consolePowered, demo {
            if demoFeed == nil {
                demoFeed = DemoFeed { [weak self] readings in
                    guard let self else { return }
                    self.console?.ingest(readings + self.keepAwakeReadings())
                }
            }
        } else {
            demoFeed?.stop()
            demoFeed = nil
        }
    }

    #if !APP_STORE
    private func received(_ batch: TelemetryBatch) {
        if panelWantsClaude { publishPanelSignals(batch) }
        if !demo, consolePowered { console?.ingest(batch) }
    }

    /// The panel's five `claude.*` signals, believed for as long as a console reading is.
    private func publishPanelSignals(_ batch: TelemetryBatch) {
        let expires = Date().addingTimeInterval(ClaudeCodeCollector.ttl)
        for line in ClaudeSummary.lines(from: batch.readings) {
            signals.push(
                Signal(
                    id: line.id, label: line.label, fraction: line.fraction, text: line.text,
                    isActive: line.active, expires: expires))
        }
    }
    #endif

    /// Hook events, already parsed. Only the real console hears them: a demo has sessions
    /// of its own.
    func hookEvents(_ readings: [Reading]) {
        lastHookEvent = Date()
        guard !demo else { return }
        console?.ingest(readings)
    }

    /// Whether the selected skin binds anything from Claude Code, so that a panel skin that
    /// shows none of it costs nothing.
    private func observeSkin() {
        withObservationTracking {
            panelWantsClaude = skins.current.layout.signalIDs.contains { $0.hasPrefix("claude.") }
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeSkin() }
        }
        updateFeeds()
    }

    // MARK: - Commands

    /// Everything on the desk that reaches outside it. F6 to F9 stay unassigned; see
    /// `SessionCommands` for why.
    ///
    /// A demo reaches no further than Keep Awake, which is harmless and undone by pressing
    /// again: its sessions are made up, and a demo that put the Mac to sleep would be a
    /// poor demo. Everything else answers NO ANSWER, which is the truth.
    private func commands(for console: @escaping @MainActor () -> PK4Console?) -> ConsoleCommands {
        var actions: [InstrumentID: CommandAction] = [
            PK4.fc1: keepAwakeAction(.systemAndDisplay),
            PK4.fc2: keepAwakeAction(.systemOnly),
        ]
        #if !APP_STORE
        if !demo {
            actions[PK4.sleepMode] = SystemCommands.sleepMode()
            actions[PK4.monitorOff] = SystemCommands.monitorOff()
            let session = SessionCommands.actions(
                details: { console()?.model.details(of: $0) },
                safetyLog: ConsoleFolder.url.appendingPathComponent("safety.log"))
            actions.merge(session) { current, _ in current }
        }
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
        guard let watched = console else { return }
        withObservationTracking {
            _ = center.states
        } onChange: { [weak self, weak watched] in
            Task { @MainActor in
                // One watch per console: the one a closed console left armed ends here.
                guard let self, let watched, self.console === watched else { return }
                watched.ingest(self.keepAwakeReadings())
                self.observeKeepAwake()
            }
        }
    }
}

/// The scripted day, played at the speed of the clock on the wall, from 08:55. At 18:00
/// it starts again.
@MainActor
final class DemoFeed {

    private var day = FakeDay.opening(at: Date())
    private var timer: Timer?
    private let deliver: @MainActor ([Reading]) -> Void

    init(deliver: @escaping @MainActor ([Reading]) -> Void) {
        self.deliver = deliver
        timer = Timer.scheduledTimer(withTimeInterval: FakeDay.tick, repeats: true) {
            [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer?.tolerance = 0.2
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        if day.isOver { day = FakeDay.opening(at: Date()) }
        deliver(day.catchUp(to: Date()))
    }
}
