#!/bin/sh
set -eu

APP_PATH="${1:-build/Dictate.app}"
OUTPUT_PATH="${2:-dist/Dictate.dmg}"

test -d "$APP_PATH"
mkdir -p "$(dirname "$OUTPUT_PATH")"

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dictate-dmg.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT HUP INT TERM

ditto "$APP_PATH" "$STAGING_DIR/Dictate.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$OUTPUT_PATH"
hdiutil create \
  -volname "Dictate" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$OUTPUT_PATH"

echo "Created $OUTPUT_PATH"
