import Foundation

/// The starter files written into the user's Skins folder on first run.
///
/// Both are generated from the live token lists and the built-in classic skin, so the
/// documentation can never drift from what the app actually reads.
enum SkinAuthoring {

    static var exampleManifest: String {
        let classic = Skin.classic

        let colors = SkinColors.keys.compactMap { key -> String? in
            guard let value = classic.colors[key] else { return nil }
            return "    \"\(key)\": \"\(value.hex)\""
        }.joined(separator: ",\n")

        return """
            {
              "format": 1,
              "id": "example",
              "name": "Example",
              "author": "You",
              "notes": "Copy this folder, rename it, change the colours.",

              "colors": {
            \(colors)
              },

              "metrics": {
                "width": \(format(classic.metrics.width)),
                "padding": \(format(classic.metrics.padding)),
                "spacing": \(format(classic.metrics.spacing)),
                "bevel": \(format(classic.metrics.bevel)),
                "cornerRadius": \(format(classic.metrics.cornerRadius)),
                "tileHeight": \(format(classic.metrics.tileHeight)),
                "titlebarHeight": \(format(classic.metrics.titlebarHeight)),
                "readoutPadding": \(format(classic.metrics.readoutPadding)),
                "ledSize": \(format(classic.metrics.ledSize)),
                "glowRadius": \(format(classic.metrics.glowRadius)),
                "tracking": \(format(classic.metrics.tracking))
              },

              "fonts": {
                "display": { "family": "Geneva", "size": 10, "weight": "semibold" },
                "readout": { "family": "Monaco", "size": 11, "monospaced": true },
                "body":    { "family": "Geneva", "size": 9.5 }
              },

              "effects": {
                "glow": true,
                "scanlines": true,
                "visualizer": true,
                "uppercase": true
              }
            }

            """
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    static var readme: String {
        """
        # Writing a skin for Mac Command Center

        A skin is a folder ending in `.mccskin` containing a `skin.json`:

            ~/Library/Application Support/MacCommandCenter/Skins/
              Example.mccskin/
                skin.json
                fonts/MyPixelFont.ttf      (optional)

        A bare `MySkin.json` in this folder works too, for a colours-only skin.

        **Saving a file here re-skins the open panel immediately.** The folder is watched,
        so you can keep the panel open next to your editor and iterate.

        ## Everything is optional

        A manifest overrides only the keys it names and inherits the rest from the
        built-in Classic '97. A three-line skin is valid:

            { "name": "Red Alert", "colors": { "readoutInk": "#FF3B30", "ledOn": "#FF3B30" } }

        Unknown keys are ignored, so a skin written today keeps working when new tokens
        are added later. If a manifest fails to parse, the panel says so in Settings
        instead of silently falling back.

        Give each skin a unique `id`. Reusing a built-in skin's `id` replaces it — which
        is how you ship a modified Classic '97.

        ## Colours

        Hex, with or without `#`. `#RGB`, `#RGBA`, `#RRGGBB` and `#RRGGBBAA` all work.

        | Token | Paints |
        |---|---|
        | `panel` | The chassis behind everything |
        | `panelHighlight` | Top and left bevel edge (the lit side) |
        | `panelShadow` | Bottom and right bevel edge |
        | `titlebarTop`, `titlebarBottom` | The titlebar gradient |
        | `titlebarText` | Titlebar caption |
        | `titlebarButtonFace` | The little titlebar boxes |
        | `sectionLabel` | Section headings, e.g. "POWER / KEEP AWAKE" |
        | `text`, `textDim` | Body copy and secondary copy |
        | `buttonFace`, `buttonFacePressed` | Command buttons, out and in |
        | `buttonText`, `buttonTextActive` | Button titles, idle and engaged |
        | `buttonSubtext`, `buttonSubtextActive` | The small line under a button title |
        | `readoutBackground` | The LCD glass |
        | `readoutInk` | Main LCD line while something is running |
        | `readoutInkDim` | Second LCD line |
        | `readoutInkIdle` | LCD when nothing is engaged |
        | `ledOn`, `ledOff` | Indicator lamps |
        | `visualizerOn`, `visualizerOff` | The spectrum bars |
        | `accent` | Focus rings and the menu bar icon tint |

        ## Metrics

        Points. Each is clamped to a sane range, so a bad number cannot make the panel
        unusable.

        | Token | Default | Notes |
        |---|---|---|
        | `width` | 340 | Whole panel width (220–640) |
        | `padding` | 11 | Inset from the chassis edge |
        | `spacing` | 11 | Gap between sections |
        | `bevel` | 2 | Bevel thickness. `0` gives a flat, modern skin |
        | `cornerRadius` | 0 | `0` is the 1997 look |
        | `tileHeight` | 142 | Height of a command button |
        | `titlebarHeight` | 20 | `0` removes the titlebar |
        | `readoutPadding` | 9 | Inset inside the LCD |
        | `ledSize` | 8 | Lamp diameter |
        | `glowRadius` | 7 | Bloom on lit elements |
        | `tracking` | 0.6 | Letter spacing on display type |

        ## Fonts

        Three roles: `display` (labels and button titles), `readout` (the LCD) and `body`
        (descriptions). Each takes `family`, `size`, `weight` and `monospaced`.

        The defaults are Geneva and Monaco because both ship with macOS, so the app never
        depends on a download. To use a font the user does not have, **ship it with the
        skin**:

            "fonts": {
              "display": { "file": "fonts/Silkscreen.ttf", "size": 8 },
              "readout": { "file": "fonts/VT323.ttf", "size": 15 }
            }

        The file is registered for this app only — nothing is installed on the system. A
        path must stay inside the skin folder. If a font is missing or fails to load, that
        role falls back to the system font at the same size rather than failing.

        Good period-correct choices already on every Mac: `Geneva`, `Monaco`,
        `Courier New`, `Andale Mono`, `PT Mono`.

        ## Effects

        | Token | Default | Effect |
        |---|---|---|
        | `glow` | true | Bloom on the LCD and lit lamps |
        | `scanlines` | true | CRT lines over the LCD |
        | `visualizer` | true | The spectrum bars in the readout |
        | `uppercase` | true | Force labels to caps |

        ## Sharing a skin

        Zip the `.mccskin` folder. Anyone drops it in this folder and it appears in the
        Settings section of the panel.

        """
    }
}
