# Community beta validation — v1.1.0-beta.3

Recorded 2026-09-08. This is a testable community beta, not a certification of all
operating systems or editors. No money was spent on APIs, signing, CI runners,
Apple enrollment, or hosting upgrades. Standard public-repository GitHub runners
and the existing Vercel Hobby project are used; workflows do not upload Actions
artifacts or use caches that could consume billable storage.

The first draft candidate passed CI but its extracted Windows executable still
imported `MSVCP140.dll`. It was withdrawn before the website update. Beta 2 exposed a Rust/CMake runtime mismatch during linking and remained a
draft. Beta 3 selects the static runtime consistently in both build systems
and retains the extracted-package dependency gate. Release recognition smoke
tests use the release profile, matching the engine shipped in the installers.

## Checks performed

| Check | Evidence / result |
| --- | --- |
| Native Mac build | Swift 6.3.3 / SDK 26.5, host macOS 26.5.2 arm64; `swift build` passes with minimum deployment target 14.0 |
| Swift product rules | 61 existing XCTest tests and one shared portable dictionary fixture test pass |
| Native release package | `Scripts/release-preflight.sh` passes: DMG contents, bundle resources, version, arm64 architecture, Mach-O and Info.plist minimum OS 14.0, strict ad-hoc signature integrity |
| Gatekeeper | Rejects the community bundle, as expected without Apple notarization; this is disclosed, not treated as a trusted-signing pass |
| Repository launcher | Shell syntax and `--check` pass on this Apple-silicon Mac; script does not invoke Git, Xcode, Swift, or a compiler; release download/install test pending publication |
| Rust product rules | Eight tests pass: shared Mac dictionary fixture, Unicode/boundary/separator/nonrecursive correction, atomic JSON roundtrip, shortcut press/release transitions, resampling duration/silence and alias suppression |
| Portable native build | `cargo check` and local Tauri developer bundle pass; first Windows and Ubuntu CI native checks pass in run 34225914590; final release builds pending |
| Real recognition | Verified public Whisper Tiny model loaded locally; opt-in integration test recognized synthetic speech offline, without microphone use; logging hooks suppress upstream token logs |
| Portable interface | TypeScript/Vite build passes; browser mock-IPC test covers setup, navigation, dictionary add, draft preservation, failed settings save, theme, search caret, recording controls and recovery. Synthetic data only |
| Website | Astro build/check pass (zero diagnostics); platform source-link/version checks; desktop 1440 px and mobile 390 px screenshot review in light/dark |
| UI review | Independent scoped review preserved incumbent design. All listed form-draft, keyboard-focus and onboarding-navigation corrections confirmed resolved; scoped UI verdict: ship |

Screenshots under `ui/portability/` are browser-rendered UI evidence. Portable
screens use a mocked native bridge and synthetic text. They do **not** prove
real microphone capture, OS dialogs, global shortcuts or editor insertion.
The attempted native preview inspection could not proceed because the host Mac
was locked; no unlock/security bypass was attempted.

## What still needs a person's machine

- Owner's personal and work Macs: both reported as macOS 26; chip unspecified.
  Fresh browser download, Gatekeeper decision, microphone/Accessibility, first
  model setup, restart offline, and real editor tests remain unperformed.
- Older macOS 14/15: compiled deployment compatibility is verified; launch and
  recognition on those OS versions remain untested.
- Windows 10/11: native compilation and installer construction are automated;
  physical microphone, permission/SmartScreen prompts, WebView2 installation,
  global shortcut, clipboard preservation and insertion remain device tests.
- Linux X11 and Wayland: compilation is automated; distribution installation,
  audio-device changes, tray support and AT-SPI insertion need real desktops.
  Wayland deliberately supports Record + Copy only in this beta.
- Intel Macs, Windows ARM and Linux ARM are not published targets.
- A managed work computer may disallow unsigned/unnotarized software. A free
  community release cannot remove that administrative restriction.

## Short acceptance test (Mac and Windows)

1. Download from the website, install and open. Do this without installing any
   developer tools. Record the OS/chip, exact installer version and any warning.
2. Allow microphone access, set up the recommended model, and dictate “This is
   a local dictation test.” Confirm a usable transcript appears.
3. Quit, disconnect from the network, reopen and repeat. Confirm no new download
   is required. Reconnect afterward.
4. Put the cursor in TextEdit/Notepad, use the configured shortcut, then finish.
   Confirm one insertion and that your previous clipboard content is retained.
5. Try an inaccessible editor or disable insertion. Confirm the transcript
   remains available to copy. Inspect any uncertain paste before retrying.
6. Cancel one recording and one model download. Confirm no canceled transcript
   is delivered and setup can be retried. Add a dictionary correction, restart,
   and confirm it and any saved history remain.

For Linux Wayland, use the Record button and Copy instead of step 4. For a work
computer, follow administrator policy rather than bypassing it. Report the
exact warning/error and platform; do not send private recordings or history.

## Reproduce developer checks

`swift test`, `make preflight`, `cargo test --locked --manifest-path
Desktop/core/Cargo.toml`, `npm run build --prefix Desktop`, and
`npm run check --prefix Website` are the main checks. The optional native
recognition test requires a separately downloaded verified tiny model and a
synthetic 16 kHz f32 sample; see `Desktop/src-tauri/tests/recognition_smoke.rs`.
`Desktop/scripts/check-ui.cjs` uses Playwright/Chrome, the Website production
preview at 127.0.0.1:4325, and the Desktop Vite server at 127.0.0.1:1420.
