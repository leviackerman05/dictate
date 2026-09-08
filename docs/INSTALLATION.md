# Installing Dictate

Use the [download page](https://dictate-macos.vercel.app/download) to choose an
installer. These community builds are free and use local speech recognition.
No Xcode, Rust, Node, Python, Git, account, or paid API is needed to use them.
Initial model setup requires an internet connection; dictation then works offline.

## Mac: install, open, set up

Requires Apple silicon and macOS 14+. Intel installers are not published. This
beta compiles for macOS 14; older-OS runtime testing remains pending.

1. Open `Dictate.dmg` and drag Dictate to **Applications**.
2. Open **Dictate** from Applications or Spotlight.
3. Allow microphone access and click **Set up recommended model**. Grant
   Accessibility only if you want automatic insertion into other apps.

On supported macOS 26 devices, Apple recognition uses an OS-managed asset.
Older macOS uses a downloadable local model. Setup shows progress, supports
cancel/retry, and does not silently download a different model on launch.

The community app is ad-hoc signed, not Developer ID signed or notarized. For
an **unverified developer / cannot verify** warning from a trusted download,
first attempt to open it, then use **System Settings → Privacy & Security →
Open Anyway** and confirm. Recent macOS versions no longer offer the old
Control-click override. [Apple's guide](https://support.apple.com/en-us/102445).

An explicit malware, revoked-signature, or damaged-app warning is different:
stop and check the release and checksum. Do not disable Gatekeeper or remove
quarantine. Work administrators may prohibit unnotarized apps; this project
cannot override that policy for free or otherwise.

Applications is the expected installed location. `build/Dictate.app` exists
only after building source. For troubleshooting, use Finder or
`open /Applications/Dictate.app` (or `open ~/Applications/Dictate.app` for a
per-user installation).

### Optional repository launcher

After cloning or extracting a repository ZIP, run:

```sh
./Scripts/start.sh
```

`./Scripts/start.sh --check` only checks OS/architecture. The launcher installs
the release pinned in `Release/version.txt`, verifies its SHA-256 manifest and
bundle signature, preserves download quarantine, and opens the exact installed
path. Quit Dictate before updating. History, preferences, and models stay in
Application Support. It does not compile your edits. A cloned repository still
needs Git to clone; downloading its ZIP does not.

## Windows beta

1. Run `Dictate-Windows-x64-setup.exe` on Windows 10/11 x64.
2. Open Dictate and set up Whisper Tiny (about 78 MB).
3. Start recording, allow the microphone if prompted, then finish. Use the
   global shortcut in a destination editor or copy the result from Dictate.

The per-user installer needs no compiler. It can install Microsoft's free
WebView2 runtime when missing. It is unsigned: Windows may display an
unknown-publisher/SmartScreen warning. Proceed only for a trusted download and
according to your organization's policy; do not bypass malware detections.

Automatic insertion uses Windows accessibility to validate the current editor,
then sends Unicode text without changing your clipboard. Elevated, password,
and inaccessible fields keep the transcript ready to copy. If confirmation is
uncertain, inspect the destination before retrying to avoid duplicate text.

## Linux beta

1. Open `Dictate-Linux-x64.deb` with your distribution's software installer, or
   mark the AppImage executable in file properties and open it.
2. Set up the recommended local model.
3. Click Record, speak, finish, then copy the completed words.

The .deb targets Ubuntu 22.04+ and compatible systems; the package manager
installs WebKitGTK 4.1, ALSA, and AppIndicator libraries. If FUSE is unavailable,
run `./Dictate-Linux-x64.AppImage --appimage-extract-and-run`.

X11 supports global shortcuts and attempts AT-SPI insertion into an accessible
focused editor with no selected text. Wayland uses **Record + Copy** in this
beta; global shortcut and insertion portals are not implemented. Tray support
varies by desktop; launching Dictate again brings its existing window forward.

Windows/Linux are an initial beta, not a claim of parity with every Mac editor.
Read the [validation record](evidence/portability-validation.md) before testing.

## Verify a download (optional)

Download the artifact and its matching `.sha256` from the same release. On Mac
or Linux run `shasum -a 256 -c Dictate.dmg.sha256` (substitute the Linux filename).
On Windows use `Get-FileHash .\Dictate-Windows-x64-setup.exe -Algorithm SHA256`
and compare it with the release's checksum. `manifest.json` also records all
file sizes and hashes. A matching checksum confirms integrity, not notarization.

## Build the native Mac app from source

Install full Xcode with the macOS 26 SDK, then run:

```sh
swift test
make app
open build/Dictate.app
```

The bundle identifier defaults to `app.dictate.desktop`. Isolate a developer
build with `DICTATE_BUNDLE_IDENTIFIER=com.example.dictate make app`.

`make preflight` validates architecture, minimum OS, resources, usage strings,
signature integrity and DMG contents. It reports actual Gatekeeper rejection for
an unnotarized community build; passing packaging checks is not Apple approval.
