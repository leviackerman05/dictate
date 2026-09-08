# Windows beta 5 validation

This update redesigns the Windows interface, adds dedicated keyboard and mouse
shortcuts, and adds CPU NVIDIA Parakeet alongside Whisper. Native Mac UI code is
unchanged. Linux remains withdrawn. No paid services, signing, or API is used.

## Evidence boundaries

- User supplied screenshots prove beta 4 could start in their Windows Sandbox;
  they are the visual anti-reference, not beta 5 acceptance results.
- [UI captures and interaction results](ui/windows-beta5/ui-check.json) use
  Chromium on macOS with synthetic Tauri IPC. They cover all six destinations,
  setup, light/dark themes, 1120×750 and 760×560 content viewports, keyboard/chord
  capture, mouse presets, setting switches/radios, save-failure draft/focus
  retention, dictionary drafts, record and copy recovery.
- [Independent finish verdict](ui/windows-beta5/finish-verdict.md) scored all
  three requested corrections resolved. It is a browser/source UI verdict, not
  native Windows microphone, font-rasterization, hook, or insertion certification.
- Windows public CI runs the real CPU adapters against the repository's synthetic
  16 kHz speech fixture. It checks Whisper Tiny and Parakeet separately within
  the integration test, after verifying every downloaded component by SHA-256.
- The release gate extracts the NSIS installer, checks x64 binaries and normal/
  delayed C++ imports against its bundled DLLs, checks notices, and starts the
  extracted app for eight seconds. This is a startup check, not a microphone test.

## Packaging

The first candidate exposed an MSVC static/dynamic runtime mismatch in upstream
ONNX static binaries. It was not released. The final implementation isolates
ONNX in Microsoft's pinned CPU runtime DLL and bundles its app-local C++ DLLs
from the existing MSVC build tools. Rust and Whisper retain static runtime
linking. Users do not need a C++ redistributable installer, Python, CUDA, an
NVIDIA GPU, or developer tools. ONNX loads from an absolute packaged path;
its dependencies exclude the current working directory from DLL search.

Parakeet v3 uses the quantized ONNX conversion at revision
8f23f0c03c8761650bdb5b40aaf3e40d2c15f1ce, totaling 670,479,942 bytes. The original
NVIDIA weights and conversion are attributed under CC BY 4.0. Tiny remains the
78 MB quick setup choice. Parakeet recommends 8 GB RAM and checks cancellation
between at most 30-second chunks; word boundaries between chunks can lose context.

## Device acceptance still required

In Windows Sandbox, enable microphone input and allocate enough memory for the
chosen model. Quit beta 4 before installing beta 5. Test Right Ctrl hold/release
in Notepad; then test a custom chord, a mouse side button, and press-to-toggle.
Check that one transcript appears, the original clipboard survives insertion,
and disabling insertion leaves text ready to copy. Restart offline and repeat.
Physical keyboard/mouse and microphone results remain user tests.

This release remains unsigned. It does not remove Smart App Control restrictions.
The website explains that SAC has no per-app Run anyway exception.

## Reproduction

Build instructions are in [Desktop/README.md](../../Desktop/README.md).
`Desktop/tests/ui-smoke.cjs` (also available through the existing
`Desktop/scripts/check-ui.cjs` entry point) needs Playwright/Chromium and the
Desktop Vite server. `PLAYWRIGHT_MODULE`, `BROWSER_EXECUTABLE`, and
`DICTATE_PREVIEW_URL` allow local tool paths without adding production dependencies.
The workflow stages runtime DLLs, prepares checksum-verified speech models,
and invokes `recognition_smoke` through `Scripts/run-windows-test.ps1`.
