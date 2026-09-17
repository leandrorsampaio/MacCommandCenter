# Privacy Policy

**Mac Command Center collects nothing.**

The app has no analytics, no telemetry, no crash reporting, no accounts and no server of
its own. Nothing you do in it is transmitted anywhere, because there is nowhere for it to
go: the app makes no outbound network connections at all.

Last updated: 18 September 2026.

## What stays on your Mac

| Data | Where | Why |
|---|---|---|
| Which skin and config you have selected | macOS preferences | To restore it next launch |
| Window position | macOS preferences | To put the panel back where you left it |
| Shell commands and URLs you have approved | macOS preferences | So an approved button does not ask every time |
| Skins and configs you add | Application Support folder | They are your files |

You can see every approved command and remove them in **Settings ▸ Advanced**, and the
skins and configs folder is a normal folder you can open, edit and delete.

On an App Store install these live inside the app's sandbox container. On a direct install
they live in `~/Library/Preferences` and
`~/Library/Application Support/MacCommandCenter`.

## The local control API

The app can run an HTTP server, **off by default**, which you switch on in
**Settings ▸ Advanced**. When enabled it binds to `127.0.0.1` — the loopback address —
and refuses to listen on any network interface. Requests never leave your Mac, and nothing
outside it can reach the server.

It exists so other things on the same Mac (the `mcc` command, Shortcuts, a Stream Deck)
can press the same buttons. It serves the list of your commands and their current state,
and nothing else.

## What the app can do on your behalf

A config can define buttons that open URLs or run shell commands. Those are **your**
configs, running under your account, doing what you told them to do.

Because configs are meant to be shared, anything that could start something asks first:

- A shell command does nothing until you have seen the exact command text and approved it.
  Editing the command asks again.
- A URL using any scheme other than `http`, `https` or `mailto` asks before opening.

Approvals are stored locally and are revocable in **Settings ▸ Advanced**.

Shell commands do not exist at all in the App Store build, which is sandboxed.

## Third parties

There are none. The app has no dependencies beyond Apple's own frameworks, and integrates
with no external service.

## Children

The app collects no data from anyone, of any age.

## Changes

Any change to this policy will be committed to
[this repository](https://github.com/leandrorsampaio/MacCommandCenter), where its history
is public.

## Contact

Open an issue at
[github.com/leandrorsampaio/MacCommandCenter/issues](https://github.com/leandrorsampaio/MacCommandCenter/issues).
