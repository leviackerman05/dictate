# Beta 8 validation

Scope: Mac model onboarding, Windows model defaults/catalog and recorder polish; Store packaging preparation. The Mac transcript cleanup experiment remains uncommitted and excluded from the release.

Local checks on 2026-09-11:
- Release Swift suite: passed (core tests and shared portability fixture).
- Windows renderer TypeScript/Vite production build: passed.
- Rust portable core: 11 tests passed.
- Chromium UI with synthetic Tauri IPC: light/dark screens, 760 px minimum width, onboarding, settings persistence, ready-indicator toggle and 32 × 16 geometry, active audio level response, recording/recovery and existing navigation flows passed without page errors or horizontal overflow. This is not a native Windows microphone or insertion test.
- Expanded Windows CI exercises the raw-RMS meter and old/new preference deserialization, then loads Whisper Tiny and Parakeet and recognizes synthetic audio through the actual native adapters. Release publication requires that workflow and packaging checks to succeed.

Model metadata: Whisper files and SHA-256 values were retrieved from the official `ggerganov/whisper.cpp` Hugging Face repository at pinned revision `5359861c739e955e79d9a303bcbc70fb988958b1`. Existing Parakeet uses pinned ONNX artifacts; the Mac FluidAudio/CoreML variants are intentionally excluded from Windows.

Existing Windows model choices are preserved. Older data has no selection provenance, so it is unsafe to migrate a saved Tiny choice based solely on its name. Only a missing data archive triggers the new automatic initial Parakeet download; cancellation/failure does not silently retry on every launch.

Store signing is not complete. The MSIX script and listing/checklist require owner-provided Partner Center identity and a verified official Fixed Version WebView2 runtime. Native packaged-app, WACK and Smart App Control acceptance remain pending certification. The GitHub EXE remains unsigned.

## Windows CI follow-up

The first recognition run exposed an incorrect pointer cast in whisper-rs 0.16.0's safe cancellation closure adapter (upstream `whisper_params.rs:639–646`). Dictate now passes a borrowed AtomicBool directly through the native callback API, keeps its Arc alive through synchronous inference, and handles actual cancellation as an empty result. A callback test checks false/true/reset reads across a worker thread. The model smoke test reports the model ID and elapsed time; CI uses release inference to avoid an extra debug native build. The failed run did not publish beta 8.

## Larger model decision

Candidate run [34626772079](https://github.com/leviackerman05/dictate/actions/runs/34626772079) passed all four native unit tests and both existing engine smoke checks after the cancellation fix. Tiny took 130.20 seconds and Parakeet 3.42 seconds including verified loading and recognition on the synthetic fixture. Medium remained in inference for several minutes when the draft run was cancelled; no completed Medium or Turbo inference result is claimed. The baseline x64 build intentionally disables optional CPU instructions for compatibility. Medium and Turbo are withheld from the final catalog pending practical acceleration and complete inference validation. Existing Tiny/Base/Small remain for compatibility; fresh installations default to Parakeet.

The research identified official Medium (1,533,763,059 bytes, SHA-256 `6c14d5adee5f86394037b4e4e8b59f1673b6cee10e3cf0b11bbdbee79c156208`) and Turbo (1,624,555,275 bytes, SHA-256 `1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69`) artifacts at the pinned Whisper revision. Metadata verification alone is not runtime acceptance. Neither cancelled draft was published.
