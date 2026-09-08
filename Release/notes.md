A free, open-source community beta. No account or paid transcription service.

New in beta 4:
- Supported macOS 26 Macs default to Apple Speech, including a one-time reset of older saved model selections. Later deliberate choices remain saved. Unsupported devices/languages keep a local-model fallback.
- Wider Mac onboarding shows the core steps without scrolling, with a proper insertion button and separate setup options.
- Model status distinguishes downloading, checking files, and loading a model already on your Mac.
- The website suggests a download by operating system and shows illustrated Mac “Open Anyway” instructions.

Compatibility:
- Native Mac app: Apple silicon, macOS 14+. Apple Speech is available on macOS 26 when supported; older systems use downloaded local models. No Xcode is required to run the app.
- Windows beta: x64 installer, local Whisper recognition, dictionary/history, and guarded text insertion with copy recovery.
- Linux beta: x64 DEB/AppImage, local Whisper recognition and copy recovery. See the compatibility guide for desktop-specific shortcut/insertion limitations.
- First launch guides model setup inside the app. Models are downloaded once and inference runs locally.
- Repository users can run `./Scripts/start.sh` on a supported Mac to install this prebuilt release rather than compiling.

Mac builds are ad-hoc signed and are not Apple-notarized. For an unverified-developer warning, review the app under System Settings → Privacy & Security. Windows community installers are unsigned and can show a reputation warning. Managed work computers may require IT approval.

Build and automated checks do not replace real microphone/cross-app tests. Older macOS and Windows/Linux hardware coverage is recorded in docs/evidence/portability-validation.md. Please test this beta before relying on it for important dictation.
