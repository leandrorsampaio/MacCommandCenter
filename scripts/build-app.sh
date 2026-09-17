#!/usr/bin/env bash
#
# Builds MacCommandCenter.app into ./build.
#
#   scripts/build-app.sh                   direct build (shell actions enabled)
#   scripts/build-app.sh --channel mas     App Store build (sandboxed, no shell actions)
#   scripts/build-app.sh --debug           debug configuration
#
# Signing is ad hoc by default, which is enough to run locally. Release signing lives in
# package-direct.sh and package-mas.sh.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="release"
CHANNEL="direct"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug) CONFIGURATION="debug"; shift ;;
        --channel) CHANNEL="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

if [[ "$CHANNEL" != "direct" && "$CHANNEL" != "mas" ]]; then
    echo "Channel must be 'direct' or 'mas'." >&2
    exit 2
fi

APP_NAME="MacCommandCenter"
DISPLAY_NAME="Mac Command Center"
BUNDLE_ID="${MCC_BUNDLE_ID:-com.leandrorossisampaio.MacCommandCenter}"
VERSION="1.0.0"
BUILD_NUMBER="${MCC_BUILD_NUMBER:-1}"
APP="$ROOT/build/$APP_NAME.app"

if [[ "$CHANNEL" == "mas" ]]; then
    export MCC_APP_STORE=1
    ENTITLEMENTS="$ROOT/Resources/Entitlements/AppStore.entitlements"
else
    unset MCC_APP_STORE || true
    ENTITLEMENTS="$ROOT/Resources/Entitlements/Direct.entitlements"
fi

echo "▸ Building $CHANNEL ($CONFIGURATION)…"
swift build -c "$CONFIGURATION" --package-path "$ROOT" --product "$APP_NAME"
if [[ "$CHANNEL" == "direct" ]]; then
    swift build -c "$CONFIGURATION" --package-path "$ROOT" --product mcc
fi
BIN_PATH="$(swift build -c "$CONFIGURATION" --package-path "$ROOT" --show-bin-path)"

echo "▸ Assembling $APP_NAME.app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_PATH/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

# The CLI ships only in the direct build. A second executable inside a sandboxed App Store
# bundle is a review liability, and a sandboxed CLI would be of little use anyway.
if [[ "$CHANNEL" == "direct" ]]; then
    cp "$BIN_PATH/mcc" "$APP/Contents/MacOS/mcc"
fi

[[ -f "$ROOT/Resources/AppIcon.icns" ]] && cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/"
[[ -d "$ROOT/Skins" ]] && cp -R "$ROOT/Skins" "$APP/Contents/Resources/Skins"
[[ -d "$ROOT/Configs" ]] && cp -R "$ROOT/Configs" "$APP/Contents/Resources/Configs"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>          <string>en</string>
    <key>CFBundleExecutable</key>                 <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>                 <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>      <string>6.0</string>
    <key>CFBundleName</key>                       <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>                <string>$DISPLAY_NAME</string>
    <key>CFBundleIconFile</key>                   <string>AppIcon</string>
    <key>CFBundlePackageType</key>                <string>APPL</string>
    <key>CFBundleShortVersionString</key>         <string>$VERSION</string>
    <key>CFBundleVersion</key>                    <string>$BUILD_NUMBER</string>
    <key>LSApplicationCategoryType</key>          <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>             <string>14.0</string>
    <!-- Menu bar only: no Dock icon, no app menu. -->
    <key>LSUIElement</key>                        <true/>
    <key>NSHighResolutionCapable</key>            <true/>
    <key>NSHumanReadableCopyright</key>           <string>MIT licensed. See LICENSE.</string>
    <key>NSSupportsAutomaticTermination</key>     <false/>
    <key>NSSupportsSuddenTermination</key>        <false/>
</dict>
</plist>
PLIST

echo "▸ Signing (ad hoc, $CHANNEL entitlements)…"
codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP" >/dev/null 2>&1 \
    || echo "  (ad-hoc signing failed — the app still runs locally)"

echo "✓ $APP  [$CHANNEL]"
