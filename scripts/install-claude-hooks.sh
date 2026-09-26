#!/usr/bin/env bash
#
# Point Claude Code's hooks at Mac Command Center, so the panel and the PK-4 console hear
# what happens the moment it happens: a session starting and ending, a turn finishing, a
# subagent starting and stopping, a permission prompt, a tool finishing, a compaction.
#
# Reading `~/.claude` tells the app what is *true* — how full the context is, what a
# session costs, whether one is working. It cannot tell it what just *happened*: "this
# finished" and "this is waiting for you" leave no trace on disk. Those are hooks.
#
#   scripts/install-claude-hooks.sh            # show what would change
#   scripts/install-claude-hooks.sh --install  # write it
#   scripts/install-claude-hooks.sh --remove   # take it back out
#
# Every hook is the same line: it pipes the hook's JSON input to the local control API.
# They are `async`, so Claude Code never waits for them, and best-effort, so a closed app
# costs a session nothing. The control API must be on for them to arrive: Settings ▸
# Advanced ▸ Enable the local control API. It is off by default and binds to 127.0.0.1
# only.
#
# Re-running replaces what an earlier version of this script installed, including the
# four single-signal hooks it used to write, and leaves every hook you wrote yourself
# exactly where it is.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNIPPET="$ROOT/scripts/claude-hooks.json"
SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
MODE="${1:---show}"

if [[ ! -f "$SNIPPET" ]]; then
    echo "Missing $SNIPPET" >&2
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is needed to merge JSON safely."
    echo "Paste the 'hooks' block from this file into $SETTINGS by hand:"
    echo "  $SNIPPET"
    exit 1
fi

case "$MODE" in
--show | --install | --remove) ;;
*)
    echo "Usage: $(basename "$0") [--show | --install | --remove]" >&2
    exit 2
    ;;
esac

python3 - "$SNIPPET" "$SETTINGS" "$MODE" <<'PY'
import json, os, shutil, sys

snippet_path, settings_path, mode = sys.argv[1:4]
ours = json.load(open(snippet_path))["hooks"]

settings = {}
if os.path.exists(settings_path):
    with open(settings_path) as handle:
        settings = json.load(handle)
existing = settings.get("hooks", {})

# What this script has ever installed: the four single-signal hooks of the first version,
# and the one event hook of this one.
markers = ("/v1/signals/claude.", "/v1/events/claude")

def is_ours(group):
    return any(
        any(marker in hook.get("command", "") for marker in markers)
        for hook in group.get("hooks", [])
    )

merged = {}
changes = []
for event in sorted(set(existing) | set(ours)):
    groups = existing.get(event, [])
    kept = [group for group in groups if not is_ours(group)]
    had_ours = len(kept) != len(groups)
    if mode != "--remove" and event in ours:
        kept += ours[event]
        changes.append(("replace" if had_ours else "add", event))
    elif had_ours:
        changes.append(("remove", event))
    if kept:
        merged[event] = kept

if mode == "--show":
    if not changes:
        print(f"Nothing to change in {settings_path}.")
    else:
        print(f"Would change {settings_path}:")
        for verb, event in changes:
            print(f"  {verb:8} {event}")
        print()
        print("Each hook runs, in the background:")
        print("  " + next(iter(ours.values()))[0]["hooks"][0]["command"])
        print()
        print("Hooks you wrote yourself are left as they are.")
        print("Run with --install to write it, --remove to take it out.")
    sys.exit(0)

if merged:
    settings["hooks"] = merged
else:
    settings.pop("hooks", None)

os.makedirs(os.path.dirname(settings_path), exist_ok=True)
if os.path.exists(settings_path):
    # Settings are hand-edited and hard to reconstruct; never write without a copy.
    shutil.copy2(settings_path, settings_path + ".mcc-backup")
with open(settings_path, "w") as handle:
    json.dump(settings, handle, indent=2)
    handle.write("\n")

verb = "Installed" if mode == "--install" else "Removed"
print(f"{verb} Mac Command Center hooks in {settings_path}")
for verb, event in changes:
    print(f"  {verb:8} {event}")
if os.path.exists(settings_path + ".mcc-backup"):
    print(f"Previous settings kept at {settings_path}.mcc-backup")
print()
print("Restart any running Claude Code session to pick the change up.")
PY
