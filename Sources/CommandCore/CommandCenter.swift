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
    /// Latching options that survive the swap are switched back on, so merely saving a
    /// file does not let the Mac fall asleep. One-shot options are never restored: an id
    /// that meant "stay awake" in one config can mean "run this command" in another, and
    /// re-firing it would run it with nobody asking.
    public func replaceAll(
        with newHandlers: [any CommandHandling],
        preservingActiveOptions: Bool = true
    ) {
        let wasActive: [CommandID: String] =
            preservingActiveOptions ? states.compactMapValues(\.activeOptionID) : [:]

        deactivateAll()
        // Detach the outgoing handlers first: work already in flight would otherwise
        // report into the registry entry now owned by their replacement.
        for handler in handlers.values {
            handler.stateDidChange = nil
        }
        handlers.removeAll()
        descriptors.removeAll()
        states.removeAll()
        lastError = nil
        register(newHandlers)

        for (id, optionID) in wasActive {
            guard let option = descriptor(for: id)?.options.first(where: { $0.id == optionID }),
                option.isEnabled,
                option.latches
            else { continue }
            _ = try? perform(.activate(optionID: optionID), on: id)
        }
    }

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
    ///
    /// Only writes what actually moved: an unconditional assignment fires every observer
    /// on every tick, which redraws the panel and re-runs the menu bar bridge for nothing.
    public func refresh() {
        for (id, handler) in handlers {
            let current = handler.state
            if states[id] != current { states[id] = current }
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
