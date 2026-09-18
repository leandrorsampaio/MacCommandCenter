# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Signals: things the panel watches rather than switches.** A command has an owner that
  can be told to change state; a signal has a source that reports it and nothing the panel
  can do about it. One signal carries a fraction for a needle, a line of text for a
  readout and an active flag for a lamp, and an instrument uses whichever it needs.
  Instruments bind by name — `"source": "signal:claude.context"` — and binding to a signal
  nothing reports is not an error: the needle reads zero and the lamp stays dark.
- **Claude Code on the panel.** Context left, session cost and token totals as
  instruments, plus lamps for working, waiting on you, and just finished. The first group
  is read from the files Claude Code already writes; the last two are pushed by hooks
  (`scripts/install-claude-hooks.sh`, which leaves your own hooks alone, does not stack up
  on re-runs and keeps a backup).

  The transcript is *followed* rather than re-read: a long session's file runs to tens of
  megabytes, and the `cost-state` checkpoint that carries the dollar figure sits megabytes
  back from the end, so a tail window found it at the start of a session and lost it by
  the middle. Each file is read once and only its new bytes after that — 294 ms for 26 MB,
  then nothing.

  Not included: the five-hour and weekly quota. It is not written to disk anywhere, and an
  undocumented endpoint is not something to hang an instrument on.
- **`POST /v1/signals/{id}`**, so anything on the machine can report into the panel —
  `text`, `fraction`, `active` and a `ttl` after which the reading stops being believed. A
  source that dies stops lighting its lamp instead of lying until the next launch. Behind
  the same header guard as a command, and `/v1/state` now carries signals too.
- Layout slots gained the bindings to go with it: a `gauge` takes `signal:<id>` as well as
  `battery`, a `readout` says what each of its two lines shows, and `lamps` takes
  `sources` — any mix of `commands`, `battery` and named signals.

### Changed

- **The Reactor Control skin is now "RBMK Mac Control Panel"**, nameplate included
  (`РБМК · Пульт управления` over `RBMK Mac Control Panel · БЩУ-1`), and its folder is
  `Skins/RBMK.mccskin`. The skin id is unchanged, so an existing selection survives.
- **Instruments speak English, keys carry both languages.** An annunciator cell, a lamp
  caption and the mode readout take the English half of a `"Русский · English"` label;
  only the keys and the nameplate stay bilingual. One panel mixing two languages across
  its instruments read as a mistake rather than a flourish.
- **A skin supplies the words for the controls row**: `"slot": "controls"` takes
  `onTop`, `onTopNote`, `close` and `closeNote`, so "Закрыть" lives in the skin instead of
  being hardcoded in an otherwise language-neutral app.
- **`legendScale`**, a metric that sizes every key face, lamp caption and annunciator cell
  together. The RBMK panel sets `1.25`.
- **Lamp captions can be written on tape**: `"slot": "lamps", "style": "tape"` puts each
  name on a torn strip in the new `hand` font, at an angle, instead of printing it under
  the lamp. New colour tokens `tape` and `tapeInk`. The tear and the angle come from the
  command's id, so a lamp looks the same on every redraw — deriving them from a random
  number made the row shimmer.
- Two modules side by side end level: a module's content now fills the height the row
  settles on, so the battery gauge no longer stopped short of the counter beside it.
- Keys in a row share a height, and the lamps sit directly on the chassis — the recessed
  strip behind them was the only part of the panel with a background of its own.

### Fixed

Following two external reviews (`review_claude_fable_5_1.md`, `review_gemini_3_8_flash.md`):

- **Clicking the menu bar icon opened the panel without giving it keyboard focus**, so the
  digit shortcuts did nothing and the keystrokes went to whatever app was behind it.
- **`openURL` had no consent gate**, so a shared config could launch an app, a script or a
  Shortcuts automation with one click and no confirmation — in the sandboxed build too.
  Web and mail links stay unprompted; anything that can *start* something now asks, once,
  and is revocable in Settings.
- **HTTP sessions were kept alive only by their own receive closure**, so a client that
  connected and said nothing leaked one forever. Sessions are now tracked, time out after
  ten seconds, are capped, and are closed when the server stops. The server also sends FIN
  before closing, which was truncating responses to any client reusing a connection.
- **Digit shortcuts collided across commands** — every command numbered its options from
  1, so only one of them ever responded.
- **A bare `Name.json` skin or config could not be deleted**: the UI required a package
  folder, so Delete silently did nothing.
- The Settings window centred itself on every open, discarding its saved position.
- "Add Button" was enabled with nothing selected and did nothing.
- The App Store build no longer ships a string directing users to download elsewhere.


- **Switching or reloading a config could run a shell command with no click.** The
  registry restored "still active" option ids across a swap without knowing what they do,
  so an id that meant *stay awake* in one config and *run this command* in another fired
  the command — silently if that exact text had ever been approved. Options now declare
  whether they latch, and only latching ones are restored.
