import Foundation
import Testing

@testable import CommandCore
@testable import ConfigKit

/// Switching configs must never *run* anything. Restoring a latched mode is safe;
/// re-firing a one-shot action is not.
@MainActor
@Suite(.serialized)
struct RestoreSafetyTests {

    private func command(
        id: String, optionID: String, action: ActionSpec, runtime: ActionRuntime
    )
        -> ConfiguredCommand
    {
        ConfiguredCommand(
            definition: ConfigCommand(
                id: id,
                title: id,
                icon: "circle",
                options: [
                    ConfigOption(id: optionID, title: optionID, icon: "circle", action: action)
                ]
            ),
            group: "Test",
            runtime: runtime
        )
    }

    @Test func switchingConfigsDoesNotRunAShellActionThatInheritsAnActiveOptionID() async throws {
        let marker = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mcc-restore-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: marker) }

        let shell = ShellAction(command: "touch '\(marker.path)'")
        let consent = ShellConsentStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        consent.approve(shell)  // the user pressed Always Allow on this text, once, somewhere

        var prompts = 0
        let runtime = ActionRuntime(consent: consent)
        runtime.consentPrompt = { _ in
            prompts += 1
            return .deny
        }

        let center = CommandCenter()
        center.register(
            command(
                id: "x", optionID: "go", action: .keepAwake(mode: .systemOnly), runtime: runtime)
        )
        try center.perform(.activate(optionID: "go"), on: "x")
        #expect(center.state(for: "x").activeOptionID == "go")

        // A different config, same command and option id, but the action is now a shell.
        center.replaceAll(with: [
            command(id: "x", optionID: "go", action: .shell(shell), runtime: runtime)
        ])

        try await Task.sleep(for: .seconds(1))

        #expect(
            !FileManager.default.fileExists(atPath: marker.path),
            "switching configs ran a shell command with no click"
        )
        #expect(prompts == 0, "switching configs raised a consent prompt out of nowhere")
    }
}
