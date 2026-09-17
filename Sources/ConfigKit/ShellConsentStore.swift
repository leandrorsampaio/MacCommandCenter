import Foundation
import Observation

public enum ShellConsent: Sendable {
    case allowOnce
    case allowAlways
    case deny
}

/// Remembers which shell commands the user has approved.
///
/// The digest is only an index. Approval belongs to an exact command *string*, and that
/// string is what gets compared — otherwise a config could ship a command crafted to
/// collide with one the user had already approved and run without ever being shown.
@MainActor
@Observable
public final class ShellConsentStore {

    private static let defaultsKey = "approvedShellCommands"

    /// Fingerprint to the approved command text, kept so Settings can show what was
    /// approved and so approval can be verified against the text itself.
    public private(set) var approved: [String: String] = [:]

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        approved = defaults.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:]
    }

    public func isApproved(_ action: ShellAction) -> Bool {
        approved[action.fingerprint] == action.normalizedCommand
    }

    public func approve(_ action: ShellAction) {
        approved[action.fingerprint] = action.normalizedCommand
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
        defaults.set(approved, forKey: Self.defaultsKey)
    }
}
