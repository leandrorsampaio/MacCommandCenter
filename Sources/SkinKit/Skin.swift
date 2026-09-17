import AppKit
import CoreText
import SwiftUI

// MARK: - Colours

/// Every colour a skin can set. A manifest overrides only the keys it names, so a skin
/// can be three lines long or set all of them.
public struct SkinColors: Sendable, Equatable {

    public var panel: SkinRGBA
    public var panelHighlight: SkinRGBA
    public var panelShadow: SkinRGBA

    public var titlebarTop: SkinRGBA
    public var titlebarBottom: SkinRGBA
    public var titlebarText: SkinRGBA
    public var titlebarButtonFace: SkinRGBA

    public var sectionLabel: SkinRGBA
    public var text: SkinRGBA
    public var textDim: SkinRGBA

    public var buttonFace: SkinRGBA
    public var buttonFacePressed: SkinRGBA
    public var buttonText: SkinRGBA
    public var buttonTextActive: SkinRGBA
    public var buttonSubtext: SkinRGBA
    public var buttonSubtextActive: SkinRGBA

    public var readoutBackground: SkinRGBA
    public var readoutInk: SkinRGBA
    public var readoutInkDim: SkinRGBA
    public var readoutInkIdle: SkinRGBA

    public var ledOn: SkinRGBA
    public var ledOff: SkinRGBA
    public var visualizerOn: SkinRGBA
    public var visualizerOff: SkinRGBA

    public var accent: SkinRGBA

    /// Documented key order, used by the authoring README and the example skin.
    public static let keys = [
        "panel", "panelHighlight", "panelShadow",
        "titlebarTop", "titlebarBottom", "titlebarText", "titlebarButtonFace",
        "sectionLabel", "text", "textDim",
        "buttonFace", "buttonFacePressed", "buttonText", "buttonTextActive",
        "buttonSubtext", "buttonSubtextActive",
        "readoutBackground", "readoutInk", "readoutInkDim", "readoutInkIdle",
        "ledOn", "ledOff", "visualizerOn", "visualizerOff",
        "accent",
    ]

    public subscript(key: String) -> SkinRGBA? {
        get {
            switch key {
            case "panel": return panel
            case "panelHighlight": return panelHighlight
            case "panelShadow": return panelShadow
            case "titlebarTop": return titlebarTop
            case "titlebarBottom": return titlebarBottom
            case "titlebarText": return titlebarText
            case "titlebarButtonFace": return titlebarButtonFace
            case "sectionLabel": return sectionLabel
            case "text": return text
            case "textDim": return textDim
            case "buttonFace": return buttonFace
            case "buttonFacePressed": return buttonFacePressed
            case "buttonText": return buttonText
            case "buttonTextActive": return buttonTextActive
            case "buttonSubtext": return buttonSubtext
            case "buttonSubtextActive": return buttonSubtextActive
            case "readoutBackground": return readoutBackground
            case "readoutInk": return readoutInk
            case "readoutInkDim": return readoutInkDim
            case "readoutInkIdle": return readoutInkIdle
            case "ledOn": return ledOn
            case "ledOff": return ledOff
            case "visualizerOn": return visualizerOn
            case "visualizerOff": return visualizerOff
            case "accent": return accent
            default: return nil
            }
        }
        set {
            guard let newValue else { return }
            switch key {
            case "panel": panel = newValue
            case "panelHighlight": panelHighlight = newValue
            case "panelShadow": panelShadow = newValue
            case "titlebarTop": titlebarTop = newValue
            case "titlebarBottom": titlebarBottom = newValue
            case "titlebarText": titlebarText = newValue
            case "titlebarButtonFace": titlebarButtonFace = newValue
            case "sectionLabel": sectionLabel = newValue
            case "text": text = newValue
            case "textDim": textDim = newValue
            case "buttonFace": buttonFace = newValue
            case "buttonFacePressed": buttonFacePressed = newValue
            case "buttonText": buttonText = newValue
            case "buttonTextActive": buttonTextActive = newValue
            case "buttonSubtext": buttonSubtext = newValue
            case "buttonSubtextActive": buttonSubtextActive = newValue
            case "readoutBackground": readoutBackground = newValue
            case "readoutInk": readoutInk = newValue
            case "readoutInkDim": readoutInkDim = newValue
            case "readoutInkIdle": readoutInkIdle = newValue
            case "ledOn": ledOn = newValue
            case "ledOff": ledOff = newValue
            case "visualizerOn": visualizerOn = newValue
            case "visualizerOff": visualizerOff = newValue
            case "accent": accent = newValue
            default: break
            }
        }
    }

