# Dictate Microsoft Store submission preparation

Status: the Store product is reserved and its assigned identity is wired into the manifest. Building the MSIX, certification, and submission remain.

## Owner setup

1. On the Windows build machine, install Git, Node.js 20 or later, Rust, Visual Studio 2022 Build Tools with **Desktop development with C++**, 7-Zip, and the Windows 10/11 SDK.
2. Download the current official **x64 Fixed Version WebView2 Runtime** from https://developer.microsoft.com/microsoft-edge/webview2/ and extract it. The folder passed below must directly contain `msedgewebview2.exe`. Update the bundled runtime with each Store release for browser security fixes.
3. From the repository root, build the validated NSIS payload and package it:

```powershell
npm --prefix Desktop ci
npm --prefix Desktop run tauri -- build --bundles nsis
.\Scripts\build-windows-msix.ps1 -WebView2Runtime 'C:\path\to\folder-containing-msedgewebview2.exe'
```

The script defaults to the reserved product identity, the installed display name **Dictate - Private Voice Typing**, and package version `1.1.9.0`. Future submissions must use a higher version, with the fourth component kept at zero.

4. Run Windows App Certification Kit from an Administrator PowerShell:

```powershell
& 'C:\Program Files (x86)\Windows Kits\10\App Certification Kit\appcert.exe' reset
& 'C:\Program Files (x86)\Windows Kits\10\App Certification Kit\appcert.exe' test -appxpackagepath '.\dist\Dictate-Windows-x64-Store.msix' -reportoutputpath '.\dist\WACK-report.xml'
```

5. Test first Parakeet download/cancellation, microphone, tray/shortcut, idle indicator, insertion, model switching, upgrade persistence, uninstall, offline operation after setup, and **Settings → General → Download update**. Store packaging may use a separate per-user data location from the NSIS beta; test data migration before recommending it as an upgrade.
6. Upload `dist\Dictate-Windows-x64-Store.msix` in Partner Center, add real screenshots, age rating, category Productivity, price Free, privacy URL https://dictate-macos.vercel.app/privacy and support URL https://github.com/leviackerman05/dictate/issues. Submit for certification. Microsoft signs the MSIX after it passes certification; the unsigned local package is not a public installer.

## Listing draft

**Short description:** Speak naturally and keep writing. Private dictation that runs on your PC.

**Description:** Hold your recording shortcut, speak, and release to insert text at your cursor. Dictate runs speech recognition on your PC using free local models. First launch downloads NVIDIA Parakeet TDT 0.6B v3; cancel or choose a different model at any time. No NVIDIA GPU is needed. Your history and dictionary stay on this PC. There is no Dictate account, subscription, telemetry, or cloud transcription. If insertion is unavailable, your words remain ready to copy.

**Requirements:** Windows 10 version 2004 or later / Windows 11, x64. Internet for initial model download; 8 GB RAM recommended for Parakeet. Microphone required for dictation.

**Certification notes:** runFullTrust is required for the native audio/recognition engines, system-wide push-to-talk key handling, tray operation and inserting dictated text into the user's focused application. Microphone audio is held in memory during active recording and never saved. Network requests download publicly hosted, checksum-verified model files only; recognition is local. The Settings update control uses Windows.Services.Store to check for and request installation of signed Microsoft Store updates, then restarts after Windows reports completion. No elevated permissions or security-policy changes are requested. WebView2 and speech runtime dependencies are bundled.

Microsoft signs MSIX submissions after certification. Store signing does not sign the separate GitHub EXE installer. References: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options and https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/app-package-requirements.
