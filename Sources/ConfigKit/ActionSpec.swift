import Foundation

/// What a button does when pressed.
///
/// Adding a case here is how the app gains a new kind of capability. Each case must
/// declare whether it *latches* — a keep-awake button stays lit until pressed again, a
/// shell button fires and returns.
public enum ActionSpec: Sendable, Equatable {

    /// Holds an IOKit power assertion.
    case keepAwake(mode: KeepAwakeMode)

    /// Opens a URL, a file or an app with the user's default handler.
    case openURL(URL)

    /// Runs a shell command.
    ///
    /// Unavailable in the App Store build, and gated behind explicit per-command consent
    /// everywhere else — a config downloaded from a stranger must not be able to run code
    /// just because someone clicked a nice-looking button.
    case shell(ShellAction)

    /// A recognised action the running build cannot perform, kept so the button can
    /// explain itself rather than vanishing.
    case unavailable(reason: String)

    /// True when activating this action leaves lasting state to turn off again.
    public var latches: Bool {
        switch self {
        case .keepAwake: return true
        case .openURL, .shell, .unavailable: return false
        }
    }
}

/// Whether this binary can run shell actions at all.
///
/// The App Store build is sandboxed, so it cannot — but it still loads configs that use
/// them and says so on the button, rather than pretending they do not exist.
public enum ShellSupport {

    public static var isAvailable: Bool {
        #if APP_STORE
        false
        #else
        true
        #endif
    }

    public static let unavailableReason = "Needs the direct download build"
}

public enum KeepAwakeMode: String, Sendable, Codable, CaseIterable {
    /// Mac and display both stay on.
    case systemAndDisplay
    /// Mac stays on, display may sleep.
    case systemOnly

    public var title: String {
        switch self {
        case .systemAndDisplay: return "Mac and display stay on"
        case .systemOnly: return "Mac stays on, display may sleep"
        }
    }
}

public struct ShellAction: Sendable, Equatable, Codable {

    /// The command line, run through a login shell so `PATH` and aliases behave the way
    /// they do in the user's terminal.
    public var command: String
    /// Seconds before the command is killed. Keeps a hung script from leaking processes.
    public var timeout: Double
    /// When true the command is fired and forgotten; otherwise its output is captured
    /// and shown in the readout.
    public var detached: Bool

    public init(command: String, timeout: Double = 30, detached: Bool = false) {
        self.command = command
        self.timeout = timeout
        self.detached = detached
    }

    /// The exact text consent is granted for. Approval is always checked against this,
    /// never against the digest alone.
    public var normalizedCommand: String {
        command.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Lookup key for the consent store. Changing the command revokes consent, which is
    /// the entire point: an edited command is a new command.
    public var fingerprint: String {
        Self.digest(normalizedCommand)
    }

    /// FNV-1a, used only to index the store. It is **not** a security boundary: a digest
    /// this short is cheap to collide deliberately, so a matching key alone must never
    /// authorise anything. `ShellConsentStore` compares the stored command text.
    static func digest(_ text: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in Array(text.utf8) {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}
