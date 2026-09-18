import Foundation

/// How a skin composes the panel.
///
/// A skin that omits `layout` gets the original stack, so every skin written before this
/// existed keeps working. One that supplies it arranges the panel from a fixed vocabulary
/// of slots — the app still draws every part, so a skin remains a data file rather than
/// code, but *what goes where* stops being hard-coded.
public struct SkinLayout: Sendable, Equatable {

    public var rows: [SkinSlot]

    public init(rows: [SkinSlot]) {
        self.rows = rows
    }

    /// What every skin got before layouts existed.
    public static let stack = SkinLayout(rows: [
        .readout(ReadoutSpec(style: .lcd)),
        .commands(style: .tile, columns: 0),
    ])
}

public indirect enum SkinSlot: Sendable, Equatable {
    /// The engraved header plate. Falls back to the config's name when no text is given.
    case nameplate(title: String?, subtitle: String?)
    /// One backlit legend cell per command, lit when that command is engaged.
    case annunciator
    case readout(ReadoutSpec)
    case gauge(GaugeSpec)
    /// The command buttons. `columns` of 0 means "one row, share the width".
    case commands(style: CommandStyle, columns: Int)
    /// A row of indicator lamps. What they watch is `sources`.
    case lamps(style: LampStyle, sources: [LampSource])
    /// Float-on-top and close, as panel controls rather than titlebar boxes. Each takes
    /// an optional label and sub-label so a skin can word them in its own language.
    case controls(labels: ControlLabels)
    /// Pushes everything after it to the bottom.
    case spacer
    /// Lays its children out side by side.
    case row([SkinSlot])
}

/// Wording for the panel controls. Anything left out falls back to English.
public struct ControlLabels: Sendable, Equatable {
    public var onTop: String?
    public var onTopNote: String?
    public var close: String?
    public var closeNote: String?

    public init(
        onTop: String? = nil, onTopNote: String? = nil,
        close: String? = nil, closeNote: String? = nil
    ) {
        self.onTop = onTop
        self.onTopNote = onTopNote
        self.close = close
        self.closeNote = closeNote
    }
}

// MARK: - What an instrument is wired to

/// The needle's input.
public enum GaugeSource: Sendable, Equatable {
    case battery
    /// A named signal, written `"signal:claude.context"`.
    case signal(String)

    public init?(raw: String) {
        if raw == "battery" {
            self = .battery
        } else if let name = Self.signalName(raw) {
            self = .signal(name)
        } else {
            return nil
        }
    }

    static func signalName(_ raw: String) -> String? {
        let prefix = "signal:"
        guard raw.hasPrefix(prefix) else { return nil }
        let name = String(raw.dropFirst(prefix.count))
        return name.isEmpty ? nil : name
    }
}

/// A line of a readout.
public enum ReadoutSource: Sendable, Equatable {
    /// How long the active command has been engaged.
    case uptime
    /// What is engaged right now.
    case mode
    case signal(String)

    public init?(raw: String) {
        switch raw {
        case "uptime": self = .uptime
        case "mode": self = .mode
        default:
            guard let name = GaugeSource.signalName(raw) else { return nil }
            self = .signal(name)
        }
    }
}

/// What a lamp watches.
public enum LampSource: Sendable, Equatable {
    /// One lamp per command in the config, lit when that command is engaged.
    case commands
    case battery
    case signal(String)

    public init?(raw: String) {
        switch raw {
        case "commands": self = .commands
        case "battery": self = .battery
        default:
            guard let name = GaugeSource.signalName(raw) else { return nil }
            self = .signal(name)
        }
    }
}

// MARK: - Instrument specs

public struct GaugeSpec: Sendable, Equatable {
    public var source: GaugeSource
    public var width: Double?
    /// The module caption. Defaults to what the source calls itself.
    public var caption: String?
    /// The small legend in the caption strip's far corner.
    public var trailing: String?

    public init(
        source: GaugeSource, width: Double? = nil, caption: String? = nil,
        trailing: String? = nil
    ) {
        self.source = source
        self.width = width
        self.caption = caption
        self.trailing = trailing
    }
}

