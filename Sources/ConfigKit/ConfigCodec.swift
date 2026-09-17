import Foundation

/// JSON shape of a `config.json`, and the translation to and from the runtime model.
///
/// Decoding is deliberately forgiving: a config from a newer version, or one naming an
/// action this build cannot perform, still loads — the affected button explains itself
/// instead of the whole config failing.
enum ConfigCodec {

    // MARK: - Wire types

    struct Document: Codable {
        var format: Int?
        var id: String?
        var name: String?
        var author: String?
        var notes: String?
        var groups: [Group]
    }

    struct Group: Codable {
        var id: String?
        var title: String
        var commands: [Command]
    }

    struct Command: Codable {
        var id: String
        var title: String
        var summary: String?
        var icon: String?
        var options: [Option]
    }

    struct Option: Codable {
        var id: String
        var title: String
        var subtitle: String?
        var icon: String?
        var action: Action
    }

    struct Action: Codable {
        var type: String
        var mode: String?
        var url: String?
        var command: String?
        var timeout: Double?
        var detached: Bool?
    }

    // MARK: - Decoding

    static func decode(
        _ data: Data, fallbackID: String, folderURL: URL?, isBuiltIn: Bool
    ) throws -> AppConfig {
        let document = try JSONDecoder().decode(Document.self, from: data)
        return AppConfig(
            id: document.id ?? fallbackID,
            name: document.name ?? fallbackID,
            author: document.author ?? "",
            notes: document.notes ?? "",
            isBuiltIn: isBuiltIn,
            folderURL: folderURL,
            groups: document.groups.enumerated().map { index, group in
                ConfigGroup(
                    id: group.id ?? "group-\(index)",
                    title: group.title,
                    commands: group.commands.map(decodeCommand)
                )
            }
        )
    }

    private static func decodeCommand(_ command: Command) -> ConfigCommand {
        ConfigCommand(
            id: command.id,
            title: command.title,
            summary: command.summary ?? "",
            icon: command.icon ?? "square.grid.2x2",
            options: command.options.map { option in
                ConfigOption(
                    id: option.id,
                    title: option.title,
                    subtitle: option.subtitle ?? "",
                    icon: option.icon ?? "circle",
                    action: decodeAction(option.action)
                )
            }
        )
    }

    static func decodeAction(_ action: Action) -> ActionSpec {
        switch action.type {
        case "keepAwake":
            let mode = KeepAwakeMode(rawValue: action.mode ?? "") ?? .systemOnly
            return .keepAwake(mode: mode)

        case "openURL":
            guard let string = action.url, let url = URL(string: string), url.scheme != nil else {
                return .unavailable(reason: "This button has no valid URL.")
            }
            return .openURL(url)

        case "shell":
            guard let command = action.command,
                !command.trimmingCharacters(in: .whitespaces).isEmpty
            else {
                return .unavailable(reason: "This button has no command to run.")
            }
            // Always decoded, even where it cannot run: dropping it here would erase
            // the command text the next time the config was saved.
            return .shell(
                ShellAction(
                    command: command,
                    timeout: action.timeout ?? 30,
                    detached: action.detached ?? false
                ))

        default:
            return .unavailable(reason: "Unknown action type '\(action.type)'.")
        }
    }

    // MARK: - Encoding

    /// Used when the Settings editor saves a config back to disk.
    static func encode(_ config: AppConfig) throws -> Data {
        let document = Document(
            format: 1,
            id: config.id,
            name: config.name,
            author: config.author,
            notes: config.notes,
            groups: config.groups.map { group in
                Group(
                    id: group.id,
                    title: group.title,
                    commands: group.commands.map { command in
                        Command(
                            id: command.id,
                            title: command.title,
                            summary: command.summary.isEmpty ? nil : command.summary,
                            icon: command.icon,
                            options: command.options.map { option in
                                Option(
                                    id: option.id,
                                    title: option.title,
                                    subtitle: option.subtitle.isEmpty ? nil : option.subtitle,
                                    icon: option.icon,
                                    action: encodeAction(option.action)
                                )
                            }
                        )
                    }
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(document)
    }

    static func encodeAction(_ action: ActionSpec) -> Action {
        switch action {
        case .keepAwake(let mode):
            return Action(type: "keepAwake", mode: mode.rawValue)
        case .openURL(let url):
            return Action(type: "openURL", url: url.absoluteString)
        case .shell(let shell):
            return Action(
                type: "shell",
                command: shell.command,
                timeout: shell.timeout,
                detached: shell.detached
            )
        case .unavailable:
            // Round-trips as a no-op rather than silently dropping the button.
            return Action(type: "unavailable")
        }
    }
}
