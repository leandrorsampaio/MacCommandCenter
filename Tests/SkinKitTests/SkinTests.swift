import Foundation
import Testing

@testable import SkinKit

struct SkinRGBATests {

    @Test(arguments: [
        ("#FF0000", 1.0, 0.0, 0.0, 1.0),
        ("00FF00", 0.0, 1.0, 0.0, 1.0),
        ("#F00", 1.0, 0.0, 0.0, 1.0),
        ("#FF000080", 1.0, 0.0, 0.0, 128.0 / 255.0),
    ])
    func parsesEveryHexLength(
        hex: String, red: Double, green: Double, blue: Double, alpha: Double
    ) throws {
        let colour = try #require(SkinRGBA(hex: hex))
        #expect(abs(colour.red - red) < 0.001)
        #expect(abs(colour.green - green) < 0.001)
        #expect(abs(colour.blue - blue) < 0.001)
        #expect(abs(colour.alpha - alpha) < 0.001)
    }

    @Test(arguments: ["", "#12345", "nonsense", "#GGGGGG", "#1234567"])
    func rejectsMalformedHex(hex: String) {
        #expect(SkinRGBA(hex: hex) == nil)
    }

    @Test func roundTripsThroughHex() throws {
        let colour = try #require(SkinRGBA(hex: "#3B3B42"))
        #expect(colour.hex == "#3B3B42")
    }
}

struct SkinManifestTests {

    private func skin(_ json: String) throws -> Skin {
        let manifest = try JSONDecoder().decode(SkinManifest.self, from: Data(json.utf8))
        return Skin(
            manifest: manifest, base: .classic, id: "test", folderURL: nil, isBuiltIn: false)
    }

