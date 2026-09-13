A free, open-source Mac and Windows community beta. No Dictate account, API key, paid service, or subscription.

New in beta 9:
- Windows uses Segoe UI Variable Text and Display with calmer weights and consistent data typography throughout the app.
- Dashboard, Dictionary, Statistics, AI models, and Settings now center and expand across large displays, including 27-inch 1440p monitors, while retaining the compact 760 × 560 layout.
- History expands transcript actions in place with a smooth disclosure animation instead of rebuilding the page.
- Dictionary Add/Edit/Cancel transitions are smoother, and the Cancel hover target no longer grows taller than the control.
- AI model state and action columns stay aligned whether a model is Ready or Not installed.
- The floating Windows recorder uses crisp rounded waveform bars and responds more strongly to normal speaking levels.
- When Dictate cannot return words to a focused field, the floating recorder now provides Copy and Dismiss controls. The same transcript remains recoverable in the main window until copied or dismissed.
- The Microsoft Store identity remains configured for “Dictate - Private Voice Typing”; Store certification and signing are still pending.

Install:
1. Quit an older Dictate instance before installing this beta.
2. Open the installer for your computer.
3. On Windows, let the initial NVIDIA Parakeet download finish or choose another model in Setup options. Focus an editable field, hold Right Ctrl, speak, and release.

Compatibility: Mac Apple silicon, macOS 14+; Windows 10/11 x64. Linux support is paused. Windows Sandbox needs microphone input enabled; allow 8 GB memory when testing Parakeet, or start with Whisper Tiny.

Mac builds are ad-hoc signed and not Apple-notarized. Follow the illustrated Open Anyway guide at https://dictate-macos.vercel.app/download#mac.
Windows GitHub builds remain unsigned. Smart App Control may block the installer or app and has no per-app Run anyway exception. Do not disable Windows protection just to use this beta. SmartScreen's More info / Run anyway option, when available, does not override Smart App Control. See https://dictate-macos.vercel.app/download#windows.

Automated verification covers the renderer build, Windows native unit tests, local model recognition on Windows CI, installer runtime dependencies, and app startup. UI checks cover light and dark themes, all six destinations, 760 × 560 and 2560 × 1440 layouts, aligned model states, history and dictionary interactions, waveform response, and the recovery Copy action with synthetic IPC. Physical microphone, global input, editor insertion, overlay interaction, and installer-policy testing on a Windows machine still require acceptance testing.
