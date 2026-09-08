A free, open-source Mac and Windows community beta. No account, API key, paid service, or subscription.

New in beta 5:
- Redesigned Windows interface: Segoe UI typography, compact settings, themed switches, clearer setup and model management.
- Right Ctrl is the default Windows recording key. Record a custom key/combination or middle/back/forward mouse button in Settings. Hold-to-talk and press-to-toggle modes are available.
- NVIDIA Parakeet TDT v3 is now available on Windows alongside Whisper Tiny, Base, and Small. All run locally on CPU; no NVIDIA GPU, Python, or CUDA is required. Parakeet downloads about 670 MB; 8 GB RAM recommended. Tiny remains the 78 MB quick setup option.
- Windows installer includes the speech runtime and its C++ dependencies. No separate C++ installation is needed.
- Native Mac interface is unchanged. macOS 26 supported devices default to Apple Speech; older supported Macs use local models.

Install:
1. Quit an older Dictate instance before installing this beta.
2. Download the installer for your computer and open it.
3. On Windows, choose Set up speech model. Hold Right Ctrl in an editable field, speak, and release. Settings lets you change the shortcut and mode. Copy remains available when insertion is unavailable or disabled.

Compatibility: Mac Apple silicon, macOS 14+; Windows 10/11 x64. Linux support is paused. Windows Sandbox needs microphone input enabled; allow 8 GB memory when testing Parakeet, or start with Whisper Tiny.

Mac builds are ad-hoc signed and not Apple-notarized. Follow the illustrated Open Anyway guide at https://dictate-macos.vercel.app/download#mac.
Windows builds remain unsigned. Smart App Control may block the installer or app and has no per-app Run anyway exception. Do not disable Windows protection just to use this beta. SmartScreen's More info / Run anyway option, when available, does not override Smart App Control. See https://dictate-macos.vercel.app/download#windows.

Automated verification covers build, input-binding policy, actual offline Whisper/Parakeet inference on synthetic speech, installer runtime dependencies, and app startup. Browser UI checks use synthetic IPC; physical microphone, global input, and insertion tests on your Windows machine are still needed. This is a beta, not a claim of complete hardware coverage.
