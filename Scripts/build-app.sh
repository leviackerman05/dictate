#!/bin/sh
set -eu

PRODUCT_NAME="Dictate"
BUNDLE_IDENTIFIER="${DICTATE_BUNDLE_IDENTIFIER:-app.dictate.desktop}"
BUILD_CONFIGURATION="release"
DEVELOPER_DIR_VALUE="${DEVELOPER_DIR:-$(xcode-select -p)}"
export DEVELOPER_DIR="$DEVELOPER_DIR_VALUE"

case "$DEVELOPER_DIR" in
  */CommandLineTools) echo "Dictate app builds require a matching full Xcode installation; Command Line Tools alone are not sufficient." >&2; exit 1 ;;
esac

SWIFT="$(xcrun --find swift)"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
echo "Using developer directory: $DEVELOPER_DIR"
echo "Using Swift: $($SWIFT --version | head -1)"
echo "Using macOS SDK: $SDK_VERSION ($SDK_PATH)"

case "$SDK_VERSION" in
  26.*) ;;
  *) echo "Dictate requires the macOS 26 SDK; found $SDK_VERSION" >&2; exit 1 ;;
esac

"$SWIFT" build -c "$BUILD_CONFIGURATION" --product "$PRODUCT_NAME"
BIN_DIR="$("$SWIFT" build -c "$BUILD_CONFIGURATION" --product "$PRODUCT_NAME" --show-bin-path)"
APP_DIR="${DICTATE_APP_PATH:-build/Dictate.app}"
APP_BINARY="$BIN_DIR/$PRODUCT_NAME"

test -x "$APP_BINARY"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$APP_BINARY" "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"

RESOURCE_BUNDLE="$(find "$BIN_DIR" -maxdepth 1 -type d -name '*.bundle' -print -quit)"
if [ -n "$RESOURCE_BUNDLE" ]; then cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"; fi
cp Sources/Dictate/Resources/AppIcon.svg "$APP_DIR/Contents/Resources/AppIcon.svg"
cp Sources/Dictate/Resources/MenuBarGlyph.svg "$APP_DIR/Contents/Resources/MenuBarGlyph.svg"
cp Sources/Dictate/Resources/Info.plist "$APP_DIR/Contents/Info.plist"

# macOS uses an ICNS asset for the Dock and Finder icon. Keep the authored
# SVG as the source of truth and compile the full retina icon family during
# the app bundle step.
ICONSET_DIR="$APP_DIR/Contents/Resources/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"
ICON_SOURCE="Sources/Dictate/Resources/AppIcon.svg"
sips -s format png -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -s format png -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -s format png -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -s format png -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -s format png -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -s format png -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -s format png -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -s format png -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -s format png -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -s format png -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET_DIR"
if [ -d Sources/Dictate/Resources/en.lproj ]; then
  cp -R Sources/Dictate/Resources/en.lproj "$APP_DIR/Contents/Resources/en.lproj"
fi
if command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_IDENTIFIER" "$APP_DIR/Contents/Info.plist"
fi

# Sign the completed bundle, after its Info.plist and resources are in place.
# This gives macOS a stable designated identity for microphone and
# Accessibility permissions instead of relying on the linker-signed binary.
codesign --force --deep --sign - --identifier "$BUNDLE_IDENTIFIER" \
  --requirements "=designated => identifier \"$BUNDLE_IDENTIFIER\"" \
  --timestamp=none "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Built $APP_DIR with FluidAudio linked through SwiftPM"
