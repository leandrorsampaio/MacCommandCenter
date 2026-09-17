import CommandCore
import Foundation

/// A command built from a config entry rather than written in Swift.
///
/// This is what makes the panel data-driven: the registry, the panel, the HTTP API and
/// the CLI all see an ordinary `CommandHandling`, and none of them know a JSON file
/// decided what the button says or does.
@MainActor
public final class ConfiguredCommand: CommandHandling {

    public var stateDidChange: (() -> Void)?

    private let definition: ConfigCommand
    private let group: String
    private unowned let runtime: ActionRuntime

    private let assertion = SleepAssertion()
    private var activeOption: String?
    private var activatedAt: Date?
    private var runningOption: String?
    private var transientDetail: String?
    private var clearTask: Task<Void, Never>?

    public init(definition: ConfigCommand, group: String, runtime: ActionRuntime) {
        self.definition = definition
        self.group = group
        self.runtime = runtime
    }

    deinit {
        clearTask?.cancel()
    }

    // MARK: - CommandHandling

    public var descriptor: CommandDescriptor {
        CommandDescriptor(
            id: CommandID(definition.id),
            title: definition.title,
            summary: definition.summary,
            systemImage: definition.icon,
            kind: definition.kind,
            group: group,
            options: definition.options.map { option in
                if let reason = Self.unavailableReason(for: option.action) {
                    return CommandOption(
                        id: option.id,
                        title: option.title,
                        subtitle: reason,
                        systemImage: option.icon,
                        isEnabled: false,
                        latches: option.action.latches
                    )
                }
                return CommandOption(
                    id: option.id,
                    title: option.title,
                    subtitle: option.subtitle,
                    systemImage: option.icon,
                    latches: option.action.latches
                )
            }
        )
    }

    public var state: CommandState {
        if let runningOption, let option = option(runningOption) {
            return CommandState(activeOptionID: nil, detail: "Running \(option.title)\u{2026}")
        }
        if let transientDetail {
            return CommandState(activeOptionID: nil, detail: transientDetail)
        }
        guard let activeOption, let option = option(activeOption) else {
            return CommandState(activeOptionID: nil, detail: idleDetail)
        }
        return CommandState(
            activeOptionID: activeOption, detail: option.subtitle, since: activatedAt)
    }

    public func handle(_ request: CommandRequest) throws {
        switch request {
        case .deactivate:
            deactivate()
        case .activate(let optionID):
            try activate(optionID)
        case .toggle(let optionID):
            if activeOption == optionID {
                deactivate()
            } else {
                try activate(optionID)
            }
        }
    }

    static func unavailableReason(for action: ActionSpec) -> String? {
        switch action {
        case .unavailable(let reason, _):
            return reason
        case .shell where !ShellSupport.isAvailable:
            return ShellSupport.unavailableReason
        default:
            return nil
        }
    }

    // MARK: - Internals

    private var idleDetail: String {
        definition.summary.isEmpty ? "Off." : definition.summary
    }

    private func option(_ id: String) -> ConfigOption? {
        definition.options.first { $0.id == id }
    }

    private func activate(_ optionID: String) throws {
        guard let option = option(optionID) else {
            throw CommandError.unknownOption(command: definition.id, option: optionID)
        }

        clearTask?.cancel()
        transientDetail = nil

        switch option.action {
        case .keepAwake(let mode):
            try assertion.hold(
                mode == .systemAndDisplay ? .systemAndDisplay : .systemOnly,
                reason: "Mac Command Center - \(definition.title)"
            )
            if activeOption != optionID { activatedAt = Date() }
            activeOption = optionID

        case .openURL(let url):
            runtime.open(url)
            report("Opened \(url.host ?? url.lastPathComponent).")

        case .shell(let shellAction):
            guard ShellSupport.isAvailable else {
                throw CommandError.failed(ShellSupport.unavailableReason)
            }
            runShell(shellAction, optionID: optionID)

        case .unavailable(let reason, _):
            throw CommandError.failed(reason)
        }
    }

    private func deactivate() {
        clearTask?.cancel()
        assertion.release()
        activeOption = nil
        activatedAt = nil
        transientDetail = nil
        runningOption = nil
    }

    private func runShell(_ action: ShellAction, optionID: String) {
        runningOption = optionID
        stateDidChange?()

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.runningOption = nil
                self.stateDidChange?()
            }

            guard await self.runtime.authorize(action) else {
                self.report("Not allowed.")
                return
            }
            let result = await self.runtime.run(action)
            self.report(result.summary)
        }
    }

    /// Shows a one-line outcome, then falls back to the idle text.
    private func report(_ detail: String) {
        transientDetail = detail
        stateDidChange?()

        clearTask?.cancel()
        clearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, let self else { return }
            self.transientDetail = nil
            self.stateDidChange?()
        }
    }
}
