#!/bin/sh
# Installs the tested release; deliberately never invokes Git, Swift or Xcode.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=$(cat "$ROOT/Release/version.txt")
RELEASE_URL="https://github.com/leviackerman05/dictate/releases/download/$VERSION"
fail() { printf '%s\n' "Dictate: $*" >&2; exit 1; }
case "${1:-}" in
  --help|-h) printf '%s\n' 'Usage: ./Scripts/start.sh [--check]' 'Installs a tested prebuilt release, not your local source changes.' 'No Xcode, compiler, account, or paid service is required.'; exit 0 ;;
  ''|--check) ;;
  *) fail 'Unknown option. Use --help.' ;;
esac
[ "$(uname -s)" = Darwin ] || fail 'For Windows and Linux, download the installer from https://dictate-macos.vercel.app/download.'
OS_MAJOR=$(sw_vers -productVersion | cut -d . -f 1)
[ "$OS_MAJOR" -ge 14 ] || fail 'This Mac build requires macOS 14 or newer. No changes were made.'
[ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" = 1 ] || fail 'This native Mac release requires Apple silicon. Intel support is not yet published.'
printf '%s\n' "Dictate $VERSION — prebuilt community release (local source changes are not compiled)."
[ "${1:-}" != --check ] || { printf '%s\n' 'Compatible Apple-silicon Mac detected. No developer tools are needed.'; exit 0; }
INSTALL_ROOT=/Applications
if [ -d /Applications/Dictate.app ]; then
  [ -w /Applications ] || fail 'An existing Dictate is in Applications, but this account cannot update it. Ask its owner to update it to avoid duplicate copies.'
elif [ -d "$HOME/Applications/Dictate.app" ] || [ ! -w /Applications ]; then
  INSTALL_ROOT="$HOME/Applications"
fi
APP="$INSTALL_ROOT/Dictate.app"
if [ -f "$APP/Contents/Resources/release-version.txt" ] && [ "$(cat "$APP/Contents/Resources/release-version.txt")" = "$VERSION" ]; then
  codesign --verify --deep --strict "$APP" || fail 'The installed app signature is damaged. Download a fresh release.'
  printf '%s\n' "Opening the installed release at $APP"
  open "$APP"
  exit 0
fi
if pgrep -f '/Dictate.app/Contents/MacOS/Dictate' >/dev/null; then
  fail 'Quit Dictate from its menu before updating, then run this command again. Your history and models will be kept.'
fi
WORK=$(mktemp -d "${TMPDIR:-/tmp}/dictate-install.XXXXXX")
MOUNT="$WORK/mounted"
STAGED=''
cleanup() {
  if [ -d "$MOUNT" ]; then hdiutil detach "$MOUNT" >/dev/null 2>&1 || true; fi
  if [ -n "$STAGED" ] && [ -d "$STAGED" ]; then rm -rf "$STAGED"; fi
  rm -rf "$WORK"
}
trap cleanup EXIT HUP INT TERM
curl --fail --location --proto '=https' --proto-redir '=https' --retry 2 --connect-timeout 20 "$RELEASE_URL/manifest.json" -o "$WORK/manifest.json" || fail 'Release download is unavailable. Check the connection or your work network policy, then retry. No source build was attempted.'
EXPECTED=$(plutil -extract macArm64.sha256 raw -o - "$WORK/manifest.json")
MANIFEST_VERSION=$(plutil -extract version raw -o - "$WORK/manifest.json")
[ "$MANIFEST_VERSION" = "$VERSION" ] || fail 'The release manifest does not match the requested version.'
case "$EXPECTED" in *[!a-f0-9]*|'') fail 'Invalid release checksum.' ;; esac
[ "${#EXPECTED}" -eq 64 ] || fail 'Invalid release checksum length.'
curl --fail --location --proto '=https' --proto-redir '=https' --retry 2 --connect-timeout 20 "$RELEASE_URL/Dictate.dmg" -o "$WORK/Dictate.dmg" || fail 'The download did not finish. Retry when connected.'
ACTUAL=$(shasum -a 256 "$WORK/Dictate.dmg" | cut -d ' ' -f 1)
[ "$ACTUAL" = "$EXPECTED" ] || fail 'The download checksum does not match. The app was not installed; retry the download.'
mkdir "$MOUNT"
hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT" "$WORK/Dictate.dmg" >/dev/null
SOURCE="$MOUNT/Dictate.app"
[ -d "$SOURCE" ] && [ ! -L "$SOURCE" ] || fail 'The download does not contain a valid app bundle.'
codesign --verify --deep --strict "$SOURCE" || fail 'The app signature is damaged. No installation was made.'
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE/Contents/Info.plist")" = app.dictate.desktop ] || fail 'Unexpected application identity.'
[ "$(cat "$SOURCE/Contents/Resources/release-version.txt")" = "$VERSION" ] || fail 'Unexpected application version.'
mkdir -p "$INSTALL_ROOT"
STAGED=$(mktemp -d "$INSTALL_ROOT/.dictate-install.XXXXXX")
ditto "$SOURCE" "$STAGED/Dictate.app"
# Explicitly retain an Internet-download origin even when curl was the downloader.
# This never removes quarantine, bypasses Gatekeeper, or re-signs an artifact.
xattr -w com.apple.quarantine "0083;$(printf '%x' "$(date +%s)");DictateInstaller;" "$STAGED/Dictate.app"
codesign --verify --deep --strict "$STAGED/Dictate.app"
if [ -e "$APP" ]; then mv "$APP" "$STAGED/previous.app"; fi
if ! mv "$STAGED/Dictate.app" "$APP"; then
  if [ -d "$STAGED/previous.app" ]; then mv "$STAGED/previous.app" "$APP"; fi
  fail 'Installation failed; the previous app was restored.'
fi
printf '%s\n' "Installed $APP" 'This free community build is not notarized. If macOS cannot verify the developer, review it in System Settings → Privacy & Security → Open Anyway.' 'Microphone access and a local model are set up inside Dictate. Accessibility is optional for automatic insertion.'
open "$APP" || fail "macOS did not open $APP. Open it in Finder and review the exact warning in Privacy & Security."
