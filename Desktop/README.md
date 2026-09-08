# Dictate portable desktop beta

Windows and Linux use Tauri 2, Rust, CPAL microphone capture, and CPU whisper.cpp
through whisper-rs. The existing native SwiftUI Mac app remains in `Sources/`.
Installers need no development tools. Use the [download page](https://dictate-macos.vercel.app/download).

## Development

Use Node 22+, Rust stable, CMake, and your platform's native toolchain. Windows
requires Visual Studio C++ Build Tools and WebView2; Linux needs the packages in
`.github/workflows/portable.yml`. Follow [Tauri prerequisites](https://v2.tauri.app/start/prerequisites/).
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
npm run tauri -- build --bundles deb,appimage # Linux
```

`core/` owns dictionary correction, compatible JSON documents, atomic persistence,
retention, resampling, and shortcut transitions. The native adapter owns audio,
model download/verification, permissions, global shortcuts, delivery, and recovery.
The renderer contains no remote code or cloud transcription client.

Models download only after a setup action. Tiny/base/small multilingual model
files are verified against pinned sizes and SHA-256 digests before loading.
Audio is held in memory, limited to ten minutes, and released after completion
or cancellation. Cancellation during inference prevents delivery and history.
A completed transcript is saved for recovery before external insertion.

Windows uses UI Automation focus checks and Unicode input. X11 uses AT-SPI
EditableText with X11 focus checks; selections and inaccessible targets fall
back to recovery. Neither automatic path overwrites the clipboard. Wayland
currently uses Record + Copy. The Mac Tauri build is a developer preview with
copy delivery; the supported Mac artifact is the native Swift app.

Data is local in the platform application-data directory for
`app.dictate.portable`: `%APPDATA%\app.dictate.portable` on Windows and
`$XDG_DATA_HOME/app.dictate.portable` (normally `~/.local/share/…`) on Linux.
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
