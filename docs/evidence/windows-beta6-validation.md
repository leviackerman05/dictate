# Windows beta 6 parity and insertion validation

Date: September 11, 2026

## Scope

Beta 6 aligns the Windows Tauri renderer with the live native Mac app across
Dashboard, History, Dictionary, Statistics, AI models, Settings, and onboarding.
It also broadens Windows cursor insertion for editors that expose custom
accessibility controls. Linux distribution remains paused.

## Renderer evidence

`ui/windows-beta6/` contains 24 screenshots and `ui-check.json` from the Chromium
renderer harness at 1120×750 and 760×560. The harness uses synthetic Tauri IPC on
macOS, so it proves frontend layout and behavior rather than native Windows
integration.

The successful pass covered:

- all six destinations in light and dark appearance;
- General, Audio, and Permissions settings;
- immediate System/Light/Dark, history, insertion, recording-mode, and shortcut persistence;
- onboarding at full and minimum window sizes;
- single modifier, key combination, and mouse-button shortcut capture;
- Parakeet and Whisper model selection;
- dictionary draft preservation and save;
- failed settings save recovery and focus;
- record/finish/recovery/copy behavior; and
- the 62×22 action-free recorder pebble in listening and processing states; and
- absence of document-level horizontal or vertical overflow at the captured sizes.

The production renderer passed `npm run build`. The shared Rust core passed all 11
tests with the locked dependency graph.

## Insertion change

The Windows delivery adapter still requires an externally focused UI Automation
element, rejects password fields, records the foreground window, and aborts if
focus changes before delivery. It accepts Edit, Document, and Custom controls without
requiring readable Value/Text patterns, because modern Notepad tabs, browsers,
Electron apps, and Office-style editors commonly omit those patterns. Delivery uses
Unicode keyboard input and does not replace clipboard contents. Any failure leaves
the transcript in Dictate for copy or retry.

## Native verification boundary

The complete Tauri package cannot be compiled on this Mac without CMake; the local
attempt reached `whisper-rs-sys` and stopped at that missing build tool. The macOS
release preflight passed and produced an arm64, macOS 14+ ad-hoc-signed DMG. The
release workflow on `windows-latest` is the authoritative native Windows check: it
compiles the Windows target, runs locked shared-core tests, performs real offline
Whisper and Parakeet inference on synthetic audio, builds the NSIS installer, and
inspects its runtime dependencies.

The first beta 6 branch run compiled the renderer and shared core, then reported a
Whisper encoder failure on the constrained runner before the native Tauri check.
Whisper now caps CPU inference at four workers, and CI compiles the complete Windows
target before running the longer recognition smoke.

Physical-device acceptance remains required for microphone capture, the global
shortcut, insertion into Notepad and another editor, installer launch, SmartScreen
or Smart App Control policy, and native Segoe rendering. The unsigned installer
does not bypass Smart App Control.

## Cost and privacy

No paid API, hosted transcription, account, subscription, signing service, or paid
infrastructure was added. Recognition remains local after the explicit free model
download.
