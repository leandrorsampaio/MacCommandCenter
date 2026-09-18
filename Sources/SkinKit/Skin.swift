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

    /// Engraved plates: the nameplate and the caption strips on modules.
    public var plate: SkinRGBA
    public var plateText: SkinRGBA
    /// The side wall a relief key stands on.
    public var keyWall: SkinRGBA
    /// Cap colours for the two non-neutral roles a config can give a button.
    public var keyCaution: SkinRGBA
    public var keyDanger: SkinRGBA
    /// The face, printing and needle of an analogue gauge.
    public var gaugeFace: SkinRGBA
    public var gaugeInk: SkinRGBA
    public var needle: SkinRGBA

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
        "plate", "plateText", "keyWall", "keyCaution", "keyDanger",
        "gaugeFace", "gaugeInk", "needle",
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
            case "plate": return plate
            case "plateText": return plateText
            case "keyWall": return keyWall
            case "keyCaution": return keyCaution
            case "keyDanger": return keyDanger
            case "gaugeFace": return gaugeFace
            case "gaugeInk": return gaugeInk
            case "needle": return needle
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
            case "plate": plate = newValue
            case "plateText": plateText = newValue
            case "keyWall": keyWall = newValue
            case "keyCaution": keyCaution = newValue
            case "keyDanger": keyDanger = newValue
            case "gaugeFace": gaugeFace = newValue
            case "gaugeInk": gaugeInk = newValue
            case "needle": needle = newValue
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
    /// How far a relief key stands proud, and how far it sinks when pressed.
    public var keyRelief: Double
    /// Minimum height of a relief key. A key is a block, not a list row.
    public var keyHeight: Double
    /// Multiplier on legend type — key faces, lamp captions and annunciator cells — so
    /// the things you read at a glance can be larger than the panel's fine print.
    public var legendScale: Double
    /// Delay between a key latching and the lamps reporting it, in seconds. A console
    /// with `0` responds instantly; a slower one feels like a relay closing elsewhere.
    public var indicatorDelay: Double

    public static let keys = [
        "width", "padding", "spacing", "bevel", "cornerRadius", "tileHeight",
        "titlebarHeight", "readoutPadding", "ledSize", "glowRadius", "tracking",
        "keyRelief", "keyHeight", "legendScale", "indicatorDelay",
    ]

    public subscript(key: String) -> Double? {
        switch key {
        case "width": return width
        case "padding": return padding
        case "spacing": return spacing
        case "bevel": return bevel
        case "cornerRadius": return cornerRadius
        case "tileHeight": return tileHeight
        case "titlebarHeight": return titlebarHeight
        case "readoutPadding": return readoutPadding
        case "ledSize": return ledSize
        case "glowRadius": return glowRadius
        case "tracking": return tracking
        case "keyRelief": return keyRelief
        case "keyHeight": return keyHeight
        case "legendScale": return legendScale
        case "indicatorDelay": return indicatorDelay
        default: return nil
        }
    }

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
            case "keyRelief": keyRelief = max(0, min(14, value))
            case "keyHeight": keyHeight = max(28, min(200, value))
            case "legendScale": legendScale = max(0.5, min(3, value))
            case "indicatorDelay": indicatorDelay = max(0, min(2, value))
            default: break
            }
        }
    }
}

// MARK: - Fonts

public struct SkinFontSpec: Sendable, Equatable {

    /// Families in preference order, the way a CSS font stack works. The first one
    /// actually installed wins, so a skin can ask for a font not everyone has and name a
    /// fallback that everyone does.
    public var families: [String]

    /// The first family that resolves on this machine.
    public var family: String? {
        families.first { FontAvailability.hasFamily($0) } ?? families.first
    }
    /// A font file inside the skin folder, relative to it. Registered at load time.
    public var file: String?
    public var size: Double
    public var weight: Font.Weight
    public var monospaced: Bool

    public init(
        family: String? = nil, file: String? = nil, size: Double,
        weight: Font.Weight = .regular, monospaced: Bool = false
    ) {
        self.families = family.map { [$0] } ?? []
        self.file = file
        self.size = size
        self.weight = weight
        self.monospaced = monospaced
    }

