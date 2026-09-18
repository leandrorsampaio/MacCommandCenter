# Driving it from somewhere else

The panel is one way in. Everything it does is also reachable from a shell command, a
local HTTP request, or a keyboard — which is what makes physical buttons possible.

Start here, because it is the shortest path and most people stop at the first row:

| You have | Use | Needs the control API? |
|---|---|---|
| A macro pad or programmable keyboard | **Keystrokes.** No code at all. | No |
| Shortcuts, Raycast, Alfred | `mcc` | Yes |
| A Stream Deck | System ▸ Open, running `mcc` | Yes |
| A microcontroller on your network | HTTP, through a relay | Yes |

---

## The no-code path: a macro pad

This works today with nothing installed and the control API switched off.

The app registers **⌘⇧K** system-wide, and while the panel has focus the digit keys pick
options in order — `1`, `2`, `3` … numbered across the whole panel, not per command.
`Esc` closes it.

So any keyboard that can send a macro — QMK, ZMK, VIA, a Pi Pico running CircuitPython as
a USB HID device, most gaming pads — can drive it:

```
Key 1  ->  Cmd+Shift+K, 1        (Awake + Display On)
Key 2  ->  Cmd+Shift+K, 2        (Awake, Display Off)
Key 3  ->  Cmd+Shift+K, Escape   (open and dismiss, i.e. just look)
```

In QMK, as a tap-dance-free macro:

```c
case MCC_AWAKE_DISPLAY_OFF:
    if (record->event.pressed) {
        SEND_STRING(SS_LCMD(SS_LSFT("k")) SS_DELAY(120) "2");
    }
    return false;
```

The delay matters: the panel has to appear and take focus before the digit lands. 120 ms
is comfortable; 50 ms is usually enough.

**Why this is the recommended path.** It needs no network entitlement, no daemon, nothing
enabled in Settings, and it keeps working if the HTTP API is ever removed. The keyboard is
talking to macOS, not to the app.

Its one limit: it is write-only. The pad cannot light an LED to show what is on. For that
you need the API below.

---

## Turn the control API on

Everything from here needs **Settings ▸ Advanced ▸ Enable the local control API**. It is
off by default and binds to `127.0.0.1` only.

```bash
mcc                            # what's on
mcc list                       # every command and option id
mcc awake display-off
mcc on     <command> <option>
mcc off    <command>
mcc toggle <command> <option>
```

`mcc` ships inside the app bundle. To put it on your `PATH`:

```bash
sudo ln -sf /Applications/MacCommandCenter.app/Contents/MacOS/mcc /usr/local/bin/mcc
```

It is not included in the App Store build — a second executable inside a sandboxed bundle
is a review liability, and a sandboxed CLI would be of little use anyway.

---

## Shortcuts

Create a shortcut with a single **Run Shell Script** action:

```bash
/Applications/MacCommandCenter.app/Contents/MacOS/mcc toggle keep-awake display-off
```

Assign it a keyboard shortcut in Shortcuts, or call it from Siri, a Focus automation, or a
Stream Deck. A Shortcuts automation on "When I open Xcode" is a decent way to have the Mac
stay awake without thinking about it.

## Raycast

Save as a script command (`~/.raycast/scripts/keep-awake.sh`):

```bash
#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Toggle Keep Awake
# @raycast.mode compact
# @raycast.packageName Mac Command Center

/Applications/MacCommandCenter.app/Contents/MacOS/mcc toggle keep-awake display-off
```

## Stream Deck

Use the built-in **System ▸ Open** action and point it at a one-line `.sh` file, or the
Terminal plugin. There is no dedicated plugin and there does not need to be — every button
is a shell command.

---

## HTTP directly

```
GET  /v1/state                                          read, open
GET  /v1/commands                                       read, open
GET  /v1/signals                                        read, open
ANY  /v1/commands/{id}/activate?option={optionID}       needs the header
ANY  /v1/commands/{id}/toggle?option={optionID}         needs the header
ANY  /v1/commands/{id}/deactivate                       needs the header
ANY  /v1/signals/{id}?text=…&fraction=…&active=…&ttl=…  needs the header
ANY  /v1/signals/{id}?clear=1                           needs the header
```

Anything that changes state must send `X-MCC-Client` and must not send `Origin`:

