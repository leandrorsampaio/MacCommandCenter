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
        .readout(style: .lcd),
        .commands(style: .tile, columns: 0),
    ])
}

public indirect enum SkinSlot: Sendable, Equatable {
    /// The engraved header plate. Falls back to the config's name when no text is given.
    case nameplate(title: String?, subtitle: String?)
    /// One backlit legend cell per command, lit when that command is engaged.
    case annunciator
    case readout(style: ReadoutStyle)
    case gauge(source: GaugeSource, width: Double?)
    /// The command buttons. `columns` of 0 means "one row, share the width".
    case commands(style: CommandStyle, columns: Int)
    /// A row of indicator lamps mirroring command state.
    case lamps
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

public enum ReadoutStyle: String, Sendable, Codable {
    /// The original single strip.
    case lcd
    /// A large glowing counter plus a mode line.
    case nixie
}

public enum GaugeSource: String, Sendable, Codable {
    case battery
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
        case "lamps": self = .lamps
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
            self = .readout(style: ReadoutStyle(rawValue: entry["style"] as? String ?? "") ?? .lcd)

        case "gauge":
            let source = GaugeSource(rawValue: entry["source"] as? String ?? "") ?? .battery
            self = .gauge(source: source, width: entry["width"] as? Double)

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
