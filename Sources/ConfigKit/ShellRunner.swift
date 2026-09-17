import Foundation

public struct ShellResult: Sendable {
    public let exitCode: Int32
    public let output: String
    public let timedOut: Bool

    public var succeeded: Bool { exitCode == 0 && !timedOut }

    /// A single line fit for the panel readout.
    public var summary: String {
        if timedOut { return "Timed out." }
        let firstLine =
            output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        if succeeded {
            return firstLine.isEmpty ? "Done." : String(firstLine.prefix(60))
        }
        return firstLine.isEmpty ? "Failed (\(exitCode))." : String(firstLine.prefix(60))
    }
}

/// Runs a config's shell action.
///
/// Compiled out of the App Store build entirely — the sandbox forbids it and review would
/// reject it, so the code should not be in that binary at all.
enum ShellRunner {

    #if APP_STORE

    static func run(_ action: ShellAction) async -> ShellResult {
        ShellResult(
            exitCode: 1, output: "Shell actions need the direct download build.", timedOut: false)
    }

    #else

    static func run(_ action: ShellAction) async -> ShellResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: execute(action))
            }
        }
    }

    private static func execute(_ action: ShellAction) -> ShellResult {
        let process = Process()
        // A login shell, so PATH, rbenv/nvm shims and aliases behave the way they do in
        // the user's own terminal — which is where these commands were written.
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", action.command]

        // Nothing reads a detached command's output, so it must go nowhere. Handing it a
        // pipe would wedge the command forever once the buffer filled.
        let pipe: Pipe? = action.detached ? nil : Pipe()
        process.standardOutput = pipe ?? FileHandle.nullDevice
        process.standardError = pipe ?? FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return ShellResult(exitCode: 127, output: error.localizedDescription, timedOut: false)
        }

        guard let pipe else {
            return ShellResult(exitCode: 0, output: "Started.", timedOut: false)
        }

        // Read on a worker so a chatty command cannot fill the pipe buffer and deadlock
        // against our own wait.
        let outputQueue = DispatchQueue(label: "mcc.shell.output")
        var collected = Data()
        let finishedReading = DispatchSemaphore(value: 0)
        outputQueue.async {
            collected = pipe.fileHandleForReading.readDataToEndOfFile()
            finishedReading.signal()
        }

        // Written by the watchdog, read here: it needs a lock, not a bare Bool.
        let timedOut = Flag()
        let watchdog = DispatchWorkItem {
            if process.isRunning {
                timedOut.set()
                process.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(
            deadline: .now() + max(1, action.timeout), execute: watchdog)

        process.waitUntilExit()
        watchdog.cancel()
        _ = finishedReading.wait(timeout: .now() + 2)

        let output = String(data: collected, encoding: .utf8) ?? ""
        return ShellResult(
            exitCode: process.terminationStatus,
            output: output,
            timedOut: timedOut.isSet
        )
    }

    /// A Bool shared between the watchdog queue and the caller.
    private final class Flag: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false

        func set() {
            lock.lock()
            defer { lock.unlock() }
            value = true
        }

        var isSet: Bool {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

    #endif
}
