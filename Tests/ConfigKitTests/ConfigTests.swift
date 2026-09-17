import Foundation
import Testing

@testable import ConfigKit

struct ConfigCodecTests {

    private static let sample = ##"""
        {
          "format": 1,
          "id": "sample",
          "name": "Sample",
          "groups": [
            {
              "id": "power",
              "title": "Power",
              "commands": [
                {
                  "id": "keep-awake",
                  "title": "Keep Awake",
                  "icon": "cup.and.saucer.fill",
                  "options": [
                    { "id": "on",  "title": "On",  "icon": "sun.max.fill",
                      "action": { "type": "keepAwake", "mode": "systemAndDisplay" } },
                    { "id": "off", "title": "Off", "icon": "moon.zzz.fill",
                      "action": { "type": "keepAwake", "mode": "systemOnly" } }
                  ]
                },
                {
                  "id": "tools",
                  "title": "Tools",
                  "options": [
                    { "id": "site", "title": "Site", "icon": "link",
                      "action": { "type": "openURL", "url": "https://example.com" } },
                    { "id": "df", "title": "Disk", "icon": "internaldrive",
                      "action": { "type": "shell", "command": "df -h /", "timeout": 12, "detached": true } }
                  ]
                }
              ]
            }
          ]
        }
        """##

    private func decoded() throws -> AppConfig {
        try ConfigCodec.decode(
            Data(Self.sample.utf8), fallbackID: "x", folderURL: nil, isBuiltIn: false)
    }

    @Test func decodesTheWholeTree() throws {
        let config = try decoded()

        #expect(config.id == "sample")
        #expect(config.groups.count == 1)
        #expect(config.allCommands.count == 2)
        #expect(config.groups[0].commands[0].options.count == 2)
    }

    @Test func decodesEachActionType() throws {
        let config = try decoded()
        let keepAwake = config.groups[0].commands[0].options[0].action
        let open = config.groups[0].commands[1].options[0].action
        let shell = config.groups[0].commands[1].options[1].action

        #expect(keepAwake == .keepAwake(mode: .systemAndDisplay))
        #expect(open == .openURL(URL(string: "https://example.com")!))
        #expect(shell == .shell(ShellAction(command: "df -h /", timeout: 12, detached: true)))
    }

    /// Kind is derived from the actions, so a config cannot claim a button latches when
    /// its action does not.
    @Test func kindFollowsTheActions() throws {
        let config = try decoded()

        #expect(config.groups[0].commands[0].kind == .mode)  // keep awake latches
        #expect(config.groups[0].commands[1].kind == .action)  // open and shell do not
    }

    /// Regression: the App Store build used to decode shell actions to `.unavailable`,
    /// which silently erased the command the next time the config was saved.
    @Test func shellCommandsSurviveASaveEvenWhereTheyCannotRun() throws {
        let original = try decoded()
        let reencoded = try ConfigCodec.encode(original)
        let roundTripped = try ConfigCodec.decode(
            reencoded, fallbackID: "x", folderURL: nil, isBuiltIn: false
        )

        #expect(roundTripped == original)

        guard case .shell(let action) = roundTripped.groups[0].commands[1].options[1].action else {
            Issue.record("shell action did not survive the round trip")
            return
        }
        #expect(action.command == "df -h /")
        #expect(action.timeout == 12)
        #expect(action.detached)
    }

    /// Regression: an action this build cannot read used to be rewritten as a
    /// placeholder, so opening someone's config and saving destroyed it.
    @Test func unreadableActionsSurviveARoundTrip() throws {
        let json = ##"""
            { "groups": [ { "title": "G", "commands": [
                { "id": "c", "title": "C", "options": [
                    { "id": "future", "title": "F",
                      "action": { "type": "teleport", "url": "somewhere://there" } },
                    { "id": "broken", "title": "B",
                      "action": { "type": "openURL", "url": "not a url" } } ] } ] } ] }
            """##
        let original = try ConfigCodec.decode(
            Data(json.utf8), fallbackID: "x", folderURL: nil, isBuiltIn: false)

        let reencoded = try ConfigCodec.encode(original)
        let text = String(data: reencoded, encoding: .utf8) ?? ""

        #expect(text.contains("teleport"), "an unknown action type was erased on save")
        #expect(text.contains("somewhere://there"), "its payload was erased on save")
        #expect(text.contains("not a url"), "a malformed URL was erased on save")

        let roundTripped = try ConfigCodec.decode(
            reencoded, fallbackID: "x", folderURL: nil, isBuiltIn: false)
        #expect(roundTripped == original)
    }

    @Test func unknownActionTypesBecomeExplainableButtons() {
        let action = ConfigCodec.decodeAction(ConfigCodec.Action(type: "teleport"))

        guard case .unavailable(let reason, let raw) = action else {
            Issue.record("expected an unavailable action")
            return
        }
        #expect(reason.contains("teleport"))
        #expect(raw?.type == "teleport", "the original payload must be kept")
    }

    @Test(arguments: [
        ConfigCodec.Action(type: "openURL", url: "not a url at all"),
        ConfigCodec.Action(type: "shell", command: "   "),
    ])
    func malformedActionsDegradeRatherThanThrow(action: ConfigCodec.Action) {
        if case .unavailable = ConfigCodec.decodeAction(action) { return }
        Issue.record("expected \(action.type) to degrade to .unavailable")
    }

    @Test func missingOptionalFieldsGetDefaults() throws {
        let json = ##"""
            { "groups": [ { "title": "G", "commands": [
                { "id": "c", "title": "C", "options": [
                    { "id": "o", "title": "O", "action": { "type": "keepAwake" } } ] } ] } ] }
            """##
        let config = try ConfigCodec.decode(
            Data(json.utf8), fallbackID: "fallback", folderURL: nil, isBuiltIn: false)

        #expect(config.id == "fallback")
        #expect(config.groups[0].id == "group-0")
        #expect(config.groups[0].commands[0].icon == "square.grid.2x2")
        #expect(config.groups[0].commands[0].options[0].action == .keepAwake(mode: .systemOnly))
    }
}

struct ShellActionTests {

    /// Consent is keyed by this, so an edited command must produce a different one.
    @Test func fingerprintChangesWithTheCommand() {
        let original = ShellAction(command: "echo hello")
        let edited = ShellAction(command: "echo hello; rm -rf /")

        #expect(original.fingerprint != edited.fingerprint)
    }

    @Test func fingerprintIgnoresSurroundingWhitespaceOnly() {
        #expect(
            ShellAction(command: " echo hi ").fingerprint
                == ShellAction(command: "echo hi").fingerprint)
        #expect(
            ShellAction(command: "echo  hi").fingerprint
                != ShellAction(command: "echo hi").fingerprint)
    }

    @Test func timeoutAndDetachedDoNotChangeIdentity() {
        let quick = ShellAction(command: "make", timeout: 5)
        let slow = ShellAction(command: "make", timeout: 600, detached: true)

        #expect(quick.fingerprint == slow.fingerprint)
    }
}

struct ActionSpecTests {

    @Test func onlyKeepAwakeLatches() {
        #expect(ActionSpec.keepAwake(mode: .systemOnly).latches)
        #expect(!ActionSpec.openURL(URL(string: "https://example.com")!).latches)
        #expect(!ActionSpec.shell(ShellAction(command: "ls")).latches)
        #expect(!ActionSpec.unavailable(reason: "nope", raw: nil).latches)
    }

    @Test func standardConfigIsSandboxSafe() {
        #expect(!AppConfig.standard.usesShellActions)
        #expect(AppConfig.standard.allCommands.count == 1)
    }
}

struct ConfigCatalogTests {

    @Test(arguments: [
        ("My Config", "my-config"),
        ("  Spaced  Out  ", "spaced-out"),
        ("Ünïcödé 99", "ünïcödé-99"),
    ])
    func identifiersAreSlugified(name: String, expected: String) {
        #expect(ConfigCatalog.identifier(from: name) == expected)
    }

    /// Identifiers travel in HTTP paths, so whatever they contain must survive encoding.
    @Test(arguments: ["My Config", "Ünïcödé 99", "café"])
    func identifiersSurviveURLEncoding(name: String) throws {
        let id = ConfigCatalog.identifier(from: name)
        let encoded = try #require(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed))
        let url = try #require(URL(string: "http://127.0.0.1:8787/v1/commands/\(encoded)/toggle"))

        #expect(url.path.contains(id))
    }

    @Test func emptyNamesStillGetAnIdentifier() {
        #expect(!ConfigCatalog.identifier(from: "!!!").isEmpty)
    }

    @Test func findsBothPackageAndBareManifests() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let package = root.appendingPathComponent("Alpha.mccconfig", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: package.appendingPathComponent("config.json"))
        try Data("{}".utf8).write(to: root.appendingPathComponent("Beta.json"))
        // A folder with no manifest must simply be skipped.
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Empty.mccconfig"), withIntermediateDirectories: true
        )

        let found = ConfigCatalog.manifestURLs(in: root).map(\.lastPathComponent)

        #expect(found.sorted() == ["Beta.json", "config.json"])
    }
}

@MainActor
struct ConsentStoreTests {

    private func isolatedStore() -> ConsentStore {
        ConsentStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    @Test func approvingOneCommandDoesNotApproveAnother() {
        let store = isolatedStore()
        store.approve(ShellAction(command: "echo safe"))

        #expect(store.isApproved(ShellAction(command: "echo safe")))
        #expect(!store.isApproved(ShellAction(command: "rm -rf ~")))
    }

    /// The digest only indexes the store. If a crafted command ever lands on an approved
    /// key, the stored text must still refuse it — otherwise a shared config could run
    /// something the user was never shown.
    @Test func aMatchingKeyAloneDoesNotAuthorise() {
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        let approvedAction = ShellAction(command: "echo safe")

        // Stand in for a digest collision: the approved key now holds different text.
        suite.set([approvedAction.fingerprint: "rm -rf ~"], forKey: "approvedShellCommands")
        let store = ConsentStore(defaults: suite)

        #expect(store.approved[approvedAction.fingerprint] == "rm -rf ~")
        #expect(!store.isApproved(approvedAction), "a key match must not be enough on its own")
    }

    @Test func editingACommandRevokesIt() {
        let store = isolatedStore()
        store.approve(ShellAction(command: "make deploy"))

        #expect(!store.isApproved(ShellAction(command: "make deploy --force")))
    }

    @Test func surroundingWhitespaceDoesNotChangeApproval() {
        let store = isolatedStore()
        store.approve(ShellAction(command: "  make deploy  "))

        #expect(store.isApproved(ShellAction(command: "make deploy")))
    }

    @Test func revokingRemovesApproval() {
        let store = isolatedStore()
        let action = ShellAction(command: "echo hi")
        store.approve(action)
        store.revoke(fingerprint: action.fingerprint)

        #expect(!store.isApproved(action))
    }
}

struct DuplicateIDTests {

    private func config(commands: [ConfigCommand]) -> AppConfig {
        AppConfig(
            id: "x",
            name: "Sample",
            groups: [ConfigGroup(id: "g", title: "G", commands: commands)]
        )
    }

    private func command(id: String, optionIDs: [String]) -> ConfigCommand {
        ConfigCommand(
            id: id,
            title: id,
            icon: "circle",
            options: optionIDs.map {
                ConfigOption(
                    id: $0, title: $0, icon: "circle", action: .keepAwake(mode: .systemOnly))
            }
        )
    }

    @Test func cleanConfigsReportNothing() {
        let sample = config(commands: [
            command(id: "a", optionIDs: ["one", "two"]),
            command(id: "b", optionIDs: ["one"]),
        ])

        #expect(ConfigCatalog.duplicateIDProblems(in: sample).isEmpty)
    }

    /// A repeated command id used to replace the earlier one in the registry without a
    /// word, leaving a button on screen that did nothing.
    @Test func repeatedCommandIDsAreReported() {
        let sample = config(commands: [
            command(id: "a", optionIDs: ["one"]),
            command(id: "a", optionIDs: ["two"]),
        ])

        let problems = ConfigCatalog.duplicateIDProblems(in: sample)

        #expect(problems.count == 1)
        #expect(problems[0].contains("'a'"))
    }

    @Test func repeatedOptionIDsAreReported() {
        let sample = config(commands: [command(id: "a", optionIDs: ["one", "one"])])

        let problems = ConfigCatalog.duplicateIDProblems(in: sample)

        #expect(problems.count == 1)
        #expect(problems[0].contains("'one'"))
    }
}
