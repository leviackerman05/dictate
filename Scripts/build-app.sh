#!/bin/sh
set -eu

PRODUCT_NAME="Dictate"
BUNDLE_IDENTIFIER="${DICTATE_BUNDLE_IDENTIFIER:-app.dictate.desktop}"
BUILD_CONFIGURATION="release"
BIN_DIR="$(swift build -c "$BUILD_CONFIGURATION" --product "$PRODUCT_NAME" --show-bin-path)"
APP_DIR="${DICTATE_APP_PATH:-build/Dictate.app}"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/$PRODUCT_NAME" "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"

RESOURCE_BUNDLE="$(find "$BIN_DIR" -maxdepth 1 -type d -name '*.bundle' -print -quit || true)"
if [ -n "$RESOURCE_BUNDLE" ]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"
fi
cp Sources/Dictate/Resources/AppIcon.svg "$APP_DIR/Contents/Resources/AppIcon.svg"
cp Sources/Dictate/Resources/Info.plist "$APP_DIR/Contents/Info.plist"
if command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_IDENTIFIER" "$APP_DIR/Contents/Info.plist"
fi

echo "Built $APP_DIR"
