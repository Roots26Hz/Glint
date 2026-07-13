#!/bin/bash
#
# Builds a Release Glint.app and packages it as a drag-to-install DMG in
# dist/. Run from anywhere:
#
#   scripts/package-dmg.sh
#
# Requires: xcodegen, create-dmg (both via Homebrew), Xcode command line tools.
# Note: without a Developer ID certificate the DMG is not notarized; first
# launch on another Mac needs System Settings → Privacy & Security → Open
# Anyway (documented in the README's Install section).

set -euo pipefail
cd "$(dirname "$0")/.."

APPICONSET="Glint/Resources/Assets.xcassets/AppIcon.appiconset"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Glint/Resources/Info.plist)
DMG="dist/Glint-${VERSION}.dmg"

rm -rf dist/staging dist/Glint.iconset dist/Glint.icns "$DMG"
mkdir -p dist/staging dist/Glint.iconset

echo "── Building Release (universal, distribution entitlements)…"
xcodegen generate --quiet
# CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO drops the get-task-allow debug
# entitlement Xcode injects for development signing — shipping it makes
# other Macs refuse to open the app.
xcodebuild -project Glint.xcodeproj -scheme Glint -configuration Release \
    -derivedDataPath dist/DerivedData \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    ONLY_ACTIVE_ARCH=NO ARCHS="arm64 x86_64" \
    build | tail -2

APP="dist/DerivedData/Build/Products/Release/Glint.app"

# Re-sign with a secure timestamp so the signature outlives the yearly
# Apple Development certificate expiry.
codesign --force --timestamp \
    --entitlements Glint/Resources/Glint.entitlements \
    --sign "Apple Development" "$APP"

echo "── Verifying distribution readiness…"
codesign --verify --deep --strict "$APP"
if codesign -d --entitlements - "$APP" 2>/dev/null | grep -q get-task-allow; then
    echo "ERROR: get-task-allow is still present — other Macs would refuse to open this build" >&2
    exit 1
fi
ARCHS_FOUND=$(lipo -archs "$APP/Contents/MacOS/Glint")
case "$ARCHS_FOUND" in
    *arm64*x86_64*|*x86_64*arm64*) ;;
    *) echo "ERROR: expected a universal binary, got: $ARCHS_FOUND" >&2; exit 1 ;;
esac
echo "── Signature OK ($ARCHS_FOUND): $(codesign -dvv "$APP" 2>&1 | grep '^Authority' | head -1 || true)"

echo "── Building volume icon…"
# iconutil needs Apple's <name>x<name>[@2x] file naming.
declare -a MAP=(
    "icon_16.png icon_16x16.png"
    "icon_32.png icon_16x16@2x.png"
    "icon_32.png icon_32x32.png"
    "icon_64.png icon_32x32@2x.png"
    "icon_128.png icon_128x128.png"
    "icon_256.png icon_128x128@2x.png"
    "icon_256.png icon_256x256.png"
    "icon_512.png icon_256x256@2x.png"
    "icon_512.png icon_512x512.png"
    "icon_1024.png icon_512x512@2x.png"
)
for pair in "${MAP[@]}"; do
    src=${pair%% *}; dst=${pair##* }
    cp "$APPICONSET/$src" "dist/Glint.iconset/$dst"
done
iconutil -c icns dist/Glint.iconset -o dist/Glint.icns

echo "── Creating DMG…"
cp -R "$APP" dist/staging/
# Glint isn't notarized (free developer account), so macOS blocks the very
# first open on other Macs; put the unblock steps inside the DMG where they
# can't be missed.
cat > "dist/staging/HOW TO INSTALL.txt" <<'EOF'
INSTALLING GLINT
=================

1. Drag Glint onto the Applications folder in this window.

2. Open Glint from Applications. macOS will say it "cannot be
   opened" or could not verify it is free of malware — that is
   expected: Glint is an open-source app that is not notarized
   by Apple (that requires a paid developer account). Click
   "Done" — NOT "Move to Trash".

3. Open System Settings → Privacy & Security, scroll to the
   bottom, and click "Open Anyway" next to the Glint message.
   Do this within an hour of step 2, then confirm.

4. Glint now opens normally, this was a one-time step. Grant
   the permissions it asks for (Music automation, Bluetooth,
   Accessibility, System Audio Recording) — each one powers a
   notch feature and nothing is stored or sent anywhere.

Terminal alternative to steps 2-3:
   xattr -dr com.apple.quarantine /Applications/Glint.app
EOF
echo "── Rendering DMG background…"
swift scripts/generate-dmg-background.swift

create-dmg \
    --volname "Glint" \
    --background dist/dmg-background.png \
    --volicon dist/Glint.icns \
    --window-size 660 420 \
    --icon-size 128 \
    --icon "Glint.app" 165 220 \
    --app-drop-link 495 220 \
    --icon "HOW TO INSTALL.txt" 330 385 \
    --hide-extension "Glint.app" \
    "$DMG" \
    dist/staging

rm -rf dist/staging dist/Glint.iconset
echo "── Done: $DMG ($(du -h "$DMG" | cut -f1 | tr -d ' '))"
