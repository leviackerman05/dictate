A free, open-source Mac and Windows community beta. No account, API key, paid service, or subscription.

New in beta 7:
- Windows shortcut edges are processed in order, so releasing a hold-to-talk key during microphone startup now finishes correctly and a second click-to-toggle press cannot race the first press.
- The Windows recorder matches Mac's compact 62 × 22 signal pebble with no action buttons. Its transparent shadow host is centered above the usable work area of the display under the pointer, keeping it clear of the Windows taskbar in normal sessions and Windows Sandbox.
- Windows uses the same Dictate mark as the Mac app and native Segoe Variable typography. The Dashboard recording button now turns red with the same filled stop mark used on Mac.
- Dashboard chart points are round and centered over their date cells. Dashboard and Statistics charts expose exact word counts on mouse hover and keyboard focus. The native Mac Dashboard chart uses the same date alignment and hover values.
- Privacy links on Windows now use the system browser. The website has a dedicated responsive privacy page describing local data, model downloads, permissions, and recovery behavior for both platforms.
- Windows still includes NVIDIA Parakeet TDT v3 and Whisper Tiny, Base, and Small. All run locally on CPU; no NVIDIA GPU, Python, CUDA, account, paid API, or paid service is required.

Install:
1. Quit an older Dictate instance before installing this beta.
2. Download the installer for your computer and open it.
3. On Windows, choose Set up speech model. Focus an editable field, hold Right Ctrl, speak, and release. Use History or the recovery card if an editor refuses insertion.

Compatibility: Mac Apple silicon, macOS 14+; Windows 10/11 x64. Linux support is paused. Windows Sandbox needs microphone input enabled; allow 8 GB memory when testing Parakeet, or start with Whisper Tiny.

Mac builds are ad-hoc signed and not Apple-notarized. Follow the illustrated Open Anyway guide at https://dictate-macos.vercel.app/download#mac.
Windows builds remain unsigned. Smart App Control may block the installer or app and has no per-app Run anyway exception. Do not disable Windows protection just to use this beta. SmartScreen's More info / Run anyway option, when available, does not override Smart App Control. See https://dictate-macos.vercel.app/download#windows.

Automated verification covers the renderer build, Windows input-binding policy, native offline Whisper/Parakeet inference on synthetic speech, installer runtime dependencies, and app startup. UI checks cover light and dark themes, onboarding, all six destinations, the shared brand mark, chart hover values, the active recording treatment, the system privacy opener, settings tabs, shortcuts, models, dictionary, recovery, the compact overlay, and minimum-window layouts with synthetic IPC. Physical microphone, global input, editor insertion, and installer-policy testing on a Windows machine are still needed.
