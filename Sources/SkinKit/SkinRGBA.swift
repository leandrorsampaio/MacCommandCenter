import SwiftUI

/// A colour parsed from a skin manifest.
///
/// Stored as components rather than a `Color` so a `Skin` stays `Equatable` and
/// `Sendable`, and so skins can be diffed and round-tripped.
public struct SkinRGBA: Sendable, Equatable, Codable {

    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Accepts `#RGB`, `#RGBA`, `#RRGGBB` and `#RRGGBBAA`, with or without the `#`.
    public init?(hex input: String) {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.allSatisfy({ $0.isHexDigit }) else { return nil }

        func component(_ slice: Substring) -> Double {
            Double(UInt8(slice, radix: 16) ?? 0) / 255
        }

        switch text.count {
        case 3, 4:
            let expanded = text.map { String(repeating: String($0), count: 2) }.joined()
            self.init(hex: expanded)
        case 6:
            let chars = Array(text)
            self.init(
                red: component(text.prefix(2)),
                green: component(Substring(String(chars[2...3]))),
                blue: component(Substring(String(chars[4...5]))),
                alpha: 1
            )
        case 8:
            let chars = Array(text)
            self.init(
                red: component(text.prefix(2)),
                green: component(Substring(String(chars[2...3]))),
                blue: component(Substring(String(chars[4...5]))),
                alpha: component(Substring(String(chars[6...7])))
            )
        default:
            return nil
        }
    }

    public var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    public var hex: String {
        let channels = [red, green, blue].map { Int(($0 * 255).rounded()) }
        return "#" + channels.map { String(format: "%02X", $0) }.joined()
    }

    /// Used for glow layers, where a skin gives one colour and the view needs it faded.
    public func opacity(_ value: Double) -> Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha * value)
    }

    public static let clear = SkinRGBA(red: 0, green: 0, blue: 0, alpha: 0)
}