- **Any local client could crash the app** with `Content-Length: -1`: the body index
  walked off the front of the buffer and trapped.
- **A shell command still running when the config reloaded** reported into the registry
  entry its replacement now owned. Outgoing handlers are detached first.
- **The shell timeout could not kill anything that ignores SIGTERM.** It now escalates to
  SIGKILL, instead of leaving a button stuck on "Running…" forever.
- **"Saving reloads the panel" was false for editors that write in place.** A directory
  vnode source only sees entries added, removed or renamed. A content fingerprint is now
  polled as a backstop.
- **The control API changed state on unauthenticated requests** that a web page can issue
  cross-origin. Mutations now require `X-MCC-Client` and no `Origin`.
- **Command ids containing `/`, `+` or `%2F` were unreachable**: the path was decoded
  before it was split.
- **Settings crashed on a huge `timeout`** (`Int(Double)` trap), and a command with ten or
  more options trapped on `Character("10")`.
- **Actions this build cannot read lost their payload on save**, so opening someone's
  config and saving it destroyed what it said.
- **Import deleted the destination before copying**, so a failed copy destroyed what was
  there and re-importing an item already in the folder deleted it.
- The first-run panel landed bottom-left: `fitToContent()` moved the window before the
  "frame still at zero" check could run.
- Skin font `weight` was ignored whenever a family was named.
- `mcc` with the API off ran `open`, toggling the panel onto the screen before failing.
- Symlinked skin and config folders were silently ignored.
- The shell output buffer was read while a worker could still be writing it.
- The 10-second refresh timer rewrote every state entry, waking every observer for nothing.
- Documentation promised shell aliases; `zsh -lc` never reads `.zshrc`.

- **An active Keep Awake no longer switches itself off when a config file changes.** The
  folder watcher rebuilt the command registry on any change in the directory, which turned
  off whatever was running — so saving an unrelated button let the Mac sleep in the middle
  of the work the app exists to protect. Surviving options are now switched back on, and
  an unchanged config skips the rebuild entirely.
- **Detached shell commands no longer hang.** They were handed an output pipe nothing ever
  read, so any command producing more than a buffer's worth of output wedged forever.
  Their output now goes to `/dev/null`.
- **Settings switches now show what they did.** Launch-at-login, float-on-top and the
  control API were computed properties over `UserDefaults`; `@Observable` only tracks
  stored ones, so flipping a switch changed the setting without redrawing it. A failed
  login-item registration now puts the switch back rather than lying.
- **Revert in the config editor no longer leaves Save enabled**, and the editor no longer
  claims unsaved changes it does not have.
- **Shell command timeouts were racy**: the watchdog wrote `timedOut` from one queue while
  the caller read it from another. Now guarded.
- **The global shortcut's registry is thread-safe.** It used `MainActor.assumeIsolated`
  from `deinit` and from a Carbon C callback, either of which could trap off the main
  thread.
- **Config commands named in any language work over the API.** The CLI interpolated the
  command id straight into a URL, so a non-ASCII name produced a nil URL and a misleading
  "app isn't running" message.
- Shell commands survived a save in the App Store build: they had been decoded to
  `.unavailable`, which erased the command text on the next write.
- The control server held its registry `unowned` and could read a destroyed reference.
- The control-server tests bound a fixed port and failed intermittently against sockets
  left over from the previous test process.
- The panel could restore off-screen — a saved frame of `y = -154` left no way to drag it
  back. Frames are now clamped to the visible screen.

### Added

- Reactor Control ships a real key click, derived from Universfield's "Click Button" on
  Pixabay under a licence that permits redistribution in a product. Trimmed from 496 ms to
  158 ms and summed to mono: the original had 21 ms of silence before the attack, which a
  key press reads as lag.

### Added

- **Needle flicker** (`"flicker": true`), so an analogue gauge wanders the way a real
  moving coil does: it moves on roughly seven ticks in ten, by up to five points of full
  scale, and holds the rest of the time.
- **Font stacks.** `"family"` takes a list and the first installed face wins, which is how
  a skin can ask for Bahnschrift — which ships with Office, not macOS — and say what to
  use instead.
- **Skins can ship a click sound**: `"chrome": { "keySound": "sounds/click.wav" }`,
  resolved inside the skin folder like a font, falling back to the synthesised click.

### Fixed

- **A string in `chrome` broke the whole skin.** `chrome` decoded as `[String: Bool]`, so
  adding `keySound` failed the entire manifest; the catalog then fell back to the first
  available skin *and persisted that*, which looked like the skin quietly doing nothing.
  Chrome is a typed struct now, and a new test loads every bundled skin through the real
  decoder so a broken manifest fails CI rather than the user's panel.

### Added

