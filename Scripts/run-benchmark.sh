#!/bin/sh
set -eu

DEVELOPER_DIR_VALUE="${DEVELOPER_DIR:-$(xcode-select -p)}"
export DEVELOPER_DIR="$DEVELOPER_DIR_VALUE"

case "$DEVELOPER_DIR" in
  */CommandLineTools)
    echo "Dictate benchmarks require the macOS 26 SDK from a matching full Xcode installation." >&2
    exit 1
    ;;
esac

SWIFT="$(xcrun --find swift)"
"$SWIFT" build -c release --product Dictate
BIN_DIR="$("$SWIFT" build -c release --product Dictate --show-bin-path)"
exec "$BIN_DIR/Dictate" benchmark "$@"
