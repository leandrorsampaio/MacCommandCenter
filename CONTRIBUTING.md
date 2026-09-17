# Contributing

Thanks for taking a look. This is a small, native macOS app with no third-party
dependencies, and the aim is to keep it that way.

## Getting set up

```bash
git clone https://github.com/leandrorossisampaio/MacCommandCenter.git
cd MacCommandCenter
swift test              # 28 tests, all offline
scripts/build-app.sh    # -> build/MacCommandCenter.app
open build/MacCommandCenter.app
```

`open Package.swift` gives you a working Xcode project — there is no `.xcodeproj` to keep
in sync, and release packaging is done by the scripts in `scripts/`.

Before opening a pull request:

```bash
swift test
swift format lint --recursive --strict Sources Tests
MCC_APP_STORE=1 swift build -c release --product MacCommandCenter
```

That last one matters: the App Store build compiles shell actions out, so it can break
without the default build noticing. CI runs all three.

## How the pieces fit

| Module | Knows about |
|---|---|
| `AppSupport` | Sandbox-aware paths, directory watching. Nothing else. |
| `CommandCore` | The command registry, power assertions, the HTTP API. No UI, no config format. |
| `SkinKit` | Appearance only. Does not know what a command is. |
| `ConfigKit` | Behaviour: the config format, actions, shell consent. Depends on `CommandCore`. |
| `MacCommandCenterApp` | The AppKit shell and SwiftUI views that tie the above together. |
| `mcc` | A thin HTTP client. Depends only on `CommandCore`'s models. |

The rule that keeps this honest: **the panel does not know what a command is, and a
command does not know it is on a panel.** Everything meets at `CommandCenter`.

## Adding an action type

Actions are what a config button can do. To add one:

1. Add a case to `ActionSpec` in `Sources/ConfigKit/ActionSpec.swift`, and say whether it
   latches (leaves state to turn off again) or fires once.
2. Handle it in `ConfigCodec.decodeAction` and `encodeAction`. **Decode it even where it
   cannot run** — degrading to `.unavailable` at decode time erases the payload on the
   next save. There is a regression test for exactly this.
3. Perform it in `ConfiguredCommand.activate`.
4. Add it to `ActionKind` in `ButtonDetailView.swift` so the editor can build it.
5. Document it in `Sources/ConfigKit/ConfigAuthoring.swift` — that text becomes the README
   in the user's Configs folder.

If your action can reach outside the app — the filesystem, the network, other processes —
it needs the same treatment as shell actions: unavailable under the sandbox, and gated
behind explicit consent everywhere else.

## Capabilities that were investigated and rejected

Before adding one of these, know that it was looked at and turned down for a reason:

- **Do Not Disturb / Focus modes.** There is no public API to set a Focus mode. Every app
  that appears to do it is either driving Shortcuts or writing to
  `~/Library/DoNotDisturb/DB`, which is undocumented, breaks between releases and is not
  sandbox-reachable. If you want a Focus button today, make it a `shell` action that calls
  `shortcuts run "…"`, where the Shortcut does the work.
- **Display brightness.** `CoreDisplay_Display_SetUserBrightness` is private — an App
  Store rejection — and the public `IODisplaySetFloatParameter` does not affect the
  built-in display on Apple Silicon. There is no correct way to do this in a sandboxed
  app.
- **Audio output switching.** This one *is* feasible:
  `AudioObjectSetPropertyData` with `kAudioHardwarePropertyDefaultOutputDevice` is public
  and works under the sandbox. It was left out only because nobody asked for it, not
  because it cannot be done. It would be a reasonable first contribution.
- **Auto-update for the direct build.** Sparkle is the obvious answer and it is a
  third-party dependency, which this project does not take. Until there is a better
  option, direct users update by downloading a new DMG; a Homebrew cask would be a
  reasonable contribution.
- **Localisation.** The app is English-only. Nothing blocks translating it — the strings
  are ordinary literals — but half-translating a UI is worse than not starting, so it is
  all or nothing.
- **Skinnable icons.** Icons come from the *config*, not the skin, because the config is
  what knows what a button means. Letting a skin override them would mean a skin deciding
  that "Keep Awake" looks like a sun, which is the config author's call.

## Adding a skin token

1. Add the property to `SkinColors` / `SkinMetrics` / `SkinEffects`, and its name to the
   matching `keys` array.
2. Handle it in the `subscript` or `apply` method. Clamp numbers.
3. Give it a value in `Skin.classic`.
4. Document it in `SkinAuthoring.readme`.

Steps 1 and 4 are checked by tests: the generated example skin must contain every
declared token, and the README must mention every colour. If you skip one, CI says so.

## A trap when testing both channels

Both builds use the same bundle id, which is correct for shipping but bites during
development: once you have run the sandboxed build, macOS creates a container for that id
and **`defaults write` starts redirecting into it**, while the non-sandboxed build keeps
reading `~/Library/Preferences`. A setting you write from the shell then appears to be
ignored.

Read what the app actually sees, not what `defaults read` reports:

```bash
plutil -p ~/Library/Preferences/com.leandrorossisampaio.MacCommandCenter.plist
plutil -p ~/Library/Containers/com.leandrorossisampaio.MacCommandCenter/Data/Library/Preferences/*.plist
```

Also note that writing defaults while the app is running gets clobbered when the app next
saves its own snapshot. Quit it first.

## House style

- **No third-party dependencies.** If AppKit or SwiftUI can do it, use them.
- **Comments explain why, not what.** A comment that restates the code is noise; one that
  records a constraint or a rejected alternative is worth keeping.
- **Degrade, do not crash.** A malformed skin or config is a normal event: the app reports
  it in Settings and carries on. There are tests for every malformed-input path.
- **Accessibility is not optional.** Real `Button`s, labels on icon-only controls.
- Public API gets a doc comment. Internal code gets one when the reason is not obvious.

## Reporting a security issue

Please do not open a public issue for anything involving shell actions or the control API.
Email the address in `LICENSE` instead.
