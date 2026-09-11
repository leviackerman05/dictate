# Dictate portable desktop beta

Windows uses Tauri 2, Rust, CPAL microphone capture, and CPU Whisper and NVIDIA Parakeet
through whisper-rs. The existing native SwiftUI Mac app remains in `Sources/`.
Installers need no development tools. Use the [download page](https://dictate-macos.vercel.app/download).

Linux support is paused. Linux packaging and desktop integrations have been
removed from the current source; older release assets are unsupported previews.

The unsigned Windows beta may be blocked by Smart App Control. It has no
per-app exception; see [installation limitations](../docs/INSTALLATION.md#windows-beta).

## Development

Use Node 22+, Rust stable, CMake, and your platform's native toolchain. Windows
requires Visual Studio C++ Build Tools and WebView2. Follow [Tauri prerequisites](https://v2.tauri.app/start/prerequisites/).
These are source-build prerequisites, not user installation steps.

```sh
cd Desktop
npm ci
npm run tauri -- dev
```

```sh
npm run build
cargo test --locked --manifest-path core/Cargo.toml
cargo check --locked --manifest-path src-tauri/Cargo.toml
npm run tauri -- build --bundles nsis       # Windows
```

`core/` owns dictionary correction, compatible JSON documents, atomic persistence,
retention, resampling, and shortcut transitions. The native adapter owns audio,
model download/verification, permissions, global shortcuts, delivery, and recovery.
The renderer contains no remote code or cloud transcription client.

Fresh installs start the Parakeet download automatically; cancel or choose a model in setup. Later downloads require a setup action. Whisper multilingual model
files are verified against pinned sizes and SHA-256 digests before loading.
Audio is held in memory, limited to ten minutes, and released after completion
or cancellation. Cancellation during inference prevents delivery and history.
A completed transcript is saved for recovery before external insertion.

Windows uses UI Automation focus checks and Unicode input, preserving the
clipboard. The Mac Tauri build is a developer preview with
copy delivery; the supported Mac artifact is the native Swift app.

Data is local in the platform application-data directory for
`app.dictate.portable`: `%APPDATA%\app.dictate.portable` on Windows.
`data.json` holds preferences, history, dictionary, and pending recovery;
`models/` holds downloaded models. Export dictionary/history from the UI.
Dictionary JSON schema 1 interoperates with Mac exports. Corrupt data causes a
startup error rather than being silently discarded or overwritten.

## Free release policy

Only public-repository standard GitHub runners are used. No CI caches or
Actions artifact storage, paid signing, APIs, services, or hosting upgrades.
The release workflow assembles installers on a draft GitHub release, then
publishes checksums and the manifest only after every platform build passes.
Hardware microphone, editor, and OS-version validation remains separate from
CI build success; record it in `docs/evidence/portability-validation.md`.

## Windows shortcuts and models (beta 5)

Right Ctrl is the default dedicated recording key. In Settings, click the
shortcut control and press a key or combination, or a middle/back/forward mouse
button; then Save changes. Hold to talk and press-to-toggle modes are available.
Escape cancels recording while the app is focused. The chosen trigger is reserved
while Dictate runs; left/right mouse clicks and Escape cannot be assigned.
Existing explicit shortcuts stay saved; the old default migrates once.

Whisper Tiny (78 MB), Base (148 MB), Small (488 MB), and NVIDIA Parakeet TDT v3
(670 MB) run locally on CPU. An NVIDIA GPU, Python, CUDA, account, or paid API is
not needed. Parakeet recommends 8 GB RAM; Windows Sandbox may need its memory
allocation raised to test it. Parakeet is the fresh-install default; Tiny remains an optional small download. Parakeet
supports 25 languages and uses pinned quantized ONNX components. Dictionary
corrections apply to both engines; vocabulary prompting applies to Whisper.
Parakeet processes audio in at most 30-second chunks to bound memory, so a word
at a chunk boundary may be less accurate; cancellation waits for the current
inference chunk to finish. No model is included in the installer.

Run `python Scripts/prepare-portable-smoke.py` from the repository root with
`DICTATE_SMOKE_DIR` set to a test directory, then run the opt-in
`recognition_smoke` Cargo test with `-- --ignored`. This downloads verified Tiny
Parakeet models and checks the real adapters against synthetic speech.

Whisper Medium and Large v3 Turbo are deferred: the current baseline CPU build is too slow for practical larger-model validation. The catalog retains Tiny, Base, Small and Parakeet. Store signing preparation is documented in `Release/windows-store/submission.md`.
