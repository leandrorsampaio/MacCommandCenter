#if !APP_STORE

import Foundation

/// Reads what Claude Code leaves on disk, and reports it as signals.
///
/// Nothing here is an API: these are the files the tool writes for its own use, so
/// every read is defensive and a missing or changed field costs one signal rather
/// than the panel. The two that matter:
///
/// - `~/.claude/sessions/<pid>.json` — one per *running* session, with its status,
///   its working directory and the session id.
/// - `~/.claude/projects/<slug>/<session-id>.jsonl` — the transcript. The last
///   assistant record carries the token usage that fills the context window, and a
///   `cost-state` record carries the running total for the session.
///
/// Left out on purpose: the five-hour and weekly quota. Claude Code does not cache it
/// anywhere on disk, and guessing at an undocumented endpoint is not something to
/// hang an instrument on.
public struct ClaudeCodeSource: SignalSource {

    public let id = "claude"

    /// The `~/.claude` directory. Injected so the tests can read a fixture.
    private let root: URL
    /// Held across polls so a transcript is read once and followed after that.
    private let follower = TranscriptFollower()

    public init(root: URL? = nil) {
        self.root =
            root
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
    }

    public func read() -> [Signal] {
        let sessions = liveSessions()
        let busy = sessions.filter { $0.status == "busy" }
        let now = Date()

        var signals: [Signal] = [
            Signal(
                id: "claude.sessions",
                label: "Sessions",
                fraction: sessions.isEmpty ? 0 : 1,
                text: Self.sessionLine(total: sessions.count, busy: busy.count),
                isActive: !sessions.isEmpty,
                updated: now
            ),
            Signal(
                id: "claude.busy",
                label: "Working",
                text: busy.first?.name,
                isActive: !busy.isEmpty,
                updated: now
            ),
        ]

        // The session to report on is the one that moved most recently — usually the
        // window you are looking at, and still the right answer when it is not.
        guard let latest = sessions.max(by: { $0.updated < $1.updated }),
            let transcript = transcript(for: latest.sessionID),
            let reading = follower.reading(for: transcript)
        else {
            return signals
        }

        if let used = reading.contextTokens {
            let window = Self.contextWindow(forModel: reading.billedModel ?? reading.model)
            // Room *left*, not room used: a gauge runs green at full, and on a panel green
            // has to mean "fine". Reporting how full the window is put the needle in the
            // green exactly when it was about to run out.
            let left = Double(max(0, window - used)) / Double(window)
            signals.append(
                Signal(
                    id: "claude.context",
                    label: "Context",
                    fraction: left,
                    text: "\(Self.compact(max(0, window - used))) left",
                    isActive: left <= 0.2,
                    updated: now
                ))
        }

        if let cost = reading.costUSD {
            signals.append(
                Signal(
                    id: "claude.cost",
                    label: "Cost at checkpoint",
                    text: String(format: "$%.2f", cost),
                    isActive: false,
                    updated: now
                ))
        }

        if reading.outputTokens > 0 || reading.inputTokens > 0 {
            signals.append(
                Signal(
                    id: "claude.tokens",
                    label: "Tokens",
                    text:
                        "\(Self.compact(reading.outputTokens)) out · "
                        + "\(Self.compact(reading.inputTokens)) in",
                    isActive: false,
                    updated: now
                ))
        }

        return signals
    }

    // MARK: - Live sessions

    struct LiveSession {
        var sessionID: String
        var status: String
        var name: String?
        var updated: Date
    }

    func liveSessions() -> [LiveSession] {
        let directory = root.appendingPathComponent("sessions", isDirectory: true)
        let contents =
            (try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil)) ?? []

        return contents.filter { $0.pathExtension == "json" }.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let sessionID = json["sessionId"] as? String
            else { return nil }

