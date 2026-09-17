import Foundation

/// Stable identifier for a command. Used by the UI, the control server and the CLI,
/// so it must stay constant once shipped.
public struct CommandID: RawRepresentable, Hashable, Sendable, Codable,
    ExpressibleByStringLiteral, CustomStringConvertible
{
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public var description: String { rawValue }

    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// What a button *means*, which is a property of the command, not of the skin. A skin
/// decides what "danger" looks like; the config decides which button is dangerous.
public enum CommandRole: String, Codable, Sendable {
    case normal
    case caution
    case danger
}

/// How a command behaves, which is also how a future physical button should behave.
public enum CommandKind: String, Codable, Sendable {
    /// Fire and forget (no lasting state).
    case action
    /// One or more mutually exclusive states, plus "off".
    case mode
}

/// One selectable state of a `.mode` command (or the "on" state of a `.toggle`).
public struct CommandOption: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let systemImage: String
    /// False when the running build cannot perform this option's action. The button stays
    /// visible and explains itself rather than disappearing.
    public let isEnabled: Bool
    /// True when activating this option leaves state to turn off again, rather than
    /// doing something once. Only latching options may be restored across a registry
    /// swap — re-firing a one-shot action would run it with nobody asking.
    public let latches: Bool
    /// What this button means. A skin turns it into a colour.
    public let role: CommandRole

    public init(
        id: String,
        title: String,
        subtitle: String = "",
        systemImage: String,
        isEnabled: Bool = true,
        latches: Bool = false,
        role: CommandRole = .normal
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.latches = latches
        self.role = role
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        systemImage = try container.decodeIfPresent(String.self, forKey: .systemImage) ?? "circle"
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        latches = try container.decodeIfPresent(Bool.self, forKey: .latches) ?? false
        role = try container.decodeIfPresent(CommandRole.self, forKey: .role) ?? .normal
    }
}

/// Everything the UI (or a remote caller) needs to render a command without knowing
/// anything about its implementation.
public struct CommandDescriptor: Identifiable, Codable, Sendable {
    public let id: CommandID
    public let title: String
    public let summary: String
    public let systemImage: String
    public let kind: CommandKind
    /// Section heading in the UI. New groups appear automatically.
    public let group: String
    public let options: [CommandOption]

    public init(
        id: CommandID,
        title: String,
        summary: String,
        systemImage: String,
        kind: CommandKind,
        group: String,
        options: [CommandOption]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.systemImage = systemImage
        self.kind = kind
        self.group = group
        self.options = options
    }
}

/// The live state of a command.
public struct CommandState: Codable, Sendable, Equatable {
    /// `nil` means the command is off / idle.
    public var activeOptionID: String?
    /// Short human-readable status line.
    public var detail: String
    /// When the current state was entered.
    public var since: Date?

    public init(activeOptionID: String? = nil, detail: String = "Off", since: Date? = nil) {
        self.activeOptionID = activeOptionID
        self.detail = detail
        self.since = since
    }

    public var isActive: Bool { activeOptionID != nil }

    public static let idle = CommandState()
}

/// What a caller wants a command to do.
public enum CommandRequest: Sendable {
    case activate(optionID: String)
    case deactivate
    /// Activate, or deactivate when that option is already the active one.
    case toggle(optionID: String)
}

public enum CommandError: LocalizedError {
    case unknownCommand(String)
    case unknownOption(command: String, option: String)
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .unknownCommand(let id):
            return "No command with id '\(id)'."
        case .unknownOption(let command, let option):
            return "Command '\(command)' has no option '\(option)'."
        case .failed(let message):
            return message
        }
    }
}

/// Implemented by each concrete command. Adding a feature to the app means adding one
/// of these and registering it — nothing else in the app needs to change.
@MainActor
public protocol CommandHandling: AnyObject {
    var descriptor: CommandDescriptor { get }
    var state: CommandState { get }
    func handle(_ request: CommandRequest) throws

    /// Set by the registry on registration. A handler calls it when its state changes
    /// outside of `handle` — a shell command finishing, for instance.
    var stateDidChange: (() -> Void)? { get set }
}
