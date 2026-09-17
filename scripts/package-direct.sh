#!/usr/bin/env bash
#
# Builds, signs, notarizes and packages the direct-download build as a DMG.
#
# Needs a Developer ID certificate in the keychain and a notarytool profile:
#   xcrun notarytool store-credentials MacCommandCenter \
#       --apple-id you@example.com --team-id TEAMID --password APP_SPECIFIC_PASSWORD
#
# Then:
#   MCC_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" scripts/package-direct.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacCommandCenter"
APP="$ROOT/build/$APP_NAME.app"
DMG="$ROOT/build/$APP_NAME.dmg"
IDENTITY="${MCC_SIGN_IDENTITY:-}"
PROFILE="${MCC_NOTARY_PROFILE:-MacCommandCenter}"
ENTITLEMENTS="$ROOT/Resources/Entitlements/Direct.entitlements"

if [[ -z "$IDENTITY" ]]; then
    echo "Set MCC_SIGN_IDENTITY to your Developer ID Application certificate." >&2
    echo "List them with:  security find-identity -v -p codesigning" >&2
    exit 2
fi

"$ROOT/scripts/build-app.sh" --channel direct

echo "▸ Signing with Hardened Runtime…"
# Nested executables sign first, then the bundle.
codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP/Contents/MacOS/mcc"
codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "▸ Building DMG…"
rm -f "$DMG"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

echo "▸ Notarizing (this takes a few minutes)…"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "✓ $DMG"
