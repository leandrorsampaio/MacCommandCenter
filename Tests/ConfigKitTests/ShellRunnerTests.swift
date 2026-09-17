import Foundation
import Testing

@testable import ConfigKit

#if !APP_STORE

/// These start real processes, so they are serialised and kept short.
@Suite(.serialized)
struct ShellRunnerTests {

    @Test func capturesOutputFromASuccessfulCommand() async {
        let result = await ShellRunner.run(ShellAction(command: "echo hello"))

        #expect(result.succeeded)
        #expect(result.summary == "hello")
    }

    @Test func reportsFailureExitCodes() async {
        let result = await ShellRunner.run(ShellAction(command: "exit 3"))

        #expect(!result.succeeded)
        #expect(result.exitCode == 3)
    }

    /// Regression for the watchdog, which used to write `timedOut` from one queue
    /// while the caller read it from another.
    @Test func killsCommandsThatOverrunTheirTimeout() async {
        let start = Date()
        let result = await ShellRunner.run(ShellAction(command: "sleep 30", timeout: 1))

        #expect(result.timedOut)
        #expect(!result.succeeded)
        #expect(result.summary == "Timed out.")
        #expect(Date().timeIntervalSince(start) < 10)
    }

    /// Regression: a detached command was handed a pipe nobody ever read, so it
    /// wedged forever as soon as it produced more than a buffer's worth of output.
    @Test func detachedCommandsFinishEvenWhenTheyAreChatty() async throws {
        let marker = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mcc-detached-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: marker) }

        let result = await ShellRunner.run(
            ShellAction(
                command: "head -c 300000 /dev/zero | base64; touch '\(marker.path)'",
                detached: true
            )
        )
        #expect(result.succeeded)

        var finished = false
        for _ in 0..<100 where !finished {
            if FileManager.default.fileExists(atPath: marker.path) {
                finished = true
            } else {
                try await Task.sleep(for: .milliseconds(100))
            }
        }

        #expect(finished, "a detached command producing output never completed")
    }

    @Test func reportsCommandsThatCannotStart() async {
        let result = await ShellRunner.run(
            ShellAction(command: "definitely-not-a-real-binary-xyz")
        )

        #expect(!result.succeeded)
    }
}

#endif
