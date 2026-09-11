A free, open-source Mac and Windows community beta. No Dictate account, API key, paid service, or subscription.

New in beta 8:
- Mac AI models offers “Use model” for Apple Speech Transcriber, which is built into supported macOS versions. macOS manages any missing language assets. Fresh supported Mac setups default to Apple and preserve saved choices.
- Mac onboarding offers NVIDIA Parakeet directly: download and switch if it works better for your voice.
- Fresh Windows installations begin downloading NVIDIA Parakeet TDT 0.6B v3 automatically (670 MB). Cancel setup or choose another model at any time. Existing model selections are preserved because older preferences do not distinguish defaults from deliberate choices.
- Windows Whisper cancellation uses a corrected native callback, preventing false aborts during recognition.
- Windows microphone levels use consistent 30 Hz RMS windows and a more sensitive response curve. A 32 × 16 ready indicator stays visible between sessions by default, with a General settings toggle.
- Windows keeps the existing Tiny, Base, Small and Parakeet catalog. Medium and Large v3 Turbo are deferred pending practical CPU acceleration and completed inference validation; Mac-only CoreML Parakeet variants remain Mac-only.
- Includes preparation tooling and a submission checklist for the free Microsoft Store/MSIX signing route. Store certification and signing are pending; this GitHub EXE remains unsigned.

The experimental Mac writing-cleanup prototype is not included in this release; it remains local for user testing.

Install:
1. Quit an older Dictate instance before installing this beta.
2. Open the installer for your computer.
3. On Windows, let the initial Parakeet download finish or choose a different model in Setup options. Focus an editable field, hold Right Ctrl, speak, and release.

Compatibility: Mac Apple silicon, macOS 14+; Windows 10/11 x64. Linux support is paused. Windows Sandbox needs microphone input enabled; allow 8 GB memory when testing Parakeet, or start with Whisper Tiny.

Mac builds are ad-hoc signed and not Apple-notarized. Follow the illustrated Open Anyway guide at https://dictate-macos.vercel.app/download#mac.
Windows builds remain unsigned. Smart App Control may block the installer or app and has no per-app Run anyway exception. Do not disable Windows protection just to use this beta. SmartScreen's More info / Run anyway option, when available, does not override Smart App Control. See https://dictate-macos.vercel.app/download#windows.

Automated verification covers the renderer build, Windows input-binding policy, native offline Whisper/Parakeet inference on synthetic speech, installer runtime dependencies, and app startup. UI checks cover light and dark themes, onboarding, all six destinations, the shared brand mark, chart hover values, the active recording treatment, the system privacy opener, settings tabs, shortcuts, models, dictionary, recovery, the compact overlay, and minimum-window layouts with synthetic IPC. Physical microphone, global input, editor insertion, and installer-policy testing on a Windows machine are still needed.
