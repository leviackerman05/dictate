# Windows signing

Selected route: **Microsoft Store MSIX**, using Microsoft's free signing after certification. The repository now includes [Store submission preparation](../Release/windows-store/submission.md), a manifest template, and `Scripts/build-windows-msix.ps1`. The script requires real Partner Center identity values and a Microsoft-signed Fixed Version WebView2 runtime. No account or publisher identity is fabricated.

Current GitHub installers remain unsigned. Creating an MSIX or submitting an EXE to the Store does not itself confer public trust. Store publication depends on the owner's developer verification, app reservation and Microsoft's certification. Do not disable Smart App Control to install this beta.

Microsoft confirms free individual registration and automatic signing for MSIX submissions:
- https://learn.microsoft.com/en-us/windows/apps/publish/whats-new-individual-developer
- https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options
- https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/app-package-requirements

SignPath Foundation remains a possible free alternative for direct EXE distribution, subject to application and approval: https://signpath.org/terms.html. No approval or timing is guaranteed for either route.
