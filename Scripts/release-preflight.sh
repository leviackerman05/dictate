#!/bin/sh
set -eu

APP_PATH="${DICTATE_APP_PATH:-build/Dictate.app}"
DMG_PATH="${DICTATE_DMG_PATH:-dist/Dictate.dmg}"
CHECKSUM_PATH="${DICTATE_CHECKSUM_PATH:-dist/Dictate.dmg.sha256}"
EXPECTED_BUNDLE_ID="${DICTATE_BUNDLE_IDENTIFIER:-app.dictate.desktop}"

fail() {
  echo "preflight: $*" >&2
  exit 1
}

value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || fail "missing Info.plist key $2"
}

DEVELOPER_DIR_VALUE="${DEVELOPER_DIR:-$(xcode-select -p)}"
export DEVELOPER_DIR="$DEVELOPER_DIR_VALUE"
case "$DEVELOPER_DIR" in
  */CommandLineTools) fail "full Xcode with the macOS 26 SDK is required" ;;
esac

./Scripts/build-app.sh
./Scripts/create-dmg.sh "$APP_PATH" "$DMG_PATH"

PLIST="$APP_PATH/Contents/Info.plist"
BINARY="$APP_PATH/Contents/MacOS/Dictate"
test -f "$PLIST" || fail "missing $PLIST"
test -x "$BINARY" || fail "missing executable $BINARY"

ARCHS="$(lipo -archs "$BINARY")"
test "$ARCHS" = "arm64" || fail "expected an arm64-only executable, found: $ARCHS"
BINARY_MIN_OS="$(xcrun vtool -show-build "$BINARY" | awk '/minos/{print $2; exit}')"
test "$BINARY_MIN_OS" = "26.0" || fail "executable minimum OS must be 26.0, found: $BINARY_MIN_OS"
test "$(value "$PLIST" LSMinimumSystemVersion)" = "26.0" || fail "LSMinimumSystemVersion must be 26.0"
test "$(value "$PLIST" CFBundleIdentifier)" = "$EXPECTED_BUNDLE_ID" || fail "unexpected bundle identifier"
test -n "$(value "$PLIST" CFBundleShortVersionString)" || fail "missing marketing version"
test -n "$(value "$PLIST" CFBundleVersion)" || fail "missing build version"
test -n "$(value "$PLIST" NSMicrophoneUsageDescription)" || fail "missing microphone usage description"
test -n "$(value "$PLIST" NSSpeechRecognitionUsageDescription)" || fail "missing speech recognition usage description"

for resource in AppIcon.icns AppIcon.svg MenuBarGlyph.svg en.lproj/Localizable.strings; do
  test -e "$APP_PATH/Contents/Resources/$resource" || fail "missing resource $resource"
done
find "$APP_PATH/Contents/Resources" -maxdepth 1 -type d -name '*.bundle' -print -quit | grep -q . \
  || fail "missing SwiftPM resource bundle"

if find "$APP_PATH" \( -name '*.mlmodel' -o -name '*.mlmodelc' -o -name '*.mlpackage' \) -print -quit | grep -q .; then
  fail "model assets must not be bundled in the release app"
fi

codesign --verify --deep --strict "$APP_PATH" || fail "code signature verification failed"
SIGNATURE_DETAILS="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)"
if printf '%s\n' "$SIGNATURE_DETAILS" | grep -q 'Signature=adhoc'; then
  SIGNING_STATUS="ad-hoc signed (not Developer ID signed)"
else
  SIGNING_STATUS="non-ad-hoc signature detected; inspect codesign output before release"
fi

SPCTL_LOG="$(mktemp "${TMPDIR:-/tmp}/dictate-spctl.XXXXXX")"
if spctl --assess --type execute --verbose=2 "$APP_PATH" >"$SPCTL_LOG" 2>&1; then
  GATEKEEPER_STATUS="accepted by Gatekeeper assessment"
else
  GATEKEEPER_STATUS="not accepted by Gatekeeper (expected for the current non-notarized community build)"
fi

hdiutil imageinfo "$DMG_PATH" >/dev/null || fail "DMG metadata is invalid"
MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dictate-preflight-mount.XXXXXX")"
cleanup() {
  hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
  rmdir "$MOUNT_DIR" >/dev/null 2>&1 || true
  rm -f "$SPCTL_LOG"
}
trap cleanup EXIT HUP INT TERM
hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT_DIR" "$DMG_PATH" >/dev/null
test -d "$MOUNT_DIR/Dictate.app" || fail "DMG does not contain Dictate.app"
test -L "$MOUNT_DIR/Applications" || fail "DMG does not contain the Applications shortcut"
hdiutil detach "$MOUNT_DIR" >/dev/null
rmdir "$MOUNT_DIR"

mkdir -p "$(dirname "$CHECKSUM_PATH")"
(cd "$(dirname "$DMG_PATH")" && shasum -a 256 "$(basename "$DMG_PATH")") > "$CHECKSUM_PATH"

echo "Release preflight passed"
echo "  executable: $ARCHS, Mach-O minimum macOS $BINARY_MIN_OS, bundle minimum macOS $(value "$PLIST" LSMinimumSystemVersion)"
echo "  bundle: $(value "$PLIST" CFBundleIdentifier) $(value "$PLIST" CFBundleShortVersionString) ($(value "$PLIST" CFBundleVersion))"
echo "  signing: $SIGNING_STATUS"
echo "  Gatekeeper: $GATEKEEPER_STATUS"
echo "  package: $DMG_PATH"
echo "  checksum: $CHECKSUM_PATH"