    /// The core promise of the format: name three keys, inherit everything else.
    @Test func partialManifestInheritsTheRest() throws {
        let result = try skin(##"{ "name": "Red", "colors": { "ledOn": "#FF0000" } }"##)

        #expect(result.name == "Red")
        #expect(result.colors.ledOn.hex == "#FF0000")
        #expect(result.colors.panel == Skin.classic.colors.panel)
        #expect(result.metrics.width == Skin.classic.metrics.width)
        #expect(result.effects.uppercase == Skin.classic.effects.uppercase)
    }

    /// A skin written for a future version must still load today.
    @Test func unknownKeysAreIgnored() throws {
        let result = try skin(##"{ "name": "Future", "colors": { "somethingNew": "#FFFFFF" } }"##)
        #expect(result.name == "Future")
        #expect(result.colors.panel == Skin.classic.colors.panel)
    }

    @Test func malformedColourValuesAreSkippedNotFatal() throws {
        let result = try skin(##"{ "colors": { "ledOn": "not-a-colour", "ledOff": "#123456" } }"##)

        #expect(result.colors.ledOn == Skin.classic.colors.ledOn)
        #expect(result.colors.ledOff.hex == "#123456")
    }

    /// A bad number must not be able to make the panel unusable.
    @Test func metricsAreClamped() throws {
        let result = try skin(#"{ "metrics": { "width": 99999, "bevel": -40, "tileHeight": 1 } }"#)

        #expect(result.metrics.width == 640)
        #expect(result.metrics.bevel == 0)
        #expect(result.metrics.tileHeight == 60)
    }

    @Test func fontSizesAreClampedAndWeightsParsed() throws {
        let result = try skin(#"{ "fonts": { "display": { "size": 900, "weight": "bold" } } }"#)

        #expect(result.fonts.display.size == 48)
        #expect(result.fonts.display.weight == .bold)
    }

    @Test func effectsToggleIndependently() throws {
        let result = try skin(#"{ "effects": { "scanlines": false } }"#)

        #expect(result.effects.scanlines == false)
        #expect(result.effects.glow == Skin.classic.effects.glow)
    }

    @Test func labelHonoursUppercaseEffect() throws {
        let shouting = try skin(#"{ "effects": { "uppercase": true } }"#)
        let quiet = try skin(#"{ "effects": { "uppercase": false } }"#)

        #expect(shouting.label("Keep Awake") == "KEEP AWAKE")
        #expect(quiet.label("Keep Awake") == "Keep Awake")
    }
}

struct SkinAuthoringTests {

    /// The generated example is what every skin author starts from, so it has to be a
    /// valid, complete manifest — and it is generated from the live token lists.
    @Test func generatedExampleIsValidAndComplete() throws {
        let data = Data(SkinAuthoring.exampleManifest.utf8)
        let manifest = try JSONDecoder().decode(SkinManifest.self, from: data)

        let colours = try #require(manifest.colors)
        for key in SkinColors.keys {
            #expect(colours[key] != nil, "example is missing colour '\(key)'")
        }

        let metrics = try #require(manifest.metrics)
        for key in SkinMetrics.keys {
            #expect(metrics[key] != nil, "example is missing metric '\(key)'")
        }
    }

    @Test func generatedExampleRoundTripsToTheClassicLook() throws {
        let manifest = try JSONDecoder().decode(
            SkinManifest.self,
            from: Data(SkinAuthoring.exampleManifest.utf8)
        )
        let rebuilt = Skin(
            manifest: manifest, base: .classic, id: "x", folderURL: nil, isBuiltIn: false)

        #expect(rebuilt.colors == Skin.classic.colors)
        #expect(rebuilt.metrics == Skin.classic.metrics)
    }

    /// Every token an author can write must appear in the README they are handed. This
    /// used to check colours alone, and a metric and a chrome flag duly went undocumented.
    @Test func readmeDocumentsEveryToken() throws {
        let readme = SkinAuthoring.readme

        for key in SkinColors.keys {
            #expect(readme.contains(key), "README never mentions colour '\(key)'")
        }
        for key in SkinMetrics.keys {
            #expect(readme.contains(key), "README never mentions metric '\(key)'")
        }
        for key in SkinEffects.keys {
            #expect(readme.contains(key), "README never mentions effect '\(key)'")
        }
        for key in SkinChrome.keys {
            #expect(readme.contains(key), "README never mentions chrome token '\(key)'")
        }
    }
}

struct SkinLayoutTests {

    private func layout(_ json: String) -> SkinLayout? {
        let object = try? JSONSerialization.jsonObject(with: Data(json.utf8))
        return SkinLayout(json: (object as? [String: Any])?["layout"])
    }

    @Test func decodesASlotTree() throws {
        let parsed = try #require(
            layout(
                """
                { "layout": [
                    { "slot": "nameplate", "text": "Console" },
                    { "slot": "row", "children": [
                        { "slot": "gauge", "source": "battery", "width": 168 },
                        { "slot": "readout", "style": "nixie" }
                    ]},
                    { "slot": "commands", "style": "key", "columns": 2 },
                    { "slot": "spacer" },
                    { "slot": "controls" }
                ]}
                """))

        #expect(parsed.rows.count == 5)
        #expect(parsed.rows[0] == .nameplate(title: "Console", subtitle: nil))
        #expect(parsed.rows[2] == .commands(style: .key, columns: 2))
        #expect(parsed.rows[4] == .controls(labels: ControlLabels()))

        guard case .row(let children) = parsed.rows[1] else {
            Issue.record("expected a row")
            return
        }
        #expect(children == [.gauge(source: .battery, width: 168), .readout(style: .nixie)])
    }

    /// A layout written for a later version must still render what this build knows.
    @Test func unknownSlotsAreSkippedRatherThanFailing() throws {
        let parsed = try #require(
            layout(
                """
                { "layout": [
                    { "slot": "oscilloscope" },
                    { "slot": "lamps" }
                ]}
                """))

        #expect(parsed.rows == [.lamps])
    }

    @Test func unknownStylesFallBackRatherThanFailing() throws {
        let parsed = try #require(
            layout(##"{ "layout": [ { "slot": "commands", "style": "hologram" } ] }"##))

        #expect(parsed.rows == [.commands(style: .tile, columns: 0)])
    }

    @Test func columnCountsAreClamped() throws {
        let parsed = try #require(
            layout(##"{ "layout": [ { "slot": "commands", "style": "key", "columns": 99 } ] }"##))

        #expect(parsed.rows == [.commands(style: .key, columns: 8)])
    }

    /// A skin with no layout, or an empty one, keeps the original stack.
    @Test func missingOrEmptyLayoutsFallBackToTheStack() {
        #expect(layout(##"{ "name": "Plain" }"##) == nil)
        #expect(layout(##"{ "layout": [] }"##) == nil)
        #expect(Skin.classic.layout == SkinLayout.stack)
    }

    @Test func aRowNeedsChildrenToCount() {
        #expect(layout(##"{ "layout": [ { "slot": "row", "children": [] } ] }"##) == nil)
    }
}
