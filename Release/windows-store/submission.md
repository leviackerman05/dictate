# Dictate Microsoft Store submission preparation

Status: preparation only. No Store account, assigned identity, certification, or trusted signature is assumed.

## Owner setup

1. Register the free individual developer account at https://storedeveloper.microsoft.com and complete Microsoft's identity verification.
2. Reserve Dictate as an **MSIX** app. Copy Package/Identity/Name, Package/Identity/Publisher, and the publisher display name from Product management → Product identity.
3. Download the current official **x64 Fixed Version WebView2 Runtime** from https://developer.microsoft.com/microsoft-edge/webview2/ and extract it on the Windows build machine. The package includes this runtime so users do not need a separate installer. Update it with each Store release for browser security fixes.
4. Build and validate the release using the existing Windows workflow, then run:

```powershell
./Scripts/build-windows-msix.ps1 -IdentityName '<assigned identity>' -Publisher '<assigned publisher>' -PublisherDisplayName '<verified display name>' -Version '1.1.8.0' -WebView2Runtime 'C:\path\to\extracted-runtime'
```

The version is a proposed first Store package version; confirm it exceeds previous submissions. Its fourth component must be zero. The template placeholders are never valid submission identity values.

5. Run Windows App Certification Kit and test installation, first Parakeet download/cancellation, microphone, tray/shortcut, idle indicator, insertion, model switching, upgrade persistence and uninstall with the packaged app. Verify offline operation after setup. Store packaging may use a separate per-user data location from the NSIS beta; test data migration before recommending it as an upgrade.
6. Upload the MSIX in Partner Center, add real screenshots, age rating, category Productivity, price Free, privacy URL https://dictate-macos.vercel.app/privacy and support URL https://github.com/leviackerman05/dictate/issues. Submit for certification. Do not publish an unsigned MSIX as a trusted public installer.

## Listing draft

**Short description:** Speak naturally and keep writing. Private dictation that runs on your PC.

**Description:** Hold your recording shortcut, speak, and release to insert text at your cursor. Dictate runs speech recognition on your PC using free local models. First launch downloads NVIDIA Parakeet TDT 0.6B v3; cancel or choose a different model at any time. No NVIDIA GPU is needed. Your history and dictionary stay on this PC. There is no Dictate account, subscription, telemetry, or cloud transcription. If insertion is unavailable, your words remain ready to copy.

**Requirements:** Windows 10 version 2004 or later / Windows 11, x64. Internet for initial model download; 8 GB RAM recommended for Parakeet. Microphone required for dictation.

**Certification notes:** runFullTrust is required for the native audio/recognition engines, system-wide push-to-talk key handling, tray operation and inserting dictated text into the user's focused application. Microphone audio is held in memory during active recording and never saved. Network requests download publicly hosted, checksum-verified model files only; recognition is local. No elevated permissions or security-policy changes are requested. WebView2 and speech runtime dependencies are bundled.

Microsoft signs MSIX submissions after certification. Store signing does not sign the separate GitHub EXE installer. References: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options and https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/app-package-requirements.
