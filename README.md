<p align="center">
  <img src="Sources/Dictate/Resources/AppIcon.svg" width="104" height="104" alt="Dictate app icon">
</p>

<h1 align="center">Dictate</h1>

<p align="center">Hold a key. Say what you mean. Release and keep writing.</p>

<p align="center">
  <a href="https://dictate-macos.vercel.app/download">Download for Mac or Windows</a> ·
  <a href="https://dictate-macos.vercel.app">Website</a> ·
  <a href="https://github.com/leviackerman05/dictate/releases">Releases</a>
</p>

<p align="center">
  <img src="docs/evidence/ui/dictate-dashboard.png" width="1100" alt="Dictate dashboard in dark mode">
</p>

Dictate is free, open-source dictation for Mac and Windows. Hold your shortcut,
speak, and release to insert text into the app you're using. If insertion isn't
available, your transcript stays ready to copy.

Speech recognition runs on your computer. No Dictate account, subscription,
cloud transcription, or telemetry. Initial model setup needs internet; dictation
then works offline. Raw microphone audio is not saved to disk.

## Install

Download the installer for your computer from the [download page](https://dictate-macos.vercel.app/download).
No developer tools are needed.

| Platform | Requirements | Installation |
| --- | --- | --- |
| Mac | Apple silicon (M-series), macOS 14+ | Open `Dictate.dmg`, drag Dictate to Applications, then open it. |
| Windows | Windows 10/11, x64 | Run `Dictate-Windows-x64-setup.exe`, then open Dictate. |

The Mac build does not support Intel Macs. Linux support is paused.

**Mac:** Allow microphone access; enable Accessibility if you want automatic
text insertion. Fresh supported macOS 26 setups default to Apple Speech.
Other supported macOS versions use a downloadable local model. Onboarding also
offers NVIDIA Parakeet.

**Windows:** First launch downloads NVIDIA Parakeet (670 MB); cancel or choose
another model in Setup options. No NVIDIA GPU is needed; 8 GB RAM is recommended.
The installer provides the speech runtime and installs WebView2 if missing.

Community Mac builds are not notarized, and Windows installers are unsigned.
See the [installation guide](docs/INSTALLATION.md) for Mac's Open Anyway step,
Windows Smart App Control limitations, and checksum verification.

## Use

1. Choose your recording shortcut in Settings. Windows defaults to **Right Ctrl**.
2. Focus a text field, hold the shortcut, speak, and release. Toggle mode is also available.
3. Find past transcripts in History and add names or preferred corrections in Dictionary.

## Build locally

Install [Git](https://git-scm.com/downloads), then clone the repository:

```sh
git clone https://github.com/leviackerman05/dictate.git
cd dictate
```

### Mac

Use an Apple silicon Mac with **full Xcode 26**, Swift 6.2+, and the macOS 26 SDK.
Open Xcode once to finish setup and select it under **Settings → Locations →
Command Line Tools**. Command Line Tools alone are insufficient.

From the repository root:

```sh
make app
open build/Dictate.app
```

The app is built at `build/Dictate.app`. Drag it to Applications if you want to
install it. Quit another running copy of Dictate before opening your build.

### Windows

Build on Windows x64 with:

- [Node.js](https://nodejs.org/) 22+ and [Rust](https://rustup.rs/) stable using the `x86_64-pc-windows-msvc` toolchain.
- Visual Studio **2022 Build Tools**, with **Desktop development with C++**, MSVC v143, and a Windows SDK.
- [CMake](https://cmake.org/download/) and [LLVM/Clang](https://rust-lang.github.io/rust-bindgen/requirements.html#windows), available on PATH. Whisper's bindings need `libclang.dll`.
- Microsoft Edge WebView2 Runtime, if missing. See [Tauri's Windows prerequisites](https://v2.tauri.app/start/prerequisites/#windows).

Open a new PowerShell window after installing these tools. From the repository root:

```powershell
cd Desktop
npm ci
npm run tauri -- build --bundles nsis
```

Run the generated installer in `Desktop/src-tauri/target/release/bundle/nsis/`.
The build command automatically prepares the verified speech-runtime DLLs and
builds the interface. For development with live reload, use `npm run tauri -- dev`
from `Desktop` instead.

For optional tests, packaging checks, and recognition benchmarks, see the
[developer guide](docs/DEVELOPMENT.md). [Windows technical notes](Desktop/README.md)
cover models, local data, and runtime troubleshooting.

## Project

- [Privacy policy](PRIVACY.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Design system](docs/DESIGN_SYSTEM.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)
- [Report an issue](https://github.com/leviackerman05/dictate/issues) — include your OS version and the app you were dictating into.

## License

[MIT](LICENSE).
