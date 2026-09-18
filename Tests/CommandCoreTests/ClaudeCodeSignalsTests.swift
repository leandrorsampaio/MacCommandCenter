import Foundation
import Testing

@testable import CommandCore

#if !APP_STORE

/// These read files Claude Code writes for its own use, so the shapes are not a
/// contract. Every test here is built on a fixture rather than the real `~/.claude`:
/// a test that passes only on the machine that wrote it is not a test.
@Suite struct ClaudeCodeSignalsTests {

    // MARK: - Transcript

    @Test func readsTheLastUsageAndCostFromATranscript() throws {
        let lines = [
            #"{"type":"assistant","message":{"model":"claude-opus-5[1m]","usage":{"input_tokens":5,"cache_creation_input_tokens":100,"cache_read_input_tokens":900,"output_tokens":42}}}"#,
            #"{"type":"user","message":{"role":"user"}}"#,
            #"{"type":"assistant","message":{"model":"claude-opus-5[1m]","usage":{"input_tokens":2,"cache_creation_input_tokens":2483,"cache_read_input_tokens":135592,"output_tokens":507}}}"#,
            #"{"type":"cost-state","totalCostUSD":169.497,"modelUsage":{"claude-opus-5[1m]":{"inputTokens":5130,"outputTokens":783272,"cacheCreationInputTokens":1947798}}}"#,
        ]

        let reading = try #require(ClaudeCodeSource.parse(lines: lines.map { Data($0.utf8) }))

        // The newest usage record wins, not the first one found.
        #expect(reading.contextTokens == 138_077)
        #expect(reading.model == "claude-opus-5[1m]")
        #expect(reading.billedModel == "claude-opus-5[1m]")
        #expect(reading.costUSD == 169.497)
        // Summed across both assistant records, and cache *reads* are not new tokens.
        #expect(reading.outputTokens == 549)
        #expect(reading.inputTokens == 2590)
        #expect(reading.contextTokens == 138_077)
    }

    /// One request is written as several records — text, then each tool call — and
    /// every one repeats that request's usage. Counting per record inflated the
    /// session's token totals by 2.4x against what Claude Code itself reports.
    @Test func countsOneRequestOnceEvenWhenItIsWrittenSeveralTimes() throws {
        let line = { (request: String, output: Int) in
            #"{"type":"assistant","requestId":""# + request
                + #"","message":{"model":"claude-opus-5","usage":{"output_tokens":"#
                + String(output) + #"}}}"#
        }
        let lines = [line("req_a", 100), line("req_a", 100), line("req_b", 30)]

        let reading = try #require(ClaudeCodeSource.parse(lines: lines.map { Data($0.utf8) }))

        #expect(reading.outputTokens == 130)
    }

    @Test func aTranscriptWithNothingUsefulReportsNothing() {
        let lines = [#"{"type":"system","subtype":"boot"}"#, "not json at all"]

        #expect(ClaudeCodeSource.parse(lines: lines.map { Data($0.utf8) }) == nil)
    }

    /// A record this build does not understand must cost one reading, not the file.
    @Test func survivesRecordsItDoesNotUnderstand() throws {
        let lines = [
            #"{"type":"assistant","message":{"usage":"not an object"}}"#,
            #"{"type":"cost-state","totalCostUSD":"free"}"#,
            #"{"type":"assistant","message":{"model":"claude-sonnet-5","usage":{"input_tokens":10}}}"#,
        ]

        let reading = try #require(ClaudeCodeSource.parse(lines: lines.map { Data($0.utf8) }))

        #expect(reading.contextTokens == 10)
        #expect(reading.costUSD == nil)
    }

    /// The follower is the whole point of this file: a long transcript must not be
    /// re-read every few seconds, and its newest `cost-state` sits megabytes back.
    @Test func followsATranscriptWithoutRereadingIt() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("session.jsonl")
        let cost =
            #"{"type":"cost-state","totalCostUSD":4.5,"modelUsage":{"claude-opus-5[1m]":{"outputTokens":9}}}"#
        let turn =
            #"{"type":"assistant","message":{"model":"claude-opus-5","usage":{"input_tokens":10,"output_tokens":5}}}"#

        // No request id on these, so each record counts once on its own.
        // A checkpoint, then enough turns to push it well outside any tail window.
        var text = cost + "\n"
        text += String(repeating: turn + "\n", count: 5000)
        try text.write(to: file, atomically: true, encoding: .utf8)

        let follower = ClaudeCodeSource.TranscriptFollower()
        let first = try #require(follower.reading(for: file))
        #expect(first.costUSD == 4.5)
        #expect(first.outputTokens == 25_000)

        // Appending must add to the running totals, not restart them.
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((turn + "\n").utf8))
        try handle.close()

