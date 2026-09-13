# Windows Beta 1 validation

Windows Beta 1 consolidates the earlier development releases into one public Windows release line. The existing Mac release remains separate.

## Automated checks

- TypeScript type check and production renderer build.
- Rust core and desktop tests on Windows.
- Real Whisper and NVIDIA Parakeet recognition against synthetic speech in Windows CI.
- NSIS runtime dependency inspection.
- UI smoke checks at 760 × 560, 1120 × 750, and 2560 × 1440 in light and dark themes.
- Microsoft Store update availability and install command wiring through synthetic IPC.

## Store package

- Product identity: `PriyanshSingh.Dictate-PrivateVoiceTyping`
- Publisher: `CN=41A9F374-D1EA-4092-B9C8-24D61C5BE98A`
- Package version: `1.1.9.0`
- Marketing label: Windows Beta 1

The signed MSIX uses `Windows.Services.Store.StoreContext` to check for updates and request download and installation. Windows presents the consent UI and Dictate restarts only after the Store reports completion. The unsigned GitHub installer opens the download page for updates.

Physical-device microphone, global input, editor insertion, Store consent UI, upgrade persistence, and certification still require acceptance testing on a Windows PC before the Partner Center submission is sent.