    mutating func apply(_ overrides: [String: String]) {
        for (key, value) in overrides {
            guard let parsed = SkinRGBA(hex: value) else { continue }
            self[key] = parsed
        }
    }
}

// MARK: - Metrics

public struct SkinMetrics: Sendable, Equatable {

    /// Panel width in points. Skins may change the whole panel's proportions.
    public var width: Double
    public var padding: Double
    public var spacing: Double
    /// Thickness of the bevel edges, in points. `0` gives a flat skin.
    public var bevel: Double
    public var cornerRadius: Double
    public var tileHeight: Double
    public var titlebarHeight: Double
    public var readoutPadding: Double
    public var ledSize: Double
    public var glowRadius: Double
    public var tracking: Double

    public static let keys = [
        "width", "padding", "spacing", "bevel", "cornerRadius", "tileHeight",
        "titlebarHeight", "readoutPadding", "ledSize", "glowRadius", "tracking",
    ]

    mutating func apply(_ overrides: [String: Double]) {
        for (key, value) in overrides {
            switch key {
            case "width": width = max(220, min(640, value))
            case "padding": padding = max(0, min(40, value))
            case "spacing": spacing = max(0, min(40, value))
            case "bevel": bevel = max(0, min(8, value))
            case "cornerRadius": cornerRadius = max(0, min(24, value))
            case "tileHeight": tileHeight = max(60, min(280, value))
            case "titlebarHeight": titlebarHeight = max(0, min(48, value))
            case "readoutPadding": readoutPadding = max(0, min(30, value))
            case "ledSize": ledSize = max(0, min(24, value))
            case "glowRadius": glowRadius = max(0, min(30, value))
            case "tracking": tracking = max(-2, min(6, value))
            default: break
            }
        }
    }
}

// MARK: - Fonts

public struct SkinFontSpec: Sendable, Equatable {

    /// A font family installed on the system, or one registered from `file`.
    public var family: String?
    /// A font file inside the skin folder, relative to it. Registered at load time.
    public var file: String?
    public var size: Double
    public var weight: Font.Weight
    public var monospaced: Bool

    public init(
        family: String? = nil, file: String? = nil, size: Double,
        weight: Font.Weight = .regular, monospaced: Bool = false
    ) {
        self.family = family
        self.file = file
        self.size = size
        self.weight = weight
        self.monospaced = monospaced
    }

    /// Falls back to a system font whenever the named family is missing, so a skin that
    /// asks for a font the user does not have still renders.
    public var font: Font {
        if let family, !family.isEmpty, NSFont(name: family, size: size) != nil {
            return .custom(family, fixedSize: size)
        }
        return .system(size: size, weight: weight, design: monospaced ? .monospaced : .default)
    }

    /// True when the skin's requested family is actually available.
    public var isResolved: Bool {
        guard let family, !family.isEmpty else { return false }
        return NSFont(name: family, size: size) != nil
    }
}

public struct SkinFonts: Sendable, Equatable {
    /// Labels, button titles, the titlebar.
    public var display: SkinFontSpec
    /// The LCD readout.
    public var readout: SkinFontSpec
    /// Descriptions and secondary copy.
    public var body: SkinFontSpec

    public static let keys = ["display", "readout", "body"]
}

// MARK: - Effects

public struct SkinEffects: Sendable, Equatable {
    public var glow: Bool
    public var scanlines: Bool
    public var visualizer: Bool
    public var uppercase: Bool

    public static let keys = ["glow", "scanlines", "visualizer", "uppercase"]

    mutating func apply(_ overrides: [String: Bool]) {
        for (key, value) in overrides {
            switch key {
            case "glow": glow = value
            case "scanlines": scanlines = value
            case "visualizer": visualizer = value
            case "uppercase": uppercase = value
            default: break
            }
        }
    }
}