    /// Falls back to a system font whenever the named family is missing, so a skin that
    /// asks for a font the user does not have still renders.
    public var font: Font {
        if let family, !family.isEmpty, FontAvailability.hasFamily(family) {
            // `.weight` still applies to a custom family; dropping it silently ignored
            // every skin's weight, the built-in one included.
            return .custom(family, fixedSize: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: monospaced ? .monospaced : .default)
    }

    /// A copy at a different size, used where one role needs more presence than the
    /// rest of the panel.
    public func scaled(by factor: Double) -> SkinFontSpec {
        var copy = self
        copy.size = max(5, min(72, size * factor))
        return copy
    }

    /// True when the skin's requested family is actually available.
    public var isResolved: Bool {
        guard let family, !family.isEmpty else { return false }
        return FontAvailability.hasFamily(family)
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

/// Panel furniture that is not a colour or a size.
public struct SkinChrome: Sendable, Equatable {
    /// Screws in the four corners.
    public var screws: Bool
    /// A click when a key is pressed.
    public var keyClick: Bool
    /// Fine vertical grain over the chassis, the way painted metal catches light.
    public var texture: Bool

    public static let keys = ["screws", "keyClick", "texture"]

    mutating func apply(_ entry: SkinManifest.ChromeEntry) {
        if let value = entry.screws { screws = value }
        if let value = entry.keyClick { keyClick = value }
        if let value = entry.texture { texture = value }
    }
}

public struct SkinEffects: Sendable, Equatable {
    public var glow: Bool
    public var scanlines: Bool
    public var visualizer: Bool
    public var uppercase: Bool
    /// Analogue jitter on gauge needles. A real moving coil never sits perfectly still.
    public var flicker: Bool

    public static let keys = ["glow", "scanlines", "visualizer", "uppercase", "flicker"]

    mutating func apply(_ overrides: [String: Bool]) {
        for (key, value) in overrides {
            switch key {
            case "glow": glow = value
            case "scanlines": scanlines = value
            case "visualizer": visualizer = value
            case "uppercase": uppercase = value
            case "flicker": flicker = value
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
    /// Where this skin was read from: the package folder, or a bare `.json` file.
    public var sourceURL: URL?

    public var colors: SkinColors
    public var metrics: SkinMetrics
    public var fonts: SkinFonts
    public var effects: SkinEffects
    public var chrome: SkinChrome
    /// A click sound shipped inside the skin folder, if it named one.
    public var keySoundURL: URL?
    /// How the panel is composed. Defaults to the original stack, so a skin written
    /// before layouts existed renders exactly as it always did.
    public var layout: SkinLayout

    /// Applies text casing the skin asked for.
    public func label(_ text: String) -> String {
        effects.uppercase ? text.uppercased() : text
    }
}

// MARK: - Manifest decoding

/// The on-disk shape of `skin.json`. Every field is optional: a manifest overrides only
/// what it names and inherits the rest, so skins never break when new tokens are added.
struct SkinManifest: Decodable {

    /// One name or several, so a manifest can write either.
    struct FontFamilies: Decodable {
        let names: [String]

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let single = try? container.decode(String.self) {
                names = [single]
            } else {
                names = (try? container.decode([String].self)) ?? []
            }
        }
    }

    struct ChromeEntry: Decodable {
        var screws: Bool?
        var keyClick: Bool?
        var texture: Bool?
        /// A sound file inside the skin folder. Resolved by the catalog, not here.
        var keySound: String?
    }

    struct FontEntry: Decodable {
        /// Accepts a single name or a stack: "PT Sans" or ["Bahnschrift", "DIN Condensed"].
        var family: FontFamilies?
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
    var chrome: ChromeEntry?
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
        if let overrides = manifest.chrome { chrome.apply(overrides) }

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
                spec.families = [registered]
                return
            }
        }
        if let family = entry.family, !family.names.isEmpty { spec.families = family.names }
    }
}

/// Caches whether a font family exists.
///
/// `NSFont(name:size:)` was being called several times per tile on every render purely to
/// answer a question whose answer cannot change: either the family is installed or it is
/// not. A family registered from a skin only ever becomes available, so a positive answer
/// is permanent and a negative one is re-checked after a registration.
enum FontAvailability {

    private static let lock = NSLock()
    private static var known: [String: Bool] = [:]

    static func hasFamily(_ family: String) -> Bool {
        lock.lock()
        if let cached = known[family] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let exists = NSFont(name: family, size: 12) != nil
        lock.lock()
        known[family] = exists
        lock.unlock()
        return exists
    }

    /// Called after a skin registers a font file, so a previous "missing" is forgotten.
    static func invalidate() {
        lock.lock()
        known.removeAll()
        lock.unlock()
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
        FontAvailability.invalidate()
        return family
    }
}
