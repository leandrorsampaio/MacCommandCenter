import AppKit
import Foundation

/// Shared services a configured command needs to actually do anything.
///
/// One instance is owned by the app and handed to every command, so consent and the
/// confirmation UI live in exactly one place.
@MainActor
public final class ActionRuntime {

    public let consent: ShellConsentStore

    /// Set by the app to present the confirmation sheet. Left `nil`, every unapproved
    /// shell command is refused — failing closed is the only safe default.
    public var consentPrompt: ((ShellAction) async -> ShellConsent)?

    public init(consent: ShellConsentStore? = nil) {
        self.consent = consent ?? ShellConsentStore()
    }

    /// True when the command may run now. Prompts the user if it has not been approved.
    func authorize(_ action: ShellAction) async -> Bool {
        if consent.isApproved(action) { return true }
        guard let consentPrompt else { return false }

        switch await consentPrompt(action) {
        case .allowOnce:
            return true
        case .allowAlways:
            consent.approve(action)
            return true
        case .deny:
            return false
        }
    }

    func run(_ action: ShellAction) async -> ShellResult {
        await ShellRunner.run(action)
    }

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