        let second = try #require(follower.reading(for: file))
        #expect(second.outputTokens == 25_005)
        // The checkpoint is remembered rather than re-read.
        #expect(second.costUSD == 4.5)
    }

    /// A read almost always lands while a record is being written.
    @Test func carriesAHalfWrittenRecordToTheNextPass() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("session.jsonl")
        let turn =
            #"{"type":"assistant","message":{"model":"claude-opus-5","usage":{"output_tokens":7}}}"#
        let split = turn.index(turn.startIndex, offsetBy: 30)

        try String(turn[..<split]).write(to: file, atomically: true, encoding: .utf8)
        let follower = ClaudeCodeSource.TranscriptFollower()
        #expect(follower.reading(for: file) == nil)

        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((String(turn[split...]) + "\n").utf8))
        try handle.close()

        let reading = try #require(follower.reading(for: file))
        #expect(reading.outputTokens == 7)
    }

    @Test func readsAWholeTranscriptOnTheFirstPass() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("session.jsonl")
        var text = String(
            repeating: #"{"type":"user","message":{"role":"user"}}"# + "\n", count: 20_000)
        text +=
            #"{"type":"assistant","message":{"model":"claude-sonnet-5","usage":{"input_tokens":7}}}"#
            + "\n"
        try text.write(to: file, atomically: true, encoding: .utf8)

        let reading = try #require(ClaudeCodeSource.TranscriptFollower().reading(for: file))

        #expect(reading.contextTokens == 7)
    }

    // MARK: - Context window

    /// The assistant record says `claude-opus-5`; only `cost-state` says `[1m]`.
    /// Reading the window off the assistant record sized this at 200K when it was 1M.
    @Test func theWindowComesFromTheBilledModelNotTheAssistantRecord() throws {
        let lines = [
            #"{"type":"assistant","message":{"model":"claude-opus-5","usage":{"input_tokens":400000}}}"#,
            #"{"type":"cost-state","totalCostUSD":1,"modelUsage":{"claude-haiku-4-5":{"outputTokens":13},"claude-opus-5[1m]":{"outputTokens":783272}}}"#,
        ]

        let reading = try #require(ClaudeCodeSource.parse(lines: lines.map { Data($0.utf8) }))

        #expect(reading.model == "claude-opus-5")
        // Haiku bills a few tokens for side work; it is not the model in the chair.
        #expect(reading.billedModel == "claude-opus-5[1m]")
        #expect(ClaudeCodeSource.contextWindow(forModel: reading.billedModel) == 1_000_000)
    }

    @Test func theContextWindowComesFromTheModelID() {
        #expect(ClaudeCodeSource.contextWindow(forModel: "claude-opus-5[1m]") == 1_000_000)
        #expect(ClaudeCodeSource.contextWindow(forModel: "claude-opus-5") == 200_000)
        // An id this build has never seen reads too full rather than too empty.
        #expect(ClaudeCodeSource.contextWindow(forModel: "claude-something-7") == 200_000)
        #expect(ClaudeCodeSource.contextWindow(forModel: nil) == 200_000)
    }

    // MARK: - Live sessions

    @Test func readsRunningSessionsAndPicksTheTranscriptByID() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sessions = root.appendingPathComponent("sessions", isDirectory: true)
        let project = root.appendingPathComponent("projects/-Users-me-thing", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try #"{"pid":1,"sessionId":"abc","status":"busy","name":"panel","updatedAt":1789729554427}"#
            .write(
                to: sessions.appendingPathComponent("1.json"), atomically: true, encoding: .utf8)
        try #"{"pid":2,"sessionId":"def","status":"idle","name":"other","updatedAt":1789729000000}"#
            .write(
                to: sessions.appendingPathComponent("2.json"), atomically: true, encoding: .utf8)
        try
            (#"{"type":"assistant","message":{"model":"claude-opus-5[1m]","usage":{"input_tokens":100000}}}"#
            + "\n")
            .write(
                to: project.appendingPathComponent("abc.jsonl"), atomically: true,
                encoding: .utf8)

        let source = ClaudeCodeSource(root: root)
        let signals = Dictionary(
            uniqueKeysWithValues: source.read().map { ($0.id, $0) })

        #expect(signals["claude.busy"]?.isActive == true)
        #expect(signals["claude.sessions"]?.text == "1 of 2 working")
        // The busiest-by-clock session is "abc", so its transcript is the one read.
        // 100K of a 1M window used leaves 900K, and a gauge shows what is left.
        #expect(signals["claude.context"]?.text == "900K left")
        #expect(signals["claude.context"]?.fraction == 0.9)
        #expect(signals["claude.context"]?.isActive == false)
    }

    @Test func reportsNoSessionsWithoutInventingReadings() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        let signals = Dictionary(
            uniqueKeysWithValues: ClaudeCodeSource(root: root).read().map { ($0.id, $0) })

        #expect(signals["claude.busy"]?.isActive == false)
        #expect(signals["claude.sessions"]?.text == "None running")
        #expect(signals["claude.context"] == nil)
        #expect(signals["claude.cost"] == nil)
    }

    // MARK: - Formatting

    @Test func numbersAreReadableAtAGlance() {
        #expect(ClaudeCodeSource.compact(950) == "950")
        #expect(ClaudeCodeSource.compact(138_077) == "138K")
        #expect(ClaudeCodeSource.compact(1_000_000) == "1.0M")
        #expect(ClaudeCodeSource.compact(260_821_655) == "261M")
    }
}

#endif
