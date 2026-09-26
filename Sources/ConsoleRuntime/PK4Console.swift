import ConsoleKit
import Foundation
import TelemetryKit

/// Wakes the model exactly when it next has work, and not otherwise.
///
/// One timer, rescheduled after every input. A console with nothing changing wakes a few
/// times a minute — for an expiry, the uptime minute, the hour meter — which is what keeps
/// it idle.
@MainActor
public final class ConsoleDriver {

    private let model: ConsoleModel
    private var timer: Timer?
    private var scheduledFor: Date?

    public init(model: ConsoleModel) {
        self.model = model
    }

    /// Call after anything reaches the model.
    public func poke() {
        guard let due = model.nextDeadline else {
            stop()
            return
        }
        if let scheduledFor, scheduledFor == due, timer?.isValid == true { return }
        timer?.invalidate()
        let timer = Timer(fire: max(due, Date()), interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.fire() }
        }
        // The power-up strikes its nixie rows 40 ms apart.
        timer.tolerance = 0.004
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        scheduledFor = due
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        scheduledFor = nil
    }

    private func fire() {
        timer = nil
        scheduledFor = nil
        model.advance()
        poke()
    }
}

/// The PK-4 console, running: the model, its files, its timer and every source that feeds
/// it, started and stopped with MAINS.
///
/// Views talk to `send` and read `model.snapshot`. The app hands in what only it knows —
/// the commands that reach outside the console, and readings of its own, such as which
/// Keep Awake mode is on — and forwards hook events to `ingest`.
@MainActor
public final class PK4Console {

    public let model: ConsoleModel
    public let log: FileConsoleLog
    public let directory: URL

    private let driver: ConsoleDriver
    private let extras: @MainActor () -> [Reading]
    private var machine: MachineSource?
    #if !APP_STORE
    private let readsClaudeCode: Bool
    private var claude: ClaudeCodeFeed?
    #endif
    private var sourcesRunning = false

    /// - Parameters:
    ///   - directory: where the desk's memory and its logs are kept.
    ///   - commands: how the buttons that reach outside the console are carried out.
    ///   - readsClaudeCode: whether to read `~/.claude`. Off in tests, and not possible in
    ///     the App Store build, where only hook events reach the console.
    ///   - extras: readings the app contributes, collected with each machine reading.
    public init(
        directory: URL = ConsoleFolder.url,
        commands: ConsoleCommands,
        readsClaudeCode: Bool = true,
        extras: @escaping @MainActor () -> [Reading] = { [] }
    ) {
        self.directory = directory
        self.extras = extras
        log = FileConsoleLog(directory: directory)
        model = ConsoleModel(
            clock: SystemClock(), store: FileConsoleStore(directory: directory), log: log,
            commands: commands)
        driver = ConsoleDriver(model: model)
        #if !APP_STORE
        self.readsClaudeCode = readsClaudeCode
        #endif
        syncSources()
        driver.poke()
    }

    public func send(_ intent: ConsoleIntent) {
        model.send(intent)
        syncSources()
        driver.poke()
    }

    public func ingest(_ readings: [Reading]) {
        guard !readings.isEmpty else { return }
        model.ingest(readings)
        driver.poke()
    }

    /// Stops everything and writes the desk's memory. Call before letting go of it.
    public func shutDown() {
        stopSources()
        driver.stop()
        model.flush()
    }

    public var isReadingSources: Bool { sourcesRunning }

    // MARK: - Sources follow MAINS

    private func syncSources() {
        model.isPowered ? startSources() : stopSources()
    }

    private func startSources() {
        guard !sourcesRunning else { return }
        sourcesRunning = true

        let machine = MachineSource { [weak self] readings in
            guard let self else { return }
            self.ingest(readings + self.extras())
        }
        machine.start()
        self.machine = machine

        #if !APP_STORE
        if readsClaudeCode {
            let claude = ClaudeCodeFeed { [weak self] batch in
                guard let self else { return }
                batch.issues.forEach(self.model.report)
                self.ingest(batch.readings)
            }
            claude.start()
            self.claude = claude
        }
        #endif
    }

    private func stopSources() {
        guard sourcesRunning else { return }
        sourcesRunning = false
        machine?.stop()
        machine = nil
        #if !APP_STORE
        claude?.stop()
        claude = nil
        #endif
    }
}
