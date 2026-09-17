import AppKit
import Foundation

/// Shared services a configured command needs to actually do anything.
///
/// One instance is owned by the app and handed to every command, so consent and the
/// confirmation UI live in exactly one place.
@MainActor
public final class ActionRuntime {

    public let consent: ConsentStore

    /// Set by the app to present the confirmation sheet. Left `nil`, every unapproved
    /// shell command is refused — failing closed is the only safe default.
    public var consentPrompt: ((ShellAction) async -> ShellConsent)?

    /// Set by the app to confirm a privileged URL. Left `nil`, those URLs are refused.
    public var urlConsentPrompt: ((URL) async -> ShellConsent)?

    public init(consent: ConsentStore? = nil) {
        self.consent = consent ?? ConsentStore()
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

    /// `openURL` used to hand anything straight to Launch Services, so a shared config
    /// could start an app, a script or a Shortcuts automation with no click. Web and mail
    /// links stay unprompted; anything that can start something does not.
    func authorize(url: URL) async -> Bool {
        guard ConsentStore.requiresConsent(url) else { return true }
        if consent.isApproved(url: url) { return true }
        guard let urlConsentPrompt else { return false }

        switch await urlConsentPrompt(url) {
        case .allowOnce:
            return true
        case .allowAlways:
            consent.approve(url: url)
            return true
        case .deny:
            return false
        }
    }

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