// MARK: - Skin

public struct Skin: Sendable, Equatable, Identifiable {

    public var id: String
    public var name: String
    public var author: String
    public var notes: String
    public var isBuiltIn: Bool
    public var folderURL: URL?

    public var colors: SkinColors
    public var metrics: SkinMetrics
    public var fonts: SkinFonts
    public var effects: SkinEffects

    /// Applies text casing the skin asked for.
    public func label(_ text: String) -> String {
        effects.uppercase ? text.uppercased() : text
    }
}

// MARK: - Manifest decoding

/// The on-disk shape of `skin.json`. Every field is optional: a manifest overrides only
/// what it names and inherits the rest, so skins never break when new tokens are added.
struct SkinManifest: Decodable {

    struct FontEntry: Decodable {
        var family: String?
        var file: String?
        var size: Double?
        var weight: String?
        var monospaced: Bool?
    }

    var format: Int?
    var id: String?
    var name: String?
    var author: String?
    var notes: String?
    var colors: [String: String]?
    var metrics: [String: Double]?
    var effects: [String: Bool]?
    var fonts: [String: FontEntry]?
}

extension Font.Weight {
    static func named(_ value: String?) -> Font.Weight? {
        switch value?.lowercased() {
        case "ultralight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return nil
        }
    }
}

extension Skin {

    /// Builds a skin by layering a manifest over a base (normally the built-in classic).
    init(manifest: SkinManifest, base: Skin, id: String, folderURL: URL?, isBuiltIn: Bool) {
        self = base
        self.id = manifest.id ?? id
        self.name = manifest.name ?? id
        self.author = manifest.author ?? ""
        self.notes = manifest.notes ?? ""
        self.folderURL = folderURL
        self.isBuiltIn = isBuiltIn

        if let overrides = manifest.colors { colors.apply(overrides) }
        if let overrides = manifest.metrics { metrics.apply(overrides) }
        if let overrides = manifest.effects { effects.apply(overrides) }

        if let fontOverrides = manifest.fonts {
            apply(fontOverrides["display"], to: &fonts.display, folderURL: folderURL)
            apply(fontOverrides["readout"], to: &fonts.readout, folderURL: folderURL)
            apply(fontOverrides["body"], to: &fonts.body, folderURL: folderURL)
        }
    }

    private func apply(
        _ entry: SkinManifest.FontEntry?, to spec: inout SkinFontSpec, folderURL: URL?
    ) {
        guard let entry else { return }
        if let size = entry.size { spec.size = max(5, min(48, size)) }
        if let weight = Font.Weight.named(entry.weight) { spec.weight = weight }
        if let monospaced = entry.monospaced { spec.monospaced = monospaced }

        // A bundled font file wins: register it and use the family name it declares.
        if let file = entry.file, let folderURL {
            spec.file = file
            if let registered = FontRegistrar.register(fileNamed: file, in: folderURL) {
                spec.family = registered
                return
            }
        }
        if let family = entry.family { spec.family = family }
    }
}

// MARK: - Font registration

/// Registers font files that ship inside a skin folder, so a skin can bring its own
/// pixel typeface without the user installing anything.
enum FontRegistrar {

    private static var registered: [URL: String] = [:]

    static func register(fileNamed file: String, in folder: URL) -> String? {
        // Keep skins from reaching outside their own folder.
        guard !file.contains(".."), !file.hasPrefix("/") else { return nil }
        let url = folder.appendingPathComponent(file)
        guard url.path.hasPrefix(folder.path) else { return nil }
        return register(url)
    }

    static func register(_ url: URL) -> String? {
        if let cached = registered[url] { return cached }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        guard
            let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL)
                as? [CTFontDescriptor],
            let first = descriptors.first,
            let family = CTFontDescriptorCopyAttribute(first, kCTFontFamilyNameAttribute) as? String
        else { return nil }

        // Already installed system-wide, or registered by an earlier load.
        if NSFont(name: family, size: 12) == nil {
            var error: Unmanaged<CFError>?
            guard CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) else {
                return nil
            }
        }

        registered[url] = family
        return family
    }
}
