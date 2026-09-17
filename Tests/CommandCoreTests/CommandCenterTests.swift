import Foundation
import Testing

@testable import CommandCore

@MainActor
private final class StubCommand: CommandHandling {

    var stateDidChange: (() -> Void)?
    private(set) var received: [String] = []
    private var active: String?

    let descriptor: CommandDescriptor

    init(id: String, options: [String], enabled: Bool = true, latches: Bool = true) {
        descriptor = CommandDescriptor(
            id: CommandID(id),
            title: id,
            summary: "",
            systemImage: "circle",
            kind: .mode,
            group: "Test",
            options: options.map {
                CommandOption(
                    id: $0, title: $0, systemImage: "circle", isEnabled: enabled, latches: latches)
            }
        )
    }

    var state: CommandState {
        CommandState(activeOptionID: active, detail: active ?? "off")
    }

    func handle(_ request: CommandRequest) throws {
        switch request {
        case .activate(let id):
            guard descriptor.options.contains(where: { $0.id == id }) else {
                throw CommandError.unknownOption(command: descriptor.id.rawValue, option: id)
            }
            received.append("activate:\(id)")
            active = id
        case .deactivate:
            received.append("deactivate")
            active = nil
        case .toggle(let id):
            received.append("toggle:\(id)")
            active = (active == id) ? nil : id
        }
    }

    /// Simulates an action that finishes after `handle` returned.
    func finishLater(as option: String) {
        active = option
        stateDidChange?()
    }
}

@MainActor
struct CommandCenterTests {

    @Test func registeringExposesDescriptorAndInitialState() throws {
        let center = CommandCenter()
        center.register(StubCommand(id: "a", options: ["one", "two"]))

        #expect(center.descriptors.count == 1)
        #expect(center.groups == ["Test"])
        #expect(center.state(for: "a").isActive == false)
    }

    @Test func performUpdatesPublishedState() throws {
        let center = CommandCenter()
        center.register(StubCommand(id: "a", options: ["one"]))

        try center.perform(.activate(optionID: "one"), on: "a")

        #expect(center.state(for: "a").activeOptionID == "one")
        #expect(center.isAnythingActive)
    }

    @Test func unknownCommandThrows() {
        let center = CommandCenter()
        #expect(throws: CommandError.self) {
            try center.perform(.deactivate, on: "missing")
        }
    }

    @Test func failureIsRecordedAndRethrown() {
        let center = CommandCenter()
        center.register(StubCommand(id: "a", options: ["one"]))

        #expect(throws: CommandError.self) {
            try center.perform(.activate(optionID: "nope"), on: "a")
        }
        #expect(center.lastError != nil)
    }

    /// The hook that lets a shell command report its result after `handle` returned.
    @Test func asynchronousStateChangeReachesTheRegistry() throws {
        let center = CommandCenter()
        let command = StubCommand(id: "a", options: ["one"])
        center.register(command)

        command.finishLater(as: "one")

        #expect(center.state(for: "a").activeOptionID == "one")
    }

    @Test func replaceAllTurnsOldCommandsOffFirst() throws {
        let center = CommandCenter()
        let first = StubCommand(id: "a", options: ["one"])
        center.register(first)
        try center.perform(.activate(optionID: "one"), on: "a")

        center.replaceAll(with: [StubCommand(id: "b", options: ["two"])])

        #expect(first.received.contains("deactivate"))
        #expect(center.descriptors.map(\.id.rawValue) == ["b"])
        #expect(center.states["a"] == nil)
    }

    /// Regression: rebuilding the registry when a config file changed used to turn off
    /// whatever was running — so saving an unrelated button let the Mac sleep mid-build.
    @Test func replaceAllKeepsSurvivingOptionsOn() throws {
        let center = CommandCenter()
        center.register(StubCommand(id: "a", options: ["one", "two"]))
        try center.perform(.activate(optionID: "one"), on: "a")

        center.replaceAll(with: [StubCommand(id: "a", options: ["one", "two"])])

        #expect(center.state(for: "a").activeOptionID == "one")
    }

    @Test func replaceAllDropsOptionsThatNoLongerExist() throws {
        let center = CommandCenter()
        center.register(StubCommand(id: "a", options: ["one"]))
        try center.perform(.activate(optionID: "one"), on: "a")

        center.replaceAll(with: [StubCommand(id: "a", options: ["renamed"])])

        #expect(center.state(for: "a").isActive == false)
    }

    /// An option the running build cannot perform must not be switched back on.
    @Test func replaceAllSkipsDisabledOptions() throws {
        let center = CommandCenter()
        center.register(StubCommand(id: "a", options: ["one"]))
        try center.perform(.activate(optionID: "one"), on: "a")

        center.replaceAll(with: [StubCommand(id: "a", options: ["one"], enabled: false)])

        #expect(center.state(for: "a").isActive == false)
    }

    /// A one-shot option must never be re-fired by a registry swap: the same id can mean
    /// "stay awake" in one config and "run this command" in another.
    @Test func replaceAllNeverRestoresOneShotOptions() throws {
        let center = CommandCenter()
        center.register(StubCommand(id: "a", options: ["one"]))
        try center.perform(.activate(optionID: "one"), on: "a")

        center.replaceAll(with: [StubCommand(id: "a", options: ["one"], latches: false)])

        #expect(center.state(for: "a").isActive == false)
    }

    /// Work already in flight must not report into the entry its replacement now owns.
    @Test func replacedHandlersAreDetachedFromTheRegistry() throws {
        let center = CommandCenter()
        let outgoing = StubCommand(id: "a", options: ["one"])
        center.register(outgoing)
        center.replaceAll(with: [StubCommand(id: "a", options: ["two"])])

        outgoing.finishLater(as: "one")

        #expect(center.state(for: "a").activeOptionID != "one")
    }

    @Test func replaceAllCanBeToldNotToPreserve() throws {
        let center = CommandCenter()
        center.register(StubCommand(id: "a", options: ["one"]))
        try center.perform(.activate(optionID: "one"), on: "a")

        center.replaceAll(
            with: [StubCommand(id: "a", options: ["one"])],
            preservingActiveOptions: false
        )

        #expect(center.state(for: "a").isActive == false)
    }

    @Test func snapshotCarriesEveryCommand() throws {
        let center = CommandCenter()
        center.register(StubCommand(id: "a", options: ["one"]))
        try center.perform(.activate(optionID: "one"), on: "a")

        let snapshot = center.snapshot()

        #expect(snapshot.ok)
        #expect(snapshot.commands.count == 1)
        #expect(snapshot.commands[0].state.activeOptionID == "one")
    }
}

struct CommandModelTests {

    @Test func commandIDEncodesAsABareString() throws {
        let data = try JSONEncoder().encode(CommandID("keep-awake"))
        #expect(String(data: data, encoding: .utf8) == "\"keep-awake\"")
        #expect(try JSONDecoder().decode(CommandID.self, from: data) == "keep-awake")
    }

    /// Older payloads have no `isEnabled`; they must keep decoding as enabled.
    @Test func optionDefaultsToEnabledWhenTheKeyIsAbsent() throws {
        let json = Data(#"{"id":"a","title":"A","systemImage":"circle"}"#.utf8)
        let option = try JSONDecoder().decode(CommandOption.self, from: json)

        #expect(option.isEnabled)
        #expect(option.subtitle.isEmpty)
    }
}
