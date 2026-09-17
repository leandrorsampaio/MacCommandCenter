import Foundation
import Observation

public enum ShellConsent: Sendable {
    case allowOnce
    case allowAlways
    case deny
}

/// Remembers which shell commands the user has approved.
///
/// Consent is keyed by a digest of the command text, so editing a command revokes it —
/// an edited command is a different command. Nothing here is a security boundary on its
/// own; the protection is that the exact command is shown before it is ever approved.
@MainActor
@Observable
public final class ShellConsentStore {

    private static let defaultsKey = "approvedShellCommands"

    /// Fingerprint to the command text, kept so Settings can show what was approved.
    public private(set) var approved: [String: String] = [:]

    public init() {
        approved =
            UserDefaults.standard.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:]
    }

    public func isApproved(_ action: ShellAction) -> Bool {
        approved[action.fingerprint] != nil
    }

    public func approve(_ action: ShellAction) {
        approved[action.fingerprint] = action.command
        persist()
    }

    public func revoke(fingerprint: String) {
        approved[fingerprint] = nil
        persist()
    }

    public func revokeAll() {
        approved.removeAll()
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(approved, forKey: Self.defaultsKey)
    }
}
