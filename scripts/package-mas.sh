#!/usr/bin/env bash
#
# Builds and signs the sandboxed App Store build, then wraps it in an installer package
# ready for App Store Connect.
#
# Needs, from your Apple Developer account:
#   • a "Mac App Distribution" certificate      (signs the app)
#   • a "Mac Installer Distribution" certificate (signs the .pkg)
#   • a Mac App Store provisioning profile for this bundle id
#
# Then:
#   MCC_APP_IDENTITY="Apple Distribution: Your Name (TEAMID)" \
#   MCC_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Your Name (TEAMID)" \
#   MCC_PROVISION_PROFILE=~/path/to/MacCommandCenter.provisionprofile \
#   MCC_TEAM_ID=TEAMID \
#   scripts/package-mas.sh
#
# Upload the result with Transporter, or:
#   xcrun altool --upload-app -f build/MacCommandCenter.pkg -t macos \
#       -u you@example.com -p APP_SPECIFIC_PASSWORD
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacCommandCenter"
APP="$ROOT/build/$APP_NAME.app"
PKG="$ROOT/build/$APP_NAME.pkg"

APP_IDENTITY="${MCC_APP_IDENTITY:-}"
INSTALLER_IDENTITY="${MCC_INSTALLER_IDENTITY:-}"
PROFILE="${MCC_PROVISION_PROFILE:-}"
TEAM_ID="${MCC_TEAM_ID:-}"
BUNDLE_ID="${MCC_BUNDLE_ID:-com.leandrorossisampaio.MacCommandCenter}"

for required in APP_IDENTITY INSTALLER_IDENTITY PROFILE TEAM_ID; do
    if [[ -z "${!required}" ]]; then
        echo "Set MCC_${required} first. See the comments at the top of this script." >&2
        exit 2
    fi
done

"$ROOT/scripts/build-app.sh" --channel mas

echo "▸ Embedding the provisioning profile…"
cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"

# The App Store requires these two beyond the sandbox entitlements; they must match the
# provisioning profile, so they are generated here rather than committed.
SIGNING_ENTITLEMENTS="$(mktemp -t mcc-entitlements).plist"
trap 'rm -f "$SIGNING_ENTITLEMENTS"' EXIT
cp "$ROOT/Resources/Entitlements/AppStore.entitlements" "$SIGNING_ENTITLEMENTS"
/usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string $TEAM_ID.$BUNDLE_ID" "$SIGNING_ENTITLEMENTS"
/usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string $TEAM_ID" "$SIGNING_ENTITLEMENTS"

echo "▸ Signing for the App Store…"
codesign --force --timestamp --entitlements "$SIGNING_ENTITLEMENTS" \
    --sign "$APP_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "▸ Checking the sandbox actually applied…"
if ! codesign -d --entitlements - --xml "$APP" 2>/dev/null | plutil -p - | grep -q "app-sandbox"; then
    echo "  The signed app is not sandboxed — App Store Connect will reject it." >&2
    exit 1
fi

echo "▸ Building the installer package…"
rm -f "$PKG"
productbuild --component "$APP" /Applications --sign "$INSTALLER_IDENTITY" "$PKG"

echo "✓ $PKG"
echo "  Upload it with Transporter, or xcrun altool --upload-app."
