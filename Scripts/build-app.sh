#!/bin/sh
set -eu

PRODUCT_NAME="Dictate"
BUNDLE_IDENTIFIER="${DICTATE_BUNDLE_IDENTIFIER:-app.dictate.desktop}"
BUILD_CONFIGURATION="release"
swift build -c "$BUILD_CONFIGURATION" --product "$PRODUCT_NAME" >/dev/null 2>&1 || true
BIN_DIR="$(swift build -c "$BUILD_CONFIGURATION" --product "$PRODUCT_NAME" --show-bin-path)"
APP_DIR="${DICTATE_APP_PATH:-build/Dictate.app}"
APP_BINARY="$BIN_DIR/$PRODUCT_NAME"
CORE_LIBRARY=""

# Some macOS Command Line Tools can typecheck the package but fail to emit the
# executable into SwiftPM's release directory. Keep the app build usable in
# that environment with the same two-target invocation used by CI.
if [ ! -x "$APP_BINARY" ]; then
  SDK_PATH="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || echo /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk)"
  CORE_BUILD_DIR="/private/tmp/dictate-app-build"
  rm -rf "$CORE_BUILD_DIR"
  mkdir -p "$CORE_BUILD_DIR"
  CORE_SOURCES="$(rg --files Sources/DictateCore -g '*.swift')"
  APP_SOURCES="$(rg --files Sources/Dictate -g '*.swift')"
  swiftc -swift-version 6 -target arm64-apple-macosx26.0 -sdk "$SDK_PATH" \
    -module-cache-path /private/tmp/dictate-swift-module-cache \
    -parse-as-library -enable-testing -emit-library -emit-module \
    -module-name DictateCore -emit-module-path "$CORE_BUILD_DIR/DictateCore.swiftmodule" \
    -Xlinker -install_name -Xlinker @rpath/libDictateCore.dylib \
    -o "$CORE_BUILD_DIR/libDictateCore.dylib" $CORE_SOURCES
  swiftc -swift-version 6 -target arm64-apple-macosx26.0 -sdk "$SDK_PATH" \
    -module-cache-path /private/tmp/dictate-swift-module-cache \
    -I "$CORE_BUILD_DIR" -L "$CORE_BUILD_DIR" -lDictateCore \
    -Xlinker -rpath -Xlinker '@loader_path/../Frameworks' $APP_SOURCES \
    -o "$CORE_BUILD_DIR/$PRODUCT_NAME"
  APP_BINARY="$CORE_BUILD_DIR/$PRODUCT_NAME"
  CORE_LIBRARY="$CORE_BUILD_DIR/libDictateCore.dylib"
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$APP_BINARY" "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"
if [ -n "$CORE_LIBRARY" ]; then
  mkdir -p "$APP_DIR/Contents/Frameworks"
  cp "$CORE_LIBRARY" "$APP_DIR/Contents/Frameworks/libDictateCore.dylib"
fi

RESOURCE_BUNDLE=""
if [ -d "$BIN_DIR" ]; then
  RESOURCE_BUNDLE="$(find "$BIN_DIR" -maxdepth 1 -type d -name '*.bundle' -print -quit || true)"
fi
if [ -n "$RESOURCE_BUNDLE" ]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"
fi
cp Sources/Dictate/Resources/AppIcon.svg "$APP_DIR/Contents/Resources/AppIcon.svg"
cp Sources/Dictate/Resources/Info.plist "$APP_DIR/Contents/Info.plist"
if [ -d Sources/Dictate/Resources/en.lproj ]; then
  cp -R Sources/Dictate/Resources/en.lproj "$APP_DIR/Contents/Resources/en.lproj"
fi
if command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_IDENTIFIER" "$APP_DIR/Contents/Info.plist"
fi

echo "Built $APP_DIR"
