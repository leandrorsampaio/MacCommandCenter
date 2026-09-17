# Writing a skin

A skin decides how the panel looks. It is a folder ending in `.mccskin` holding a
`skin.json`, in:

```
~/Library/Application Support/MacCommandCenter/Skins/
  MySkin.mccskin/
    skin.json
    fonts/MyPixelFont.ttf      (optional)
```

A bare `MySkin.json` works too, for a colours-only skin. Under the App Store build the app
is sandboxed, so that folder lives inside the app's container — use **Settings › Skins ›
Import…** instead of hunting for it.

**Saving a file re-skins the open window.** The folder is watched, so you can keep the
panel open beside your editor.

## Everything is optional

A manifest overrides only the keys it names and inherits the rest from the built-in
Classic '97. A three-line skin is valid:

```json
{ "name": "Red Alert", "colors": { "readoutInk": "#FF3B30", "ledOn": "#FF3B30" } }
```

Unknown keys are ignored, so a skin written today keeps working when tokens are added
later. A manifest that fails to parse is reported in Settings rather than silently
ignored. Reusing a built-in skin's `id` replaces it — that is how you ship a modified
Classic '97.

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
| `sectionLabel` | Section headings |
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

Points. Each is clamped, so a bad number cannot make the panel unusable.

| Token | Default | Notes |
|---|---|---|
| `width` | 340 | Whole panel width (220–640) |
| `padding` | 11 | Inset from the chassis edge |
| `spacing` | 11 | Gap between sections |
| `bevel` | 2 | Bevel thickness. `0` gives a flat, modern skin |
| `cornerRadius` | 0 | `0` is the 1997 look |
| `tileHeight` | 142 | Height of a command button |
| `titlebarHeight` | 20 | `0` removes the titlebar; close and settings move to a small row at the foot of the panel |
| `readoutPadding` | 9 | Inset inside the LCD |
| `ledSize` | 8 | Lamp diameter |
| `glowRadius` | 7 | Bloom on lit elements |
| `tracking` | 0.6 | Letter spacing on display type |

## Fonts

Three roles: `display` (labels and button titles), `readout` (the LCD) and `body`
(descriptions). Each takes `family`, `size`, `weight` and `monospaced`.

The defaults are **Geneva** and **Monaco** because both ship with macOS, so the app never
depends on a download. To use a font the user does not have, ship it with the skin:

```json
"fonts": {
  "display": { "file": "fonts/Silkscreen.ttf", "size": 8 },
  "readout": { "file": "fonts/VT323.ttf", "size": 15 }
}
```

The file is registered for this app only — nothing is installed on the system, and a path
cannot escape the skin folder. A missing font falls back to the system font at the same
size rather than failing.

Other period-correct faces already on every Mac: `Courier New`, `Andale Mono`, `PT Mono`.

## Effects

| Token | Default | Effect |
|---|---|---|
| `glow` | true | Bloom on the LCD and lit lamps |
| `scanlines` | true | CRT lines over the LCD |
| `visualizer` | true | The spectrum bars in the readout |
| `uppercase` | true | Force labels to caps |

## Sharing

Zip the `.mccskin` folder. The recipient drops it in the Skins folder, or uses
**Settings › Skins › Import…**

The app writes a complete, commented example into your Skins folder on first run, and it
is generated from the live token list — so it can never drift from what the app reads.
