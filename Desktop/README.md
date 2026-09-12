# Dictate for Windows

The Windows app uses Tauri 2, Rust, and a TypeScript interface. Speech runs locally
through Whisper and NVIDIA Parakeet. The native Swift Mac app lives in `Sources/`.

- [Install or build from source](../README.md)
- [Tests and recognition benchmarks](../docs/DEVELOPMENT.md#windows)
- [Installer troubleshooting](../docs/INSTALLATION.md#windows-beta)

## Development

After installing the prerequisites in the main README, run from `Desktop`:

```powershell
npm ci
npm run tauri -- dev
```

To create the Windows installer:

```powershell
npm run tauri -- build --bundles nsis
```

Output: `src-tauri/target/release/bundle/nsis/`. Both commands automatically stage
the checksum-verified ONNX Runtime and app-local Microsoft C++ DLLs.

If Whisper's build cannot find `libclang.dll`, set `LIBCLANG_PATH` to the LLVM
`bin` directory containing that file, then retry. If runtime staging reports a
missing MSVC redistributable, install the **MSVC v143 x64/x86 build tools**
component through Visual Studio Installer.

## Shortcuts and models

Hold **Right Ctrl** to record and release to finish. Choose another key,
combination, or middle/side mouse button in **Settings → Recording shortcut**;
changes save automatically. Hold and toggle modes are available. Quit Dictate
from its tray menu; closing the window only hides it.

| Local model | Download |
| --- | --- |
| NVIDIA Parakeet TDT v3 (default) | 670 MB |
| Whisper Tiny | 78 MB |
| Whisper Base | 148 MB |
| Whisper Small | 488 MB |

Fresh setup downloads Parakeet automatically; cancel or choose another model in
Setup options. Parakeet recommends 8 GB RAM and needs no NVIDIA GPU or CUDA.
Downloads are verified before loading. Larger Whisper models are deferred
pending practical CPU acceleration and completed validation.

Parakeet processes audio in chunks of up to 30 seconds to bound memory;
cancellation waits for the current inference chunk. Dictionary corrections
apply to both engines; vocabulary prompting applies to Whisper.

## Local data and runtime

`%APPDATA%\app.dictate.portable` contains `data.json` (preferences, history,
dictionary, and recovery) and `models/` (downloaded models). Export history or
dictionary from the UI. Dictionary JSON schema 1 interoperates with Mac exports.
Corrupt data produces a startup error instead of silently discarding it.

Audio stays in memory during recording, which is limited to ten minutes. A
completed transcript is saved for recovery before insertion. Windows uses UI
Automation checks and Unicode input without replacing the clipboard; unsupported
or protected fields leave text ready to copy.

`core/` owns dictionary correction, persistence, resampling, and shortcut state.
`src-tauri/` owns native capture, model loading, permissions, and delivery.
`src/` contains the interface, with no cloud transcription client.

The GitHub installer remains unsigned. [Microsoft Store/MSIX preparation](../Release/windows-store/submission.md)
is separate from local development.
