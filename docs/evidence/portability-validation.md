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

Published [community beta](https://github.com/leviackerman05/dictate/releases/tag/v1.1.0-beta.3) from immutable tag `v1.1.0-beta.3` (`1cc2474`).
[Release run 34232054290](https://github.com/leviackerman05/dictate/actions/runs/34232054290) passed all Mac, Windows, Linux and publication jobs.

## Checks performed

| Check | Evidence / result |
| --- | --- |
| Native Mac build | Swift 6.3.3 / SDK 26.5, host macOS 26.5.2 arm64; `swift build` passes with minimum deployment target 14.0 |
| Swift product rules | 61 existing XCTest tests and one shared portable dictionary fixture test pass |
| Native release package | `Scripts/release-preflight.sh` passes: DMG contents, bundle resources, version, arm64 architecture, Mach-O and Info.plist minimum OS 14.0, strict ad-hoc signature integrity |
| Published artifact integrity | All four downloaded installers match both manifest SHA-256/byte counts and checksum sidecars. Downloaded Mac bundle has build 11003, minimum OS 14.0, strict signature integrity and no Xcode/developer library paths |
| Windows runtime packaging | Actual published NSIS payload inspected independently and in CI: x64 executable and license notices present; no external MSVCP/VCRUNTIME/CONCRT DLL imports. Windows system/UCRT libraries remain OS dependencies |
| Linux package metadata | Published DEB contains the amd64 ELF executable, beta.3 version, notices, and audio/WebKitGTK/tray runtime dependencies |
| Gatekeeper | Rejects the community bundle, as expected without Apple notarization; this is disclosed, not treated as a trusted-signing pass |
| Repository launcher | Shell syntax and `--check` pass on this Apple-silicon Mac; script does not invoke Git, Xcode, Swift, or a compiler; live download, manifest/hash validation, signature verification and app replacement pass on this Mac for both /Applications and ~/Applications; quarantine warning observed; clean-machine launch and user-approved exception remain acceptance tests |
| Rust product rules | Eight tests pass: shared Mac dictionary fixture, Unicode/boundary/separator/nonrecursive correction, atomic JSON roundtrip, shortcut press/release transitions, resampling duration/silence and alias suppression |
| Portable native build | `cargo check` and local Tauri developer bundle pass; final Windows and Ubuntu release-profile native checks, recognition smoke tests and installer builds pass in run 34232054290 |
| Real recognition | Verified public Whisper Tiny model loaded locally; opt-in integration test recognized synthetic speech offline, without microphone use; logging hooks suppress upstream token logs. Final Linux and Windows release-profile integration tests pass (18.05 s and 84.52 s total test time respectively on shared CI runners; these are not microphone latency benchmarks) |
| Portable interface | TypeScript/Vite build passes; browser mock-IPC test covers setup, navigation, dictionary add, draft preservation, failed settings save, theme, search caret, recording controls and recovery. Synthetic data only |
| Website | Astro build/check pass (zero diagnostics); all five public download/manifest URLs pass HEAD checks; desktop 1440 px and mobile 390 px screenshot review in light/dark |
| UI review | Independent scoped review preserved incumbent design. All listed form-draft, keyboard-focus and onboarding-navigation corrections confirmed resolved; scoped UI verdict: ship |

Screenshots under `ui/portability/` are browser-rendered UI evidence. Portable
screens use a mocked native bridge and synthetic text. They do **not** prove
real microphone capture, OS dialogs, global shortcuts or editor insertion.
The initial native preview inspection was blocked while the Mac was locked.
After the owner returned and authorized restarting Dictate, the portable Mac
preview rendered its onboarding in the native webview. The exact published
native Mac beta then launched, preserved the existing data and Parakeet choice,
and reached the ready state using the cached model. Model-management UI was
visually inspected. No screenshots containing private history were published.
This checks an existing macOS 26.5.2 installation, not a clean machine. The
repository installer subsequently updated the existing app and retained the
Internet quarantine attribute. macOS displayed its unnotarized-app warning.
After the system Applications copy was no longer present, rerunning the same
launcher updated the existing home Applications copy to build 11003. User
approval of the app-specific exception is still pending; no quarantine removal
or Gatekeeper bypass was used.

The published Mac executable also recognized the repository synthetic fixture
using cached Parakeet: 3.7949 seconds of audio, 0.0915 seconds of transcription,
normalized word error rate 0. See [the local benchmark](mac-beta3-parakeet-smoke.md).
No microphone, private audio, or model download was involved.

The updated static website was deployed to the existing Vercel Hobby project
(`dpl_2jEiCfMkavSe47JMtUQJ2wZhASiB`). Live `/` and `/download` both return HTTP
200; all four installer links and the manifest point to beta.3. Build-time npm
audit still reports Astro/sharp/esbuild advisories. This deployment serves
static HTML/CSS/JS, without SSR, server islands, dynamic user-supplied slots or
attributes, or image uploads. The toolchain advisories were inspected; this
release does not claim a vulnerability-free dependency tree.

## What still needs a person's machine

- Owner's personal and work Macs: both reported as macOS 26. The current Mac
  is verified as Apple M2; the other chip is unconfirmed. Existing-data launch,
  cached Parakeet warmup and synthetic recognition pass here. Fresh browser
  download, Gatekeeper exception, microphone/Accessibility, first model setup,
  restart with networking disabled and real editor tests remain unperformed.
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
