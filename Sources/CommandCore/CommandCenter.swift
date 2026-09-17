import Foundation
import Observation

/// The registry every front end talks to: the menu bar UI, the local control server
/// and (later) physical buttons all go through this one object.
@MainActor
@Observable
public final class CommandCenter {

    public private(set) var descriptors: [CommandDescriptor] = []
    public private(set) var states: [CommandID: CommandState] = [:]
    public private(set) var lastError: String?

    @ObservationIgnored
    private var handlers: [CommandID: any CommandHandling] = [:]

    public init() {}

    // MARK: - Registration

    public func register(_ handler: any CommandHandling) {
        let descriptor = handler.descriptor
        handlers[descriptor.id] = handler
        handler.stateDidChange = { [weak self, weak handler] in
            guard let self, let handler else { return }
            self.states[descriptor.id] = handler.state
        }
        if let index = descriptors.firstIndex(where: { $0.id == descriptor.id }) {
            descriptors[index] = descriptor
        } else {
            descriptors.append(descriptor)
        }
        states[descriptor.id] = handler.state
    }

    public func register(_ newHandlers: [any CommandHandling]) {
        newHandlers.forEach(register)
    }

    /// Replaces the whole registry, used when a different config is selected.
    ///
    /// Anything still present after the swap is switched back on. Editing an unrelated
    /// button — or merely saving the file — must not quietly let the Mac fall asleep in
    /// the middle of the work the app exists to protect.
    public func replaceAll(
        with newHandlers: [any CommandHandling],
        preservingActiveOptions: Bool = true
    ) {
        let wasActive: [CommandID: String] =
            preservingActiveOptions ? states.compactMapValues(\.activeOptionID) : [:]

        deactivateAll()
        handlers.removeAll()
        descriptors.removeAll()
        states.removeAll()
        lastError = nil
        register(newHandlers)

        for (id, optionID) in wasActive {
            guard let descriptor = descriptor(for: id),
                descriptor.options.contains(where: { $0.id == optionID && $0.isEnabled })
            else { continue }
            _ = try? perform(.activate(optionID: optionID), on: id)
        }
    }

    // MARK: - Lookup

    public func descriptor(for id: CommandID) -> CommandDescriptor? {
        descriptors.first { $0.id == id }
    }

    public func state(for id: CommandID) -> CommandState {
        states[id] ?? .idle
    }

    /// Group names in registration order, for sectioned UI.
    public var groups: [String] {
        var seen = Set<String>()
        return descriptors.compactMap { seen.insert($0.group).inserted ? $0.group : nil }
    }

    public func descriptors(in group: String) -> [CommandDescriptor] {
        descriptors.filter { $0.group == group }
    }

    public var activeCommands: [CommandDescriptor] {
        descriptors.filter { state(for: $0.id).isActive }
    }

    public var isAnythingActive: Bool { !activeCommands.isEmpty }

    // MARK: - Invocation

    @discardableResult
    public func perform(_ request: CommandRequest, on id: CommandID) throws -> CommandState {
        guard let handler = handlers[id] else {
            throw CommandError.unknownCommand(id.rawValue)
        }
        do {
            try handler.handle(request)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            states[id] = handler.state
            throw error
        }
        let newState = handler.state
        states[id] = newState
        return newState
    }

    /// Convenience used by the UI: never throws, records the message instead.
    public func tryPerform(_ request: CommandRequest, on id: CommandID) {
        _ = try? perform(request, on: id)
    }

    /// Re-reads every handler's state (used after wake, or on a timer).
    public func refresh() {
        for (id, handler) in handlers {
            states[id] = handler.state
        }
    }

    /// Turns everything off — used on quit so no assertion outlives the app.
    public func deactivateAll() {
        for (id, handler) in handlers {
            try? handler.handle(.deactivate)
            states[id] = handler.state
        }
    }

    public func clearError() { lastError = nil }

    // MARK: - Serialisation (control server / CLI)

    public func snapshot() -> CommandSnapshot {
        CommandSnapshot(
            ok: true,
            commands: descriptors.map { .init(descriptor: $0, state: state(for: $0.id)) },
            error: lastError
        )
    }
}

/// Wire format shared by the control server and the `mcc` CLI.
public struct CommandSnapshot: Codable, Sendable {
    public struct Entry: Codable, Sendable {
        public let descriptor: CommandDescriptor
        public let state: CommandState

        public init(descriptor: CommandDescriptor, state: CommandState) {
            self.descriptor = descriptor
            self.state = state
        }
    }

    public let ok: Bool
    public let commands: [Entry]
    public let error: String?

    public init(ok: Bool, commands: [Entry], error: String?) {
        self.ok = ok
        self.commands = commands
        self.error = error
    }
}