```bash
curl -H "X-MCC-Client: 1" \
  "http://127.0.0.1:8787/v1/commands/keep-awake/toggle?option=display-off"
```

That pair is what stops a web page driving your Mac. A browser can reach loopback with a
simple cross-origin request, but it cannot add a custom header without a preflight, and no
preflight is answered. `GET` is accepted for the mutating routes on purpose, so the
simplest possible firmware can drive it with one request.

Reading `/v1/state` gives you every command, its options and what is currently on — which
is what you would poll to light an LED on a button box.

---

## Watching Claude Code

The panel can report on Claude Code as well as drive your Mac: how much context is left,
what the session has cost, whether one is working, and whether one is waiting on you.

**What it reads, with nothing switched on.** Claude Code keeps `~/.claude/sessions/*.json`
for each running session and a transcript per session under `~/.claude/projects/`. Reading
those gives five signals, polled every few seconds:

| Signal | Reading |
|---|---|
| `claude.context` | Tokens left in the window, as a fraction and a line. Alarms under 20% |
| `claude.cost` | Session cost in dollars, as of the last checkpoint |
| `claude.tokens` | Tokens in and out, live |
| `claude.busy` | Lit while a session is working |
| `claude.sessions` | How many are running |

The transcript is read once and followed after that, the way `tail -f` does — a long
session's file runs to tens of megabytes, and re-reading it every few seconds to watch two
numbers would be absurd.

Two caveats worth knowing. **Cost updates at checkpoints**, not continuously: Claude Code
writes its `cost-state` record when a session starts, compacts and exits, so the figure is
the newest one on disk rather than the figure this second. Tokens are summed live and are
current. And **the five-hour and weekly quota is not available** — it is not written to
disk anywhere, and an undocumented endpoint is not something to hang an instrument on.

This half is direct-download only. The App Store build is sandboxed and has no business
reading another tool's files in your home folder.

**What needs hooks.** "A run just finished" and "Claude is waiting for you" leave no trace
on disk, so they are pushed instead:

```bash
scripts/install-claude-hooks.sh            # show what would change
scripts/install-claude-hooks.sh --install  # write it
scripts/install-claude-hooks.sh --remove   # take it back out
```

That adds four hooks to `~/.claude/settings.json`, each one `curl` into the control API:
`Stop` lights `claude.done`, `Notification` lights `claude.waiting`, `SubagentStop` lights
`claude.agent`, and `UserPromptSubmit` clears the first two. Your own hooks are left where
they are, re-running does not stack them up, and the previous settings are kept alongside
as `settings.json.mcc-backup`.

Every call is best-effort — `-m 2` and `|| true` — so a closed panel or a control API
switched off costs the hook nothing.

**Pushing your own.** Nothing about this is specific to Claude Code. Any script can report
into the panel:

```bash
curl -H "X-MCC-Client: 1" \
  "http://127.0.0.1:8787/v1/signals/build.status?label=Build&text=passing&ttl=600"
```

`fraction` (0…1) drives a needle, `text` a readout line, `active` a lamp, and `ttl`
seconds is how long it is believed — a source that stops reporting stops lighting its
lamp rather than lying until the next launch. A skin binds to it by name; see
[SKINS.md](SKINS.md#watching-things-not-just-switching-them).

---

## A microcontroller on your network

**The server binds to `127.0.0.1` and nothing else.** A device on your LAN cannot reach it
directly, by design: a control API that starts shell commands has no business listening on
a network interface.

Bridge it deliberately instead. On the Mac:

```bash
# Expose it to the LAN for as long as this stays running.
socat TCP-LISTEN:8788,fork,bind=0.0.0.0 TCP:127.0.0.1:8787
```

Think about what that means before you run it: anyone on the network can then trigger your
buttons, including any shell command you have approved. On a home network behind a router
that is usually fine. On a café network it is not.

The device side is then an ordinary request:

```cpp
#include <HTTPClient.h>

void toggleKeepAwake() {
    HTTPClient http;
    http.begin("http://192.168.1.50:8788/v1/commands/keep-awake/toggle?option=display-off");
    http.addHeader("X-MCC-Client", "1");
    int status = http.GET();
    http.end();
}
```

To light an LED from the real state, poll `/v1/state` every second or two and look at
`commands[].state.activeOptionID`.

A safer alternative to `socat`, if the device is USB-attached: have it act as a keyboard
and use the no-code path at the top instead.
