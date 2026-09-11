A free, open-source Mac and Windows community beta. No account, API key, paid service, or subscription.

New in beta 6:
- Windows now follows the native Mac Dictate interface across Dashboard, History, Dictionary, Statistics, AI models, Settings, and onboarding. The shared light/dark palette, navigation, cards, editorial headings, and local-first status language are aligned while Windows controls and model availability remain accurate.
- Settings now has General, Audio, and Permissions tabs plus System, Light, and Dark appearance choices. Changes save immediately, as they do on Mac, with no separate Save button.
- The Windows recorder overlay now matches Mac's compact signal pebble: nine listening bars, three processing dots, and no copy or action buttons. Delivery recovery stays in the main app.
- Windows cursor insertion now accepts focused custom editors used by modern Notepad, browsers, Electron apps, and Office-style apps. It sends Unicode text without replacing clipboard contents, still refuses password fields, and keeps failed transcripts ready to copy or retry.
- Week, Month, and Year statistics ranges are functional. Dictionary import/export, model management, history actions, custom shortcuts, and onboarding options remain available.
- Right Ctrl remains the default Windows recording key. You can record a custom key/combination or middle/back/forward mouse button and choose hold-to-talk or press-to-toggle.
- Windows includes NVIDIA Parakeet TDT v3 and Whisper Tiny, Base, and Small. All run locally on CPU; no NVIDIA GPU, Python, CUDA, account, or paid service is required.
- The native Mac interface and macOS 26 Apple Speech default are unchanged.

Install:
1. Quit an older Dictate instance before installing this beta.
2. Download the installer for your computer and open it.
3. On Windows, choose Set up speech model. Focus an editable field, hold Right Ctrl, speak, and release. Use History or the recovery card if an editor refuses insertion.

Compatibility: Mac Apple silicon, macOS 14+; Windows 10/11 x64. Linux support is paused. Windows Sandbox needs microphone input enabled; allow 8 GB memory when testing Parakeet, or start with Whisper Tiny.

Mac builds are ad-hoc signed and not Apple-notarized. Follow the illustrated Open Anyway guide at https://dictate-macos.vercel.app/download#mac.
Windows builds remain unsigned. Smart App Control may block the installer or app and has no per-app Run anyway exception. Do not disable Windows protection just to use this beta. SmartScreen's More info / Run anyway option, when available, does not override Smart App Control. See https://dictate-macos.vercel.app/download#windows.

Automated verification covers the renderer build, Windows input-binding policy, native offline Whisper/Parakeet inference on synthetic speech, installer runtime dependencies, and app startup. UI checks cover light, dark, onboarding, all six destinations, settings tabs, shortcuts, models, dictionary, recording recovery, and minimum-window layouts with synthetic IPC. Physical microphone, global input, editor insertion, and installer-policy testing on a Windows machine are still needed.
