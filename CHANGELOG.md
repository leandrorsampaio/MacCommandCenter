# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

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