- **Button roles.** A config can mark an option `danger` or `caution`; the skin decides
  what that looks like via `keyDanger` and `keyCaution`. Meaning stays in the config,
  colour stays in the skin — so a skin is free to render danger as green phosphor if that
  is what it is. АЗ-5 is red because it is an emergency key, not because a skin said so.

### Added

- **A skin now owns the panel's layout, not just its colours.** It declares rows from a
  fixed vocabulary of slots — nameplate, annunciator, readout, gauge, commands, lamps,
  controls, spacer, row — and picks how commands draw. The app renders every part, so a
  skin is still a data file rather than code, and a slot a build does not recognise is
  skipped rather than failing the skin. A skin with no `layout` gets the original stack,
  unchanged.
- **Latching relief keys** (`"style": "key"`). A key falls the moment it is pressed and
  stays down until pressed again, over-travelling slightly before it releases. Its cap
  never changes colour — a physical key is the colour it is — so state shows on the lamps.
- **`indicatorDelay`**, which separates the mechanical from the electrical: the key
  latches instantly, the lamps and readout follow after the delay, the way they would if a
  relay elsewhere had to close first.
- **New parts a console skin needs**: engraved nameplate, backlit annunciator cells, a
  nixie counter, an analogue needle gauge, domed indicator lamps, corner screws and a
  synthesised key click.
- **Battery level.** `PowerStatus` now reports charge as well as source, which is what the
  gauge reads.
- **Reactor Control** rebuilt as the worked example: square, annunciator strip, needle
  gauge, amber uptime counter, latching keys, and a control row carrying float-on-top and
  close.

### Fixed

- The power assertion's reason was built from the command's title, so a config in Cyrillic
  produced an assertion that `pmset -g assertions` renders as `named: ""` — invisible to
  the exact command the README tells people to run. It uses the command id now.


- **Reactor Control**, a fifth skin: sage panel, bakelite keys, amber annunciator. The
  first *light* skin, which is what proved the colour tokens were never secretly dark-only.
- **Пульт**, a Cyrillic config to pair with it — the clearest demonstration so far that a
  skin supplies the look and a config supplies the words. PT Sans and PT Mono ship with
  macOS and are ParaType faces, so the Cyrillic needs no download.

### Changed

First pass with the UI actually on screen — screen recording became available, so every
view was captured and inspected instead of reasoned about:

- The inline **Off** button overflowed the panel's right edge. The push-button style forces
  full width, which is right for a bar and wrong beside other content.
- The control API address rendered as **`127.0.0.1:8.787`**. SwiftUI runs an interpolated
  integer through the locale's number formatter, so the port was shown with digit
  grouping — an address that is simply wrong. The shell timeout label had the same fault.
- `cornerRadius` reached only the bevel stroke, so a skin that set it and turned bevels off
  — the shipped **Midnight** does exactly that — got square corners on every surface.
  Every skinned surface now clips to it.


- The panel **scrolls** when a config has more buttons than the display has room for.
  Previously the window was clamped to the screen and the rest was simply clipped, with no
  way to reach it.
- A skin that sets `titlebarHeight: 0` — the shipped **Midnight** does — now gets a small
  close and settings row at the foot of the panel, instead of having no controls at all.
- Switching configs in the editor with unsaved edits asks before discarding them.
- Duplicate command and button ids in a config are reported in Settings. They used to
  replace each other silently, leaving a button on screen that did nothing.
- Font availability is cached. `NSFont(name:)` was being called several times per tile on
  every render to answer a question whose answer cannot change.
- Only the readout's clock ticks now. The whole readout sat on a one-second timeline, so
  the scanline canvas and the analyser were redrawn every second for nothing.
- Dropped the unused `CommandKind.toggle` case; nothing ever produced it.

### Added

- **Keep Awake**, in two modes: Mac and display both on, or Mac on with the display free
  to sleep. Both hold IOKit idle-sleep assertions, so they work on battery as well as on
  mains.
- **Skins.** Appearance is a `.mccskin` folder of JSON: 25 colour tokens, 11 metrics,
  3 font roles, 4 effect switches. Four ship with the app. The folder is watched, so
  saving a file re-skins the open window.
- **Configs.** Which buttons exist, what they say and what they do is a `.mccconfig`
  folder of JSON, editable in Settings or in a text editor. Actions: keep awake, open a
  URL, run a shell command.
- **Trust-on-first-use for shell actions.** A shell button is inert until the exact
  command has been shown and approved. Editing the command asks again. Approvals are
  listed and revocable in Settings.
- **A floating skinned window**, movable and above other windows by default.
- **Global shortcut** (⌘⇧K) via Carbon, which needs no Accessibility permission.
- **Local control API** on `127.0.0.1:8787`, off by default, plus the `mcc` CLI — the
  seam for Stream Decks, Shortcuts and hardware buttons.
- **Two build channels.** A sandboxed App Store build and a notarized direct download.
  Shell actions compile out of the App Store build.

[Unreleased]: https://github.com/leandrorossisampaio/MacCommandCenter/commits/main
