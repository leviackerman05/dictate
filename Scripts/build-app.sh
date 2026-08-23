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
cp Sources/Dictate/Resources/Info.plist "$APP_DIR/Contents/Info.plist"
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
