# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