            // Milliseconds since the epoch, the way the file writes them.
            let stamp = (json["statusUpdatedAt"] as? Double) ?? (json["updatedAt"] as? Double)
            return LiveSession(
                sessionID: sessionID,
                status: (json["status"] as? String) ?? "unknown",
                name: json["name"] as? String,
                updated: stamp.map { Date(timeIntervalSince1970: $0 / 1000) } ?? .distantPast
            )
        }
    }

    /// The transcript lives under a directory named after the project, and the naming
    /// scheme is Claude Code's business — so look the session id up rather than trying
    /// to reproduce it.
    func transcript(for sessionID: String) -> URL? {
        let projects = root.appendingPathComponent("projects", isDirectory: true)
        let contents =
            (try? FileManager.default.contentsOfDirectory(
                at: projects, includingPropertiesForKeys: nil)) ?? []

        for project in contents {
            let candidate = project.appendingPathComponent(sessionID + ".jsonl")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    // MARK: - Transcript

    struct TranscriptReading: Equatable {
        /// The id on the assistant record — the API model, with no size suffix.
        var model: String?
        /// The id `cost-state` bills against, which does carry the suffix. Preferred
        /// for sizing the window, because `claude-opus-5` and `claude-opus-5[1m]` are
        /// the same model with five times the room.
        var billedModel: String?
        /// Everything occupying the context window on the last turn.
        var contextTokens: Int?
        /// As of the last checkpoint. Claude Code writes `cost-state` when a session
        /// starts, when it compacts and when it exits — not every turn — so this is
        /// the newest figure on disk rather than the figure right now.
        var costUSD: Double?
        /// Summed as each request lands, so these *are* the figure right now.
        var inputTokens = 0
        var outputTokens = 0

        /// One API request is written as several assistant records — a text block and
        /// a tool call are separate lines — and every one of them repeats that
        /// request's usage. Counting per record inflated the totals by 2.4x.
        private var countedRequests: Set<String> = []

        var hasReading: Bool {
            contextTokens != nil || costUSD != nil || outputTokens > 0
        }

        /// Records arrive oldest first and the newest of each kind wins.
        mutating func consume(_ line: Data) {
            guard let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any]
            else { return }

            switch json["type"] as? String {
            case "assistant":
                guard let message = json["message"] as? [String: Any],
                    let usage = message["usage"] as? [String: Any]
                else { return }

                let fresh =
                    (usage["input_tokens"] as? Int ?? 0)
                    + (usage["cache_creation_input_tokens"] as? Int ?? 0)
                contextTokens = fresh + (usage["cache_read_input_tokens"] as? Int ?? 0)
                model = message["model"] as? String

                let request =
                    (json["requestId"] as? String) ?? (message["id"] as? String)
                    ?? (json["uuid"] as? String)
                if let request, !countedRequests.insert(request).inserted { return }

                // Cache reads are not counted: they are the same tokens being shown
                // to the model again, not new ones sent.
                inputTokens += fresh
                outputTokens += usage["output_tokens"] as? Int ?? 0

            case "cost-state":
                costUSD = json["totalCostUSD"] as? Double
                var busiest = 0
                for (model, usage) in json["modelUsage"] as? [String: Any] ?? [:] {
                    guard let usage = usage as? [String: Any] else { continue }
                    // A session also bills a little Haiku for side work; the model
                    // whose window matters is the one doing the talking.
                    let output = usage["outputTokens"] as? Int ?? 0
                    if output > busiest {
                        busiest = output
                        billedModel = model
                    }
                }

            default:
                return
            }
        }
    }

    static func parse(lines: [Data]) -> TranscriptReading? {
        var reading = TranscriptReading()
        lines.forEach { reading.consume($0) }
        return reading.hasReading ? reading : nil
    }

    /// Follows a transcript the way `tail -f` does.
    ///
    /// Reading the tail alone was not enough. `cost-state` is a checkpoint record, and
    /// in a long session the newest one sits megabytes back from the end — a 512 KB
    /// window found it at the start of a session and lost it by the middle. Re-reading
    /// the whole file every few seconds to fix that would mean tens of megabytes of
    /// I/O a minute for two numbers.
    ///
    /// So each transcript is read once, and after that only the bytes that have
    /// appeared since. A partial last line is carried over to the next pass, because a
    /// record is nearly always still being written when the read lands mid-line.
    final class TranscriptFollower: @unchecked Sendable {

        private let lock = NSLock()
        private var path = ""
        private var offset: UInt64 = 0
        private var partial = Data()
        private var reading = TranscriptReading()

        /// One tool result can be very long; a partial line past this is a file being
        /// written faster than it is read, and is dropped rather than accumulated.
        private static let maximumPartial = 8 * 1024 * 1024
        private static let chunk = 1024 * 1024

        func reading(for url: URL) -> TranscriptReading? {
            lock.lock()
            defer { lock.unlock() }

            if path != url.path {
                path = url.path
                offset = 0
                partial = Data()
                reading = TranscriptReading()
            }

            guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
            defer { try? handle.close() }
            guard let size = try? handle.seekToEnd() else { return nil }

            // Truncated or replaced under us: start again rather than read garbage.
            if size < offset {
                offset = 0
                partial = Data()
                reading = TranscriptReading()
            }
            guard size > offset else { return reading.hasReading ? reading : nil }

            try? handle.seek(toOffset: offset)
            while let data = try? handle.read(upToCount: Self.chunk), !data.isEmpty {
                consume(data)
            }
            offset = size

            return reading.hasReading ? reading : nil
        }

        private func consume(_ data: Data) {
            var buffer = partial
            buffer.append(data)
            partial = Data()

            var start = buffer.startIndex
            while let newline = buffer[start...].firstIndex(of: UInt8(ascii: "\n")) {
                if newline > start { reading.consume(Data(buffer[start..<newline])) }
                start = buffer.index(after: newline)
            }

            let remainder = buffer[start...]
            if remainder.count <= Self.maximumPartial { partial = Data(remainder) }
        }
    }

    // MARK: - Formatting

    /// A model id says how big its window is: the `[1m]` suffix marks the long-context
    /// variants. Everything else gets the standard window, which is the safe way to be
    /// wrong — a gauge that reads too full is better than one that reads empty.
    static func contextWindow(forModel model: String?) -> Int {
        guard let model else { return 200_000 }
        return model.contains("[1m]") ? 1_000_000 : 200_000
    }

    static func compact(_ value: Int) -> String {
        switch value {
        case 1_000_000...:
            let millions = Double(value) / 1_000_000
            return millions < 10
                ? String(format: "%.1fM", millions) : "\(Int(millions.rounded()))M"
        case 1_000...:
            return "\(value / 1000)K"
        default:
            return "\(value)"
        }
    }

    static func sessionLine(total: Int, busy: Int) -> String {
        guard total > 0 else { return "None running" }
        return busy > 0 ? "\(busy) of \(total) working" : "\(total) idle"
    }
}

#endif
