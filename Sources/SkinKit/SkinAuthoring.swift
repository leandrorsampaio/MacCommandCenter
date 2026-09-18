import Foundation

/// The starter files written into the user's Skins folder on first run.
///
/// Both are generated from the live token lists and the built-in classic skin, so the
/// documentation can never drift from what the app actually reads.
enum SkinAuthoring {

    static var exampleManifest: String {
        let classic = Skin.classic

        // Both lists are generated from the live key arrays, so a token added to the
        // format cannot quietly go missing from the example every author starts with.
        let colors = SkinColors.keys.compactMap { key -> String? in
            guard let value = classic.colors[key] else { return nil }
            return "    \"\(key)\": \"\(value.hex)\""
        }.joined(separator: ",\n")

        let metrics = SkinMetrics.keys.compactMap { key -> String? in
            guard let value = classic.metrics[key] else { return nil }
            return "    \"\(key)\": \(format(value))"
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
            \(metrics)
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
              },

              "chrome": {
                "screws": false,
                "keyClick": false
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
        | `plate` | Engraved plates: the nameplate and module captions |
        | `plateText` | Printing on those plates |
        | `keyWall` | The side wall a relief key stands on |
        | `keyCaution` | Cap of a key the config marked `caution` |
        | `keyDanger` | Cap of a key the config marked `danger` |
        | `gaugeFace` | The dial face of a gauge |
        | `gaugeInk` | Its ticks and printing |
        | `needle` | Its needle |

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
        | `keyRelief` | 5 | How far a relief key stands proud, and sinks when pressed |
        | `keyHeight` | 62 | Minimum height of a relief key. A key is a block, not a row |
        | `legendScale` | 1 | Multiplier on legend type: key faces, lamps, annunciator |
        | `indicatorDelay` | 0 | Seconds between a key latching and the lamps reporting it |

        `indicatorDelay` is worth a word. At `0` the panel responds instantly. Give it
        `0.2` and the key still falls the moment you press it — that part is mechanical —
        but the lamps and the readout follow a fifth of a second later, the way they would
        if a relay somewhere else had to close first.

        ## Fonts

        Three roles: `display` (labels and button titles), `readout` (the LCD) and `body`
        (descriptions). Each takes `family`, `size`, `weight` and `monospaced`.

        `family` takes one name or a stack, and the first one installed wins:

            "display": { "family": ["Bahnschrift", "DIN Condensed", "PT Sans Narrow"] }

        Useful because a font you have is not a font everyone has — Bahnschrift ships with
        Microsoft Office, not with macOS, so a skin that wants it should name what to use
        instead. To guarantee a face, ship the file (see below).

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
        | `flicker` | false | Analogue jitter on gauge needles |

        ## Chrome

        | Token | Default | Effect |
        |---|---|---|
        | `screws` | false | Screws in the four corners |
        | `keyClick` | false | A click when a key is pressed |
        | `texture` | false | Fine vertical grain over the chassis |

        `keyClick` can also name a sound file inside the skin folder:

            "chrome": { "keyClick": true, "keySound": "sounds/click.wav" }

        Any format AVAudioPlayer reads works. The path cannot escape the skin folder, and a
        missing file falls back to the synthesised click. Keep it under about 150ms or it
        lags behind the press.

        ## Layout

        Without a `layout`, a skin gets the original stack: a readout, then the command
        tiles. With one, it composes the panel itself from a fixed vocabulary of slots.

            "layout": [
              { "slot": "nameplate", "text": "Control panel", "subtitle": "Unit 1" },
              { "slot": "annunciator" },
              { "slot": "row", "children": [
                { "slot": "gauge", "source": "battery", "width": 168 },
                { "slot": "readout", "style": "nixie" }
              ]},
              { "slot": "commands", "style": "key", "columns": 2 },
              { "slot": "lamps" },
              { "slot": "spacer" },
              { "slot": "controls" }
            ]

        | Slot | What it draws |
        |---|---|
        | `nameplate` | An engraved header plate. Defaults to the config's name |
        | `annunciator` | A backlit legend cell per command, plus mains and on-top |
        | `readout` | `style`: `lcd` (the original strip) or `nixie` (a large counter) |
        | `gauge` | `source`: `battery`. Optional `width` |
        | `commands` | The buttons. `style`: `tile` or `key`. `columns`: 0 means one row |
        | `lamps` | An indicator lamp per command, plus battery |
        | `controls` | Float-on-top and close, as panel keys. Takes `onTop`, `onTopNote`, `close`, `closeNote`; English by default |
        | `spacer` | Pushes everything after it to the bottom |
        | `row` | Lays its `children` out side by side |

        `key` is a latching pushbutton: it stays down until pressed again, and its cap
        never changes colour, because a physical key is the colour it is. State shows on
        the lamps and the annunciator.

        A slot this version does not recognise is skipped rather than failing the skin, so
        a layout written for a later release still renders what it can.

        ## Sharing a skin

        Zip the `.mccskin` folder. Anyone drops it in this folder and it appears in the
        Settings section of the panel.

        """
    }
}
