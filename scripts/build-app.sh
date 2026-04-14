#!/bin/bash
# Builds Dev-bar.app and Dev-bar.dmg.
#   ./scripts/build-app.sh
# Output: build/Dev-bar.app, build/Dev-bar.dmg
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Dev-bar"
BINARY_NAME="DevBar"
BUNDLE_ID="com.beyondworks.dev-bar"
VERSION="0.1.0"
BUILD_DIR="$ROOT/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
ICONSET="$BUILD_DIR/AppIcon.iconset"
ICNS="$BUILD_DIR/AppIcon.icns"

echo "==> Clean"
rm -rf "$APP_BUNDLE" "$DMG_PATH" "$ICONSET" "$ICNS" "$BUILD_DIR/dmg-stage"
mkdir -p "$BUILD_DIR"

echo "==> Build release binary"
swift build -c release

echo "==> Generate icon PNGs"
swift "$ROOT/tools/generate-icon.swift" "$ICONSET"

echo "==> Convert iconset → icns"
iconutil -c icns "$ICONSET" -o "$ICNS"

echo "==> Assemble .app bundle"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp ".build/release/$BINARY_NAME" "$APP_BUNDLE/Contents/MacOS/$BINARY_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$BINARY_NAME"
cp "$ICNS" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$BINARY_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Ad-hoc codesign"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Build DMG"
DMG_STAGE="$BUILD_DIR/dmg-stage"
mkdir -p "$DMG_STAGE"
cp -R "$APP_BUNDLE" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGE" \
    -ov \
    -format UDZO \
    "$DMG_PATH" > /dev/null
rm -rf "$DMG_STAGE" "$ICONSET"

echo
echo "✓ $APP_BUNDLE"
echo "✓ $DMG_PATH"
