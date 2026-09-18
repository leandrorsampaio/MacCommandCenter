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
| `plate` | Engraved plates: the nameplate and module captions |
| `plateText` | Printing on those plates |
| `keyWall` | The side wall a relief key stands on |
| `keyCaution` | Cap of a key the config marked `caution` |
| `keyDanger` | Cap of a key the config marked `danger` |
| `gaugeFace` | The dial face of a gauge |
| `gaugeInk` | Its ticks and printing |
| `needle` | Its needle |
| `tape` | A strip of tape, for a lamp row labelled by hand |
| `tapeInk` | The marker on it |

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
| `keyRelief` | 5 | How far a relief key stands proud, and sinks when pressed |
| `keyHeight` | 62 | Minimum height of a relief key. A key is a block, not a row |
| `legendScale` | 1 | Multiplier on legend type: key faces, lamps, annunciator |
| `indicatorDelay` | 0 | Seconds between a key latching and the lamps reporting it |

`indicatorDelay` is the interesting one. At `0` the panel responds instantly. Give it
`0.2` and the key still falls the moment you press it — that part is mechanical — but the
lamps and the readout follow a fifth of a second behind, the way they would if a relay
somewhere else in the building had to close first.

## Fonts

Four roles: `display` (labels and button titles), `readout` (the LCD), `body`
(descriptions) and `hand` (anything written rather than printed — a taped-on lamp label).
Each takes `family`, `size`, `weight` and `monospaced`.

`family` takes one name or a stack, and the first one installed wins:

    "display": { "family": ["Bahnschrift", "DIN Condensed", "PT Sans Narrow"] }

Useful because a font you have is not a font everyone has — Bahnschrift ships with
Microsoft Office, not with macOS, so a skin that wants it should name what to use
instead. To guarantee a face, ship the file (see below).

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

This is the part that makes a skin a skin rather than a colour scheme.

Without a `layout`, a skin gets the original stack — a readout, then the command tiles —
so every skin written before this existed is unaffected. With one, the skin composes the
panel itself:

```json
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
```

| Slot | What it draws |
|---|---|
| `nameplate` | An engraved header plate. Defaults to the config's name |
| `annunciator` | A backlit legend cell per command, plus mains and on-top |
| `readout` | `style`: `lcd` or `nixie`. `primary`/`secondary` say what each line shows |
| `gauge` | `source`: `battery` or `signal:<id>`. Optional `width`, `caption`, `trailing` |
| `commands` | The buttons. `style`: `tile` or `key`. `columns`: `0` means one row |
| `lamps` | Indicator lamps. `style`: `plain` or `tape`. `sources` says what they watch |
| `controls` | Float-on-top and close, as panel keys. Takes `onTop`, `onTopNote`, `close`, `closeNote`; English by default |
| `spacer` | Pushes everything after it to the bottom |
| `row` | Lays its `children` out side by side |

`key` is a **latching pushbutton**: it stays down until pressed again, and its cap never
changes colour, because a physical key is the colour it is. State shows on the lamps and
the annunciator, not on the cap.

`lamps` with `"style": "tape"` writes each caption on a torn strip of tape in the `hand`
font instead of printing it under the lamp — for a panel that looks relabelled rather than
manufactured. The tear and the angle come from the command's id, so a given lamp looks the
same on every redraw.

## Watching things, not just switching them

A command is something you press. A **signal** is something you read — how full a context
window is, whether a background job is running, what a session has cost. Instruments bind
to one by name:

```json
{ "slot": "gauge", "source": "signal:claude.context", "caption": "Context", "trailing": "LEFT" },
{ "slot": "readout", "style": "nixie", "caption": "Claude Code",
  "primary": "signal:claude.cost", "primaryCaption": "Session cost",
  "secondary": "signal:claude.tokens", "secondaryCaption": "Tokens" },
{ "slot": "lamps", "style": "tape",
  "sources": ["signal:claude.busy", "signal:claude.waiting", "signal:claude.done"] }
```

A readout line takes `uptime`, `mode` or `signal:<id>`. A lamp source takes `commands`
(one lamp per command in the config), `battery` or `signal:<id>`.

A signal carries up to three readings, and an instrument uses the one it needs: a
**fraction** for a needle, a **text** line for a readout, and **active** for a lamp. On a
reading, active means *alarm* rather than *healthy* — the context lamp lights when the
window is nearly full, the way a panel lamp means "look at this".

Binding to a signal nothing reports is not an error: the gauge reads zero, the readout
reads `--` and the lamp stays dark. A skin can name a signal that only some machines have.

What ships: `claude.context`, `claude.cost`, `claude.tokens`, `claude.busy`,
`claude.sessions` (read from Claude Code's own files), and `claude.waiting`,
`claude.done`, `claude.agent` (pushed by hooks). See
[AUTOMATION.md](AUTOMATION.md#watching-claude-code). Anything can push its own with one
HTTP request, so a skin is free to invent names the app has never heard of.

**The app draws every one of these.** A skin chooses from the vocabulary and says what
goes where — it never supplies code, markup or images that get executed. A slot this
version does not recognise is skipped rather than failing the skin, so a layout written
for a later release still renders what it can.

**RBMK Mac Control Panel** is the worked example: square panel, annunciator strip, needle
gauge, amber counter, latching keys, taped lamp labels and a control row. Read its `skin.json` next to this file.

## Sharing

Zip the `.mccskin` folder. The recipient drops it in the Skins folder, or uses
**Settings › Skins › Import…**

The app writes a complete, commented example into your Skins folder on first run, and it
is generated from the live token list — so it can never drift from what the app reads.
