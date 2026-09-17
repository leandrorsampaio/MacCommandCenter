import Foundation

/// The starter README written into the user's Configs folder on first run.
enum ConfigAuthoring {

    static var readme: String {
        """
        # Writing a config for Mac Command Center

        A **skin** decides how the panel looks. A **config** decides what is on it: which
        buttons exist, what they say, and what they do. They are separate files so any
        skin works with any config.

        A config is a folder ending in `.mccconfig` holding a `config.json`:

            ~/Library/Application Support/MacCommandCenter/Configs/
              Developer.mccconfig/
                config.json

        A bare `MyConfig.json` works too. **Saving re-loads the open window**, so you can
        edit next to it and watch it change. You can also build one entirely in
        **Settings › Configs**, with no JSON at all.

        ## Shape

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

        A **command** is one tile row; its **options** are the buttons in it. Give a
        command two options and they behave as a pair, like the two Keep Awake modes.

        `icon` is any SF Symbol name. Browse them in Apple's SF Symbols app.

        An option may also carry a **role**: `"role": "danger"` or `"caution"`. That is a
        statement about what the button *means*, not what colour it is — the skin decides how
        danger looks. Leave it out for an ordinary button.


        An option may also carry a **role**: `"role": "danger"` or `"caution"`.
        That is a statement about what the button *means*, not what colour it is — the
        skin decides how danger looks. Leave it out for an ordinary button.
        ## Actions

        ### `keepAwake`

            { "type": "keepAwake", "mode": "systemAndDisplay" }
            { "type": "keepAwake", "mode": "systemOnly" }

        Holds a power assertion: `systemAndDisplay` keeps the screen lit too, `systemOnly`
        lets it sleep while the Mac keeps running. These **latch** — the button stays lit
        until pressed again. Works on battery and on mains.

        ### `openURL`

            { "type": "openURL", "url": "https://github.com" }
            { "type": "openURL", "url": "file:///Applications/Xcode.app" }

        Hands the URL to whatever normally opens it. Fires once, does not latch.

        `http`, `https` and `mailto` open straight away. Every other scheme asks once,
        showing the full URL: `file:` can launch an app or a script and `shortcuts:` can
        run any automation you own, so a config from someone else must not be able to
        start one unseen. Approvals are revocable in Settings > Advanced.

        ### `shell`

            { "type": "shell", "command": "make deploy", "timeout": 120 }
            { "type": "shell", "command": "open -a Terminal", "detached": true }

        Runs through `/bin/zsh -lc`, a login shell, so `.zprofile` and `.zlogin` are read
        and your `PATH` and version-manager shims work. `.zshrc` is **not** read — zsh
        only sources it for interactive shells — so aliases defined there are unavailable.
        Call the real command instead. The first line of output appears in the readout.

        - `timeout` seconds before the command is killed. Default 30.
        - `detached` fires and forgets, for anything long-running.

        **Two things to know.**

        1. Shell actions only exist in the **direct download** build. The App Store build
           is sandboxed, so those buttons load but say so instead of running.
        2. A shell command is **inert until you approve it**. The first press shows you the
           exact command with Run Once / Always Allow / Cancel. Editing the command asks
           again — an edited command is a new command. Approvals are listed and revocable
           in **Settings › Advanced**.

        This matters because configs are meant to be shared. Without it, "try my config"
        would mean "run my code."

        ## Sharing

        Zip the `.mccconfig` folder. The recipient drops it in this folder, or uses
        **Settings › Configs › Import…**. If it contains shell actions, the app says so
        before anything runs.

        """
    }
}
