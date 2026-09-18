import Foundation
import Observation

/// Everything the panel is watching, from every source.
///
/// Two ways in, because the two kinds of reading want different shapes:
///
/// - **Polled**, from a `SignalSource` — a number that is true whenever you look at it,
///   like how full a context window is.
/// - **Pushed**, over the control API — an event that has no steady state to read back,
///   like "that agent just finished". A push carries a lifetime, so a source that stops
///   reporting stops lighting its lamp instead of lying until the next launch.
@MainActor
@Observable
public final class SignalCenter {

    public private(set) var signals: [String: Signal] = [:]

    @ObservationIgnored private var sources: [any SignalSource] = []
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var isReading = false

    /// Polled sources read on this queue: a slow disk must not stall the panel.
    @ObservationIgnored private let queue = DispatchQueue(
        label: "com.maccommandcenter.signals", qos: .utility)

    public init() {}

    public func add(_ source: any SignalSource) {
        sources.append(source)
    }

    public func signal(_ id: String) -> Signal? {
        guard let signal = signals[id], signal.isFresh() else { return nil }
        return signal
    }

    /// Anything a skin might bind to, in a stable order.
    public var all: [Signal] {
        signals.values.filter { $0.isFresh() }.sorted { $0.id < $1.id }
    }

    // MARK: - Polling

    /// Starts polling, and reads once immediately so the first frame is not blank.
    public func start(interval: TimeInterval = 4) {
        guard timer == nil, !sources.isEmpty else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { self.refresh() }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func refresh() {
        // A read that overruns the interval must not pile up behind itself.
        guard !isReading, !sources.isEmpty else { return }
        isReading = true

        let sources = self.sources
        queue.async {
            let readings = sources.flatMap { $0.read() }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.isReading = false
                    self.apply(readings)
                }
            }
        }
    }

    /// Replaces what the polled sources report, and drops anything expired.
    private func apply(_ readings: [Signal]) {
        var next = signals.filter { $0.value.isFresh() }
        for reading in readings {
            next[reading.id] = reading
        }
        if next != signals { signals = next }
    }

    // MARK: - Pushing

    public func push(_ signal: Signal) {
        signals[signal.id] = signal
    }

    /// The control API's shape: everything optional, because a hook that only wants to
    /// light a lamp should not have to invent a number for it.
    public func push(
        id: String,
        label: String?,
        fraction: Double?,
        text: String?,
        isActive: Bool,
        ttl: TimeInterval?
    ) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        push(
            Signal(
                id: trimmed,
                label: label ?? signals[trimmed]?.label ?? trimmed,
                fraction: fraction,
                text: text,
                isActive: isActive,
                expires: ttl.map { Date().addingTimeInterval(max(1, min(86400, $0))) }
            ))
    }

    public func clear(id: String) {
        signals[id] = nil
    }

    public func snapshot() -> [Signal] {
        all
    }
}
