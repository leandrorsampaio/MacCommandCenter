#!/usr/bin/env bash
#
# Builds the app, installs it to /Applications, and puts `mcc` on your PATH.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacCommandCenter"
DESTINATION="/Applications/$APP_NAME.app"
CLI_LINK="/usr/local/bin/mcc"

"$ROOT/scripts/build-app.sh"

echo "▸ Installing to $DESTINATION…"
osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || true
rm -rf "$DESTINATION"
cp -R "$ROOT/build/$APP_NAME.app" "$DESTINATION"

echo "▸ Linking $CLI_LINK…"
if [[ -w "$(dirname "$CLI_LINK")" ]] || sudo -n true 2>/dev/null; then
    sudo mkdir -p "$(dirname "$CLI_LINK")"
    sudo ln -sf "$DESTINATION/Contents/MacOS/mcc" "$CLI_LINK"
    echo "  linked"
else
    echo "  skipped (needs sudo). Run manually:"
    echo "    sudo ln -sf \"$DESTINATION/Contents/MacOS/mcc\" $CLI_LINK"
fi

echo "▸ Launching…"
open "$DESTINATION"
echo "✓ Installed. Look for the cup icon in your menu bar."
