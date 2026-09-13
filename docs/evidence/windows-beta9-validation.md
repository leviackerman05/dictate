# Windows beta 9 validation

Scope: Windows typography, large-display layout, history and dictionary motion, AI model alignment, recorder waveform, and floating recovery actions. Microsoft Store signing remains pending.

## Local checks

- TypeScript type checking and the Vite production build pass.
- The native Tauri crate passes formatting and all available tests: four unit tests and one integration test pass; the model-fixture smoke test is intentionally ignored locally because verified model files are supplied by Windows CI.
- The Chromium integration harness passes without page errors or horizontal overflow in light and dark themes at 1120 × 750 and at the 760 × 560 minimum window.
- A 2560 × 1440 run confirms the main content shell expands beyond 1600 px and centers on the available desktop area.
- Model status columns share the same x-coordinate for Ready and Not installed rows.
- History disclosure state updates without a page rebuild, exposes its actions through ARIA only while expanded, and collapses correctly.
- The dictionary editor preserves a draft through state refresh; its compact Cancel target remains at most 26 px high.
- At synthetic RMS 0.04, the rounded recorder bars exceed a 0.7 vertical scale. The failure-recovery pebble exposes Copy and Dismiss; Copy clears durable recovery through the same command as the main window.

Screenshots and the machine-readable result are in [`docs/evidence/ui/windows-beta9`](ui/windows-beta9).

## Release gate

The public Windows workflow builds on `windows-latest`. It installs locked dependencies, tests the shared core, validates Store-script syntax, stages the app-local ONNX runtime, runs native unit tests, recognizes verified synthetic speech with Whisper and NVIDIA Parakeet, builds the NSIS installer, and inspects its runtime dependencies. Publication occurs only after the Mac and Windows release jobs pass.

Physical-device microphone input, global keyboard and mouse hooks, insertion into the user's editors, native floating-overlay clicking, 1440p display scaling, and Microsoft security-policy behavior still require acceptance testing on Windows. The GitHub installer remains unsigned; Microsoft Store certification is the planned free signing route.
