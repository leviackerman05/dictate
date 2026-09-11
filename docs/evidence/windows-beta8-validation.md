# Beta 8 validation

Scope: Mac model onboarding, Windows model defaults/catalog and recorder polish; Store packaging preparation. The Mac transcript cleanup experiment remains uncommitted and excluded from the release.

Local checks on 2026-09-11:
- Release Swift suite: passed (core tests and shared portability fixture).
- Windows renderer TypeScript/Vite production build: passed.
- Rust portable core: 11 tests passed.
- Chromium UI with synthetic Tauri IPC: light/dark screens, 760 px minimum width, onboarding, settings persistence, ready-indicator toggle and 32 × 16 geometry, active audio level response, recording/recovery and existing navigation flows passed without page errors or horizontal overflow. This is not a native Windows microphone or insertion test.
- Expanded Windows CI exercises the raw-RMS meter and old/new preference deserialization, then loads Whisper Tiny, Parakeet, Medium and Large v3 Turbo and recognizes synthetic audio through the actual native adapters. Release publication requires that workflow and packaging checks to succeed.

Model metadata: Whisper files and SHA-256 values were retrieved from the official `ggerganov/whisper.cpp` Hugging Face repository at pinned revision `5359861c739e955e79d9a303bcbc70fb988958b1`. Existing Parakeet uses pinned ONNX artifacts; the Mac FluidAudio/CoreML variants are intentionally excluded from Windows.

Existing Windows model choices are preserved. Older data has no selection provenance, so it is unsafe to migrate a saved Tiny choice based solely on its name. Only a missing data archive triggers the new automatic initial Parakeet download; cancellation/failure does not silently retry on every launch.

Store signing is not complete. The MSIX script and listing/checklist require owner-provided Partner Center identity and a verified official Fixed Version WebView2 runtime. Native packaged-app, WACK and Smart App Control acceptance remain pending certification. The GitHub EXE remains unsigned.
