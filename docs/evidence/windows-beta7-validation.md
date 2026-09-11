# Windows beta 7 validation

This record covers the beta 7 shortcut, recorder, privacy, brand, and chart changes. It does not claim Microsoft signing or Smart App Control approval.

## Automated checks

- TypeScript type checking and the production Vite renderer build pass.
- The shared Rust core has 11 passing tests, including hold-to-talk release during preparation and click-to-toggle repeat handling.
- The Tauri native crate passes `cargo check --locked` with the scoped system URL opener permission.
- The native Mac package has 63 passing XCTest cases plus the shared portable dictionary fixture.
- The website passes Astro diagnostics, platform detection tests, source link checks, and a static production build containing `/privacy`.
- The Mac release preflight produces an ad-hoc signed Apple-silicon DMG with macOS 14 as its deployment target and the expected Gatekeeper rejection for an unnotarized community build.

## Renderer interaction and visual checks

The Chromium integration harness uses synthetic Tauri IPC to exercise both light and dark themes at 1120 × 750 and the minimum 760 × 560 window. It verifies:

- all six destinations and onboarding render without horizontal or document overflow;
- the exact shared Dictate app mark is used inside the Windows app;
- Dashboard and Statistics chart values are exposed on hover and keyboard focus;
- recording changes to the red active button with a filled stop mark;
- Privacy invokes the Tauri system URL opener;
- Right Ctrl, a custom chord, F8, and a mouse-side-button shortcut can be assigned and save immediately;
- recording-mode, appearance, insertion, and history preferences save immediately and recover from a synthetic failed save;
- Parakeet selection, dictionary editing, transcript recovery, and recovery copy complete;
- the 62 × 22 recorder pebble has no action buttons and renders its listening bars and processing dots inside a 108 × 52 transparent shadow host.

Screenshots and the machine-readable result are in [`docs/evidence/ui/windows-beta7`](ui/windows-beta7).

## Native Windows release gate

The public release workflow runs on `windows-latest`. It installs from the lockfile, tests the shared core, stages the app-local ONNX runtime, runs real Whisper and Parakeet recognition against synthetic speech without a microphone, builds the NSIS installer, and checks its runtime dependencies before publication.

Physical microphone input, low-level keyboard and mouse hooks, insertion into the user's specific editors, Windows Sandbox work-area positioning, and Microsoft security-policy behavior still require acceptance testing on a Windows machine. Smart App Control can block an unsigned build without offering a per-app exception.
