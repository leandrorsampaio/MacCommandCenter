#!/usr/bin/env bash
#
# Point Claude Code's hooks at Mac Command Center, so the panel lights up when a run
# finishes or stops to ask you something.
#
# Reading `~/.claude` tells the panel what is *true* — how full the context is, what a
# session costs, whether one is working. It cannot tell it what just *happened*: "this
# finished" and "this is waiting for you" leave no trace on disk. Those are hooks.
#
#   scripts/install-claude-hooks.sh            # show what would change
#   scripts/install-claude-hooks.sh --install  # write it
#   scripts/install-claude-hooks.sh --remove   # take it back out
#
# The control API must be on: Settings ▸ Advanced ▸ Enable the local control API. It is
# off by default and binds to 127.0.0.1 only.

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
--show)
    echo "Would merge these hooks into $SETTINGS:"
    echo
    python3 -c "
import json, sys
snippet = json.load(open('$SNIPPET'))
print(json.dumps({'hooks': snippet['hooks']}, indent=2))
"
    echo
    echo "Run with --install to write it, --remove to take it out."
    ;;

--install | --remove)
    python3 - "$SNIPPET" "$SETTINGS" "$MODE" <<'PY'
import json, os, shutil, sys

snippet_path, settings_path, mode = sys.argv[1:4]
hooks = json.load(open(snippet_path))["hooks"]

settings = {}
if os.path.exists(settings_path):
    with open(settings_path) as handle:
        settings = json.load(handle)
    # Settings are hand-edited and hard to reconstruct; never write without a copy.
    shutil.copy2(settings_path, settings_path + ".mcc-backup")

existing = settings.get("hooks", {})
marker = "/v1/signals/claude."

for event, groups in hooks.items():
    # Drop any group this script installed before, so re-running does not stack them up,
    # and leave every hook the user wrote themselves exactly where it is.
    kept = [
        group for group in existing.get(event, [])
        if not any(marker in hook.get("command", "") for hook in group.get("hooks", []))
    ]
    if mode == "--install":
        kept += groups
    if kept:
        existing[event] = kept
    else:
        existing.pop(event, None)

if existing:
    settings["hooks"] = existing
else:
    settings.pop("hooks", None)

os.makedirs(os.path.dirname(settings_path), exist_ok=True)
with open(settings_path, "w") as handle:
    json.dump(settings, handle, indent=2)
    handle.write("\n")

verb = "Installed" if mode == "--install" else "Removed"
print(f"{verb} Mac Command Center hooks in {settings_path}")
if os.path.exists(settings_path + ".mcc-backup"):
    print(f"Previous settings kept at {settings_path}.mcc-backup")
PY
    echo
    echo "Restart any running Claude Code session to pick the change up."
    ;;

*)
    echo "Usage: $(basename "$0") [--show | --install | --remove]" >&2
    exit 2
    ;;
esac
