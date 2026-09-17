import CommandCore
import Foundation

/// A loaded config: the buttons, their words, and what they do.
///
/// Where a skin says how the panel looks, a config says what is on it. The two are
/// deliberately separate files so a user can mix any skin with any config.
public struct AppConfig: Sendable, Equatable, Identifiable {

    public var id: String
    public var name: String
    public var author: String
    public var notes: String
    public var isBuiltIn: Bool
    public var folderURL: URL?
    /// Where this config was read from: the package folder, or a bare `.json` file.
    public var sourceURL: URL?
    public var groups: [ConfigGroup]

    public init(
        id: String,
        name: String,
        author: String = "",
        notes: String = "",
        isBuiltIn: Bool = false,
        folderURL: URL? = nil,
        sourceURL: URL? = nil,
        groups: [ConfigGroup]
    ) {
        self.id = id
        self.name = name
        self.author = author
        self.notes = notes
        self.isBuiltIn = isBuiltIn
        self.folderURL = folderURL
        self.sourceURL = sourceURL
        self.groups = groups
    }

    public var allCommands: [ConfigCommand] {
        groups.flatMap(\.commands)
    }

    /// True when anything in this config would run a shell command — surfaced in the UI
    /// so an imported config announces itself before it is used.
    public var usesShellActions: Bool {
        allCommands.contains { command in
            command.options.contains { option in
                if case .shell = option.action { return true }
                return false
            }
        }
    }
}

public struct ConfigGroup: Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var commands: [ConfigCommand]

    public init(id: String, title: String, commands: [ConfigCommand]) {
        self.id = id
        self.title = title
        self.commands = commands
    }
}

public struct ConfigCommand: Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var summary: String
    public var icon: String
    public var options: [ConfigOption]

    public init(
        id: String, title: String, summary: String = "", icon: String, options: [ConfigOption]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.icon = icon
        self.options = options
    }

    /// Derived from the actions rather than declared, so a config cannot claim a button
    /// latches when its action does not.
    public var kind: CommandKind {
        options.contains { $0.action.latches } ? .mode : .action
    }

    public var descriptor: CommandDescriptor {
        CommandDescriptor(
            id: CommandID(id),
            title: title,
            summary: summary,
            systemImage: icon,
            kind: kind,
            group: "",
            options: options.map {
                CommandOption(
                    id: $0.id, title: $0.title, subtitle: $0.subtitle, systemImage: $0.icon)
            }
        )
    }
}

public struct ConfigOption: Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var icon: String
    public var action: ActionSpec
    /// What the button means. A skin turns it into a colour; the default is neutral.
    public var role: CommandRole

    public init(
        id: String,
        title: String,
        subtitle: String = "",
        icon: String,
        action: ActionSpec,
        role: CommandRole = .normal
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.action = action
        self.role = role
    }
}
