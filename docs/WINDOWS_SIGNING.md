# Windows signing blocker and a free route forward

The owner supplied a Windows 11 Smart App Control dialog on September 8, 2026.
It blocks `Dictate-Windows-x64-setup.exe` because the publisher cannot be verified.
This is an installation failure, before microphone or dictation testing.

Microsoft documents that Smart App Control has no individual-app exception.
The current unsigned release cannot promise compatibility with it enabled.
A self-signed certificate or changing the installer filename does not provide
public publisher trust. Do not turn off system protection as an onboarding step.

A candidate within the zero-spend requirement is **SignPath Foundation**. It
provides signing for approved open-source projects, subject to its eligibility
and security rules. Approval is external and is not guaranteed. Dictate has not
applied or received a certificate, and no signing account has been created.

Before applying, the maintainer needs to review the terms, confirm team roles
and MFA, and approve submission of the project. Application facts: Dictate;
MIT license; public repository `leviackerman05/dictate`; a Windows x64 NSIS
installer built by GitHub Actions; offline CPU Whisper recognition following
an explicit model download; privacy policy in `PRIVACY.md`.

After approval, integrate the service into the Windows release workflow, sign
the application and installer (and check bundled executable dependencies),
verify trusted signatures, then generate checksums from the final signed files.
Publish a new immutable release. Acceptance must include an actual Windows 11
machine with Smart App Control enabled, installation, app launch, model setup,
microphone recording, recognition, and insertion or copy recovery. Until that
passes, keep the limitation visible on the download page.

No paid certificate, signing plan, API, hosting upgrade, or paid build service
is authorized. Do not publish signing-provider attribution before approval.

Sources checked September 8, 2026:

- [Microsoft: Smart App Control FAQ](https://support.microsoft.com/en-us/windows/security/threat-malware-protection/smart-app-control-frequently-asked-questions)
- [Microsoft: signing for Smart App Control](https://learn.microsoft.com/en-us/windows/apps/develop/smart-app-control/code-signing-for-smart-app-control)
- [SignPath Foundation eligibility and signing conditions](https://signpath.org/terms)
- [SignPath Foundation application](https://signpath.org/apply)
