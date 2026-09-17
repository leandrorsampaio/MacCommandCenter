# Writing a config

A **skin** decides how the panel looks. A **config** decides what is on it: which buttons
exist, what they say, and what they do. They are separate files so any skin works with any
config.

```
~/Library/Application Support/MacCommandCenter/Configs/
  Developer.mccconfig/
    config.json
```

A bare `MyConfig.json` works too. **Saving reloads the open window.** You can also build
one entirely in **Settings › Configs**, with no JSON at all — rename buttons, change their
icons, reorder them and point them at different actions.

## Shape

```json
{
  "format": 1,
  "id": "developer",
  "name": "Developer",
  "author": "You",
  "groups": [
    {
      "id": "power",
      "title": "Power",
      "commands": [
        {
          "id": "keep-awake",
          "title": "Keep Awake",
          "summary": "Normal sleep settings apply.",
          "icon": "cup.and.saucer.fill",
          "options": [
            {
              "id": "display-on",
              "title": "Awake + Display On",
              "subtitle": "Nothing sleeps, screen stays lit",
              "icon": "sun.max.fill",
              "action": { "type": "keepAwake", "mode": "systemAndDisplay" }
            }
          ]
        }
      ]
    }
  ]
}
```

A **command** is one tile row; its **options** are the buttons in it. Give a command two
options and they behave as a pair, like the two Keep Awake modes.

`icon` is any SF Symbol name — browse them in Apple's SF Symbols app.

## Actions

### `keepAwake`

```json
{ "type": "keepAwake", "mode": "systemAndDisplay" }
{ "type": "keepAwake", "mode": "systemOnly" }
```

Holds a power assertion: `systemAndDisplay` keeps the screen lit too, `systemOnly` lets it
sleep while the Mac keeps running. These **latch** — the button stays lit until pressed
again. Works on battery and on mains.

### `openURL`

```json
{ "type": "openURL", "url": "https://github.com" }
{ "type": "openURL", "url": "file:///Applications/Xcode.app" }
```

Hands the URL to whatever normally opens it. Fires once, does not latch.

### `shell`

```json
{ "type": "shell", "command": "make deploy", "timeout": 120 }
{ "type": "shell", "command": "open -a Terminal", "detached": true }
```

Runs through `/bin/zsh -lc`, a login shell, so `.zprofile` and `.zlogin` are read and your
`PATH` and version-manager shims work. `.zshrc` is **not** read — zsh only sources it for
interactive shells — so aliases defined there are unavailable. Call the real command. The first line of output appears in the readout.

- `timeout` — seconds before the command is killed. Default 30.
- `detached` — fire and forget, for anything long-running. Output is discarded.

**Two things to know.**

1. Shell actions exist only in the **direct download** build. The App Store build is
   sandboxed, so those buttons load but say so instead of running. The command text is
   preserved, so saving the config there does not destroy it.
2. A shell command is **inert until you approve it**. The first press shows the exact
   command with Run Once / Always Allow / Cancel. Editing the command asks again — an
   edited command is a new command. Approvals are listed and revocable in
   **Settings › Advanced**.

That second point is why configs are safe to share. Without it, "try my config" would mean
"run my code."

## Sharing

Zip the `.mccconfig` folder. The recipient drops it in the Configs folder, or uses
**Settings › Configs › Import…**. If it contains shell actions, the app says so before
anything runs.

## Adding a new action type

See [CONTRIBUTING.md](../CONTRIBUTING.md) — it is five steps, and there is a regression
test waiting for the mistake everyone makes.