public struct ReadoutSpec: Sendable, Equatable {
    public var style: ReadoutStyle
    public var caption: String?
    public var trailing: String?
    public var primary: ReadoutSource
    public var primaryCaption: String?
    public var secondary: ReadoutSource
    public var secondaryCaption: String?

    public init(
        style: ReadoutStyle,
        caption: String? = nil,
        trailing: String? = nil,
        primary: ReadoutSource = .uptime,
        primaryCaption: String? = nil,
        secondary: ReadoutSource = .mode,
        secondaryCaption: String? = nil
    ) {
        self.style = style
        self.caption = caption
        self.trailing = trailing
        self.primary = primary
        self.primaryCaption = primaryCaption
        self.secondary = secondary
        self.secondaryCaption = secondaryCaption
    }
}

public enum ReadoutStyle: String, Sendable, Codable {
    /// The original single strip.
    case lcd
    /// A large glowing counter plus a mode line.
    case nixie
}

public enum LampStyle: String, Sendable, Codable {
    /// A printed caption under each lamp.
    case plain
    /// A strip of tape with the name written on it, the way a panel gets relabelled
    /// after the drawings stop matching the wiring.
    case tape
}

public enum CommandStyle: String, Sendable, Codable {
    /// Icon, title and subtitle in a tall card. The original.
    case tile
    /// A latching relief key: it stays down until pressed again.
    case key
}

// MARK: - Decoding

extension SkinLayout {

    /// Tolerant by design: an unrecognised slot is skipped rather than failing the skin,
    /// so a layout written for a later version still renders what this build understands.
    init?(json: Any?) {
        guard let rows = json as? [Any] else { return nil }
        let slots = rows.compactMap(SkinSlot.init(json:))
        guard !slots.isEmpty else { return nil }
        self.init(rows: slots)
    }
}

extension SkinSlot {

    init?(json: Any) {
        guard let entry = json as? [String: Any], let slot = entry["slot"] as? String else {
            return nil
        }

        switch slot {
        case "nameplate":
            self = .nameplate(
                title: entry["text"] as? String,
                subtitle: entry["subtitle"] as? String
            )
        case "annunciator": self = .annunciator

        case "lamps":
            let style = LampStyle(rawValue: entry["style"] as? String ?? "") ?? .plain
            let sources = (entry["sources"] as? [Any] ?? []).compactMap {
                ($0 as? String).flatMap(LampSource.init(raw:))
            }
            // A lamp row that named nothing usable still lights the commands: an
            // unreadable `sources` should not leave the row empty.
            self = .lamps(style: style, sources: sources.isEmpty ? [.commands, .battery] : sources)

        case "controls":
            self = .controls(
                labels: ControlLabels(
                    onTop: entry["onTop"] as? String,
                    onTopNote: entry["onTopNote"] as? String,
                    close: entry["close"] as? String,
                    closeNote: entry["closeNote"] as? String
                ))
        case "spacer": self = .spacer

        case "readout":
            self = .readout(
                ReadoutSpec(
                    style: ReadoutStyle(rawValue: entry["style"] as? String ?? "") ?? .lcd,
                    caption: entry["caption"] as? String,
                    trailing: entry["trailing"] as? String,
                    primary: (entry["primary"] as? String).flatMap(ReadoutSource.init(raw:))
                        ?? .uptime,
                    primaryCaption: entry["primaryCaption"] as? String,
                    secondary: (entry["secondary"] as? String).flatMap(ReadoutSource.init(raw:))
                        ?? .mode,
                    secondaryCaption: entry["secondaryCaption"] as? String
                ))

        case "gauge":
            let source = (entry["source"] as? String).flatMap(GaugeSource.init(raw:)) ?? .battery
            self = .gauge(
                GaugeSpec(
                    source: source,
                    width: entry["width"] as? Double,
                    caption: entry["caption"] as? String,
                    trailing: entry["trailing"] as? String
                ))

        case "commands":
            let style = CommandStyle(rawValue: entry["style"] as? String ?? "") ?? .tile
            let columns = entry["columns"] as? Int ?? 0
            self = .commands(style: style, columns: max(0, min(8, columns)))

        case "row":
            let children = (entry["children"] as? [Any] ?? []).compactMap(SkinSlot.init(json:))
            guard !children.isEmpty else { return nil }
            self = .row(children)

        default:
            return nil
        }
    }
}
