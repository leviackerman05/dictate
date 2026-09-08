# Dictate distribution and portability plan

Prepared: 2026-09-08. Implementation status: community beta implemented and published; automated release validation passed. Device acceptance remains open.

The original phased plan below records the intended longer-term rollout. Current code delivers a native Mac build targeting macOS 14+, a verified repository launcher, explicit model onboarding, and Windows/Linux portable beta installers. Wayland remains Record + Copy; Intel Mac and additional Linux desktop integrations remain future work. Physical-device acceptance, including the owner's two macOS 26 machines, is not claimed by automated checks. See [the validation record](evidence/portability-validation.md) for actual results and the short test procedure.

Implementation constraint (owner, 2026-09-08): spend no money. Use local recognition and free/open-source dependencies. Do not buy Apple membership, signing certificates, paid APIs, hosting, or CI capacity. Paid distribution options below are background information only and are excluded from the authorized implementation. Publish community builds with accurate first-launch instructions; use only existing free deployment capacity and public-repository standard CI runners.

Make the existing Mac download usable first, add a one-command repository launcher and older-macOS model onboarding, then deliver Windows and Linux in stages. Ordinary users should install a packaged application and prepare a model inside it. They should never need Git, Xcode, Swift, Rust, Node.js, Python, or a compiler. Cloning remains an optional route for people who already have Git.

## Original repository assessment (before implementation)

This section and the phased estimates below preserve the original planning
baseline. For current behavior and installation steps, use the
[installation guide](INSTALLATION.md) and [validation record](evidence/portability-validation.md).

- `Scripts/build-app.sh` creates `build/Dictate.app` and ad-hoc signs it. It does not use a Developer ID certificate or notarize the result.
- `Scripts/create-dmg.sh` packages the app with a shortcut to `/Applications`. Installing there is expected. The repository's `build/` directory is only for source builds.
- `Scripts/release-preflight.sh` allows a failed Gatekeeper assessment and still reports success. This validates a community package, not a release that opens under normal Gatekeeper policy.
- The website links to the latest GitHub release's DMG. Its link check currently checks strings in source, not whether the downloadable asset exists or works.
- The README and installation guide recommend Control-click → Open. Apple removed that Gatekeeper override starting with macOS Sequoia. The documented override is now in System Settings → Privacy & Security. [Apple's change notice](https://developer.apple.com/news/?id=saqachfa)
- The package compiler flags, bundle metadata, and release checks require Apple silicon and macOS 26. An Intel Mac or older macOS is a separate compatibility problem that signing cannot fix.
- The application uses SwiftUI/AppKit, AVAudioEngine, Apple SpeechAnalyzer, Core ML recognizers, Accessibility, and Quartz events. These integrations need replacements for Windows and Linux.
- `DictateCore` already separates roughly 1,070 lines of product rules and data models from the Mac adapters. Its behavior and tests can guide a portable implementation, although its current build flags are also Mac-specific.

The owner subsequently clarified that the source-build failure appeared to be a Swift/Xcode error. This is consistent with the documented full-Xcode requirement, but the exact error, Mac model, macOS version, and downloaded release remain unknown. The published binary has not been inspected in this planning exercise. The earlier downloaded-app warning is a separate issue: an unverified-developer warning is consistent with the build configuration, while an explicit malware, revoked-signature, or damaged-app warning requires separate artifact investigation. [Apple's warning descriptions](https://support.apple.com/en-us/102445)

## The three separate problems

1. **Missing developer tools:** compiling this Swift application requires a compiler and SDK. Apple being the default recognizer is not what makes compilation require those tools. A packaged app needs neither Xcode nor a developer account on the recipient's machine, even when it uses Apple recognition.
2. **Unsupported operating system:** the app currently requires macOS 26 globally. Selecting Whisper in settings cannot help an app that the OS cannot launch. Lowering that requirement needs availability-safe code, compatible dependencies, and new tested binaries.
3. **Distribution trust:** a prebuilt app still encounters Gatekeeper. A one-command launcher must not hide this issue by stripping quarantine, re-signing the download locally, or disabling security checks.

The intended first-use experience is install/open → grant microphone access → click **Set up recommended model** → dictate. Optional automatic insertion requires the OS's Accessibility step on Mac. Model download and system permission prompts are real prerequisites; subsequent launches should open directly into a ready state.

## Apple membership: realistic options

| Option | Cost and result |
| --- | --- |
| Community DMG | No Apple membership payment; users may need an explicit per-app exception. Managed computers can disallow this. |
| Developer ID signing and notarization | Apple lists membership at US$99 per year, or local currency where available. This is the standard direct-download route for avoiding the unverified-developer barrier. Normal first-open and microphone/accessibility prompts still apply. |
| Fee waiver | Available to qualifying nonprofit organizations, accredited educational institutions, and government entities. Being an individual with a free/open-source app does not qualify by itself. |
| Sponsorship | A sponsor can fund membership. A legitimate organization can distribute under its own accountable publisher identity; borrowing somebody's private signing key is not a distribution plan. |

There is no general free individual substitute for Apple's Developer ID/notarization service. Changing the archive format, host, framework, or package manager does not give the binary an Apple-trusted identity. The Mac App Store is not required for direct distribution.

Sources: [Apple membership](https://developer.apple.com/programs/enroll/), [fee-waiver eligibility](https://developer.apple.com/help/account/membership/fee-waivers/), [notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Phase 1 — Repair the Mac installation experience

Estimated effort: 2–4 engineering days, plus access to a clean test Mac.

1. Reproduce the colleague's failure using the exact release and a browser download. Record OS, architecture, warning text, checksum, and signature/Gatekeeper results. If the app starts and crashes, inspect the crash separately from installation policy.
2. Make the website download flow explicit: download DMG → open it → drag Dictate to Applications → open Dictate from Finder or Spotlight. Show “Apple silicon · macOS 26+” beside the button, with a guide for checking compatibility.
3. Separate “Install the app” from “Build from source” in the README and installation guide. No Terminal commands in the ordinary installation path. For troubleshooting only, the installed path is `open /Applications/Dictate.app`; `open build/Dictate.app` applies only after building from the repository.
4. For the free community release, replace the obsolete Control-click instruction with Apple's per-app Privacy & Security flow, conditional on an unverified/not-notarized warning and a trusted, intact download. Do not present it as a remedy for confirmed malware or corrupted files.
5. Improve first launch: explain microphone access, optional Accessibility, model size/download progress, readiness, and a short test dictation. Handle denied permission, offline setup, failed download, and insufficient disk space with visible recovery.
6. Check the actual release asset URL and checksum during publishing. Publish complete assets on a draft release before making it the public/latest release, so the website cannot point users at a release still building.
7. Test the downloaded artifact on a compatible Mac without developer tools or existing model caches. Include launch from the mounted DMG, copy to Applications, relaunch, permissions, and model setup.

Acceptance: a nontechnical tester installs without cloning or compiling, understands the community-build exception if applicable, and completes their first dictation. A malformed artifact or incompatible OS gets a specific diagnosis.

Files: `README.md`, `docs/INSTALLATION.md`, `Website/src/pages/index.astro`, `Website/scripts/check-links.mjs`, `.github/workflows/release.yml`, packaging scripts, and onboarding/model-setup views as needed.

## Phase 1A — One-command launch from the repository

Estimated effort: 1–3 engineering days once compatible release assets exist. The launcher can be developed against the current release first, then extended to the older-Mac release.

Proposed command after cloning or extracting a repository ZIP:

```sh
./Scripts/start.sh
```

This command is now implemented. It installs and opens a prebuilt release. It does not compile local source changes. Keep `make app` as the clearly separate developer build path.

The launcher will:

1. Detect actual OS and hardware architecture, accounting for a shell running through Rosetta. Choose a compatible versioned artifact from a release manifest. Do not send Intel or older-macOS users the current arm64/macOS-26-only build.
2. Display the release version it will run. A tagged checkout should map to that release; an unreleased checkout should explicitly identify its tested release mapping. Never pretend a downloaded binary contains local edits.
3. Download using macOS-provided tools over HTTPS, validate against the release manifest's expected hash, and verify package/signature integrity as applicable. A hash from the same download service checks consistency, not independent publisher identity. Handle blocked network access, missing assets, and partial downloads without trying a source build.
4. Reuse an existing compatible installation. For a first installation, use `/Applications` when writable, otherwise `~/Applications`, without a sudo prompt. Track the actual installation path and avoid creating duplicate installations that confuse permissions. Stage replacements and preserve the prior version until validation succeeds; do not overwrite a running app.
5. Open the installed bundle using its absolute path. Retain history, dictionary, preferences, and model caches. A second run should reuse the installed release without another download or setup.
6. If Gatekeeper or organizational policy blocks execution, present the relevant app-specific guidance and exact diagnostic. Preserve applicable quarantine/security assessment and validate both this route and a browser download on a clean Mac.

Git itself is not guaranteed to be installed on a clean Mac; invoking Apple's Git stub may request developer tools. Therefore the website DMG remains the shortest route. “Download source ZIP → extract → run the launcher” is an alternative for people who want the repository without installing Git. Do not require Homebrew, GitHub CLI, or Xcode for the launcher.

Acceptance: a clean machine with no compiler, SDK, Git, or cached models can run the extracted launcher using system tools and reach onboarding. Another tester can use an existing clone and run the same command. The app launches from either installation location, and launch/install errors never turn into Swift build errors.

## Phase 1B — Older macOS and capability-based model onboarding

Estimated effort: 1–2 engineering weeks for an Apple-silicon compatibility beta, subject to dependency/runtime tests. This moves ahead of the Windows/Linux port because older Macs are part of the immediate request.

**First candidate minimum: macOS 14 on Apple silicon.** The inspected local dependency manifests declare macOS 14 for FluidAudio and macOS 13 for WhisperKit, which makes 14 a reasonable starting point, not proof that every bundled model works there. Validate the exact pinned dependency versions. macOS 13 or earlier and Intel support require separate dependency/API/inference work. Do not advertise them based only on a model's name.

| Environment | Proposed initial recognition behavior |
| --- | --- |
| Apple silicon, macOS 26+ | Offer Apple recognition only when OS, hardware, locale, and assets support it; offer a compatible downloaded model if unavailable. |
| Apple silicon, macOS 14–15 | Recommend a tested WhisperKit or Parakeet model after checking language, memory, and model compatibility. Do not instantiate SpeechAnalyzer. |
| Intel Mac | Add a tested whisper.cpp CPU backend and an x86_64-compatible application build as an explicit additional target. Keep unavailable Core ML providers out of this build if necessary. |
| Windows/Linux initial targets | Recommend a compatible whisper.cpp model, download inside onboarding, then load locally. No Apple recognizer option. |

Implementation:

- Lower the deployment target in `Package.swift`, compiler target flags, bundle metadata, and release assertions together. Audit all UI and framework APIs and the linked dependency binaries for the chosen minimum OS. A recent build SDK can target older systems when newer APIs are properly guarded. [Apple availability guidance](https://developer.apple.com/documentation/xcode/running-code-on-a-specific-version/)
- Isolate the Apple recognizer with availability annotations and construct it only inside an OS availability guard. The controller currently constructs it eagerly in a default initializer argument, and the benchmark constructs it directly too; both must change. Merely hiding the model in the UI is insufficient. Verify older-OS launch for missing-symbol/linker failures.
- Add a provider factory and capability catalog shared by settings, onboarding, startup, and benchmarks. Separate “supported on this device,” “downloaded,” “loading,” and “ready.” Check language and compute requirements, not just OS version. Do not warm up or download an unsupported provider at launch.
- Preserve existing supported user selections. If a saved provider is unavailable, choose an already-installed compatible model where possible or return to setup with a short explanation. Do not silently start a large replacement download.
- Present one recommendation with **Set up recommended model** as the primary action and advanced alternatives behind a secondary choice. Include expected download size, disk/RAM requirements, and supported language. Replace unverified hard-coded footprint/quality claims with artifact metadata and measured guidance; the current Base/Small Whisper choices are English-only variants.
- Download only the chosen model after the setup action. Show progress, allow cancel/retry, resume when the hosting/provider API supports it, validate complete assets, and keep partial files separate. Interrupted setup must resume cleanly on relaunch and must not erase an existing working model.
- Request microphone access in context. Explain Accessibility as optional automatic insertion and allow copy-only use. Model readiness plus microphone permission must gate “Ready”; granting permissions alone must not display a false ready screen.
- Keep a usable default shortcut and defer custom key configuration. End setup with a short dictation test and visible Copy recovery. Reuse cached models on future launches and verify recording works with networking disabled after setup.

Files include `Package.swift`, `Sources/Dictate/Resources/Info.plist`, `Scripts/build-app.sh`, `Scripts/release-preflight.sh`, `Sources/Dictate/AppModel.swift`, `Sources/Dictate/DictationController.swift`, `Sources/Dictate/Recognition/`, `Sources/Dictate/BenchmarkCommandLine.swift`, and onboarding/localized UI text.

Acceptance: the new binary launches and completes local dictation on the oldest advertised macOS without Xcode. macOS 26 retains Apple recognition. A Mac without a supported Apple locale can finish setup using a downloaded compatible model. No unsupported Apple provider is constructed during launch, model listing, cancellation, or benchmarking.

## Phase 2 — Offer a signed, notarized Mac release

Estimated effort: 2–5 engineering days after membership and credentials are available; Apple enrollment timing is external.

1. Add separate community and trusted-release build modes. Preserve `app.dictate.desktop` and test permissions/data when upgrading from an ad-hoc build.
2. Sign nested executable code and the app in the correct order with Developer ID, a secure timestamp, hardened runtime, and only the entitlements required by recording and the actual runtime. Test audio and all recognizers under that configuration.
3. Submit the signed app archive through `notarytool`, require acceptance, staple and validate the app ticket, build/sign the final DMG, then notarize/staple and validate the DMG. Generate the checksum only after the final artifact is complete.
4. Make trusted-release CI fail on missing credentials, ad-hoc signatures, notarization rejection, missing tickets, or failed Gatekeeper validation. Keep community results explicitly labeled.
5. Keep signing credentials in protected CI secrets and a temporary keychain. Release from an immutable tag with traceable versions; do not expose credentials to pull-request jobs.
6. Repeat the real browser-download install on a clean Mac and check offline first-open verification with stapled tickets. Test an upgrade and permission recovery.

Acceptance: the public download passes Gatekeeper without an unverified-developer exception. Notarization is a security scan, not App Store review. [Apple's notarization workflow](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

## Phase 3 — Prove the portable architecture

Estimated effort: 1–2 engineering weeks. Commit to the stack after the prototype passes.

Recommended candidate: Tauri 2 for the Windows/Linux desktop shell, a Rust core for shared product logic, and whisper.cpp for the first portable recognition engine. Tauri provides platform installers, but microphone capture, focus tracking, overlay behavior, and text delivery still need native integration. [Tauri distribution](https://v2.tauri.app/distribute/)

Keep shipping the current Swift Mac app during the port. Port dictionary matching, transcript assembly, session/shortcut reducers, history retention, recovery, and benchmark metrics to the shared core. Use common language-neutral fixtures to compare Swift and Rust behavior, especially Unicode matching, separator handling, tie-breaking, and cancellation. Preserve the JSON schemas and validate import/export compatibility.

Define explicit boundaries for audio capture, recognizers, global shortcuts, focus/delivery, permissions, model storage, and recovery persistence. Keep microphone samples in memory; run CPU-heavy inference off the UI thread. Bundle the inference library rather than asking users to install Python or run a command-line recognizer against temporary audio files.

Start with Whisper using a tested CPU baseline; add acceleration only where validated. whisper.cpp supports Windows/Linux and CPU execution. Existing WhisperKit/Core ML caches cannot simply become portable model files: downloads, formats, hardware checks, integrity verification, licenses, removal, and migration must be handled per provider. [whisper.cpp](https://github.com/ggml-org/whisper.cpp)

Apple Speech remains Mac-only. Keep current Mac Parakeet support and evaluate a portable Parakeet runtime/export later; do not promise every model variant on every OS in the first release. FluidAudio is an Apple/Core ML integration. [FluidAudio](https://docs.fluidinference.com/introduction)

Prototype acceptance: on real Windows and Linux machines, record → release → local transcription → insert or recover. Verify latency and memory with the same short and long audio fixtures. Prove global shortcut release events and a non-focus-stealing overlay before investing in the full UI.

Alternatives: Electron is reasonable if webview consistency outweighs its larger bundled runtime; separate native applications maximize platform integration but multiply UI maintenance. Swift-only reuse would still leave the Apple UI, audio, and delivery dependencies to replace. The recommended choice remains conditional on the native-integration prototype.

## Phase 4 — Ship Windows beta

Estimated effort: 3–5 engineering weeks after the prototype. Initial target: Windows 11 x64; Windows ARM64 is a later tested target.

- Implement microphone/device lifecycle, global shortcut state, tray controls, non-activating overlay, and focus-aware delivery. Use Windows UI Automation to identify targets and guarded native paste where appropriate; do not replace the entire field value to simulate caret insertion.
- Preserve explicit copy/retry recovery, password-field exclusion, focus-change handling, cancellation, and guarded clipboard restoration.
- Treat elevated target apps as a distinct limitation. Windows `SendInput` cannot inject into higher-integrity processes; do not require running the whole app as administrator. [Microsoft SendInput](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput)
- Recreate onboarding, history, dictionary, model management, settings, and statistics with feature parity tracked explicitly.
- Ship a normal setup EXE with needed runtimes installed automatically. Tauri supports WebView2 bootstrapper or offline runtime packaging. [Windows installer options](https://v2.tauri.app/distribute/windows-installer/)
- Decide the Windows signing/distribution route before calling it a low-friction public download. Valid signing helps publisher identity but new signed binaries can still trigger SmartScreen. Evaluate a Store-packaged route separately; do not promise that signing alone removes every warning. [Microsoft SmartScreen guidance](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation)

Acceptance: clean installation with no developer tools; successful offline recognition after setup; tests in Notepad, a browser, an Electron editor, and a terminal; correct copy recovery when delivery is unavailable. Exercise non-English layouts, Unicode, app switching, microphone removal, suspend/resume, and denied permissions.

## Phase 5 — Ship Linux beta with explicit desktop support

Estimated effort: 3–5 engineering weeks, with desktop compatibility likely to extend hardening.

Start with an Ubuntu LTS x86_64 target and a Fedora target selected during the prototype. Test GNOME Wayland, KDE Wayland, and X11 separately; these are different support targets, not one generic “Linux” checkbox.

- Implement microphone capture, local inference, model management, and local storage first.
- On X11, validate shortcut registration, focus inspection, and guarded paste against the supported desktop/apps.
- On Wayland, investigate the GlobalShortcuts portal for activation/deactivation and consent-based input mechanisms where implemented. Portal availability and behavior depend on the desktop backend. Keyboard injection via RemoteDesktop requires an authorized session; it is not an automatic equivalent of a Mac Accessibility grant. [GlobalShortcuts](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.GlobalShortcuts.html), [RemoteDesktop](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.RemoteDesktop.html)
- Expose a clear capability state: automatic insertion available, extra desktop setup required, or copy-only. Unsupported global shortcuts need visible start/stop controls. Copy-only is useful but must not be marketed as complete system-wide dictation parity.
- Begin with a tested `.deb` and evaluate AppImage/RPM for the second target. Verify runtime dependencies on clean systems; an AppImage is not a guarantee of universal compatibility. Evaluate Flatpak only after its permissions and portal behavior meet the product requirements.

Acceptance: each advertised desktop session has recorded results for global hold/toggle, insertion, recovery, clipboard changes, model setup, and first installation. Do not advertise universal Wayland insertion based only on X11 tests.

## Phase 6 — Additional architectures and shared-core consolidation

Estimated effort: 2–4 additional engineering weeks, subject to API and dependency findings.

Older Apple-silicon Macs are addressed in Phase 1B. Add Intel Mac support as soon as the portable inference backend and native x86_64 build are validated; if one of the owner's test Macs is Intel, promote that work ahead of the Windows beta. Evaluate macOS 13 or earlier separately, including whether FluidAudio must be excluded and newer UI APIs replaced. Build and test each architecture explicitly.

Once Windows/Linux are stable, integrate the shared Rust product core into the existing Mac shell through a small C-compatible interface, or evaluate a Tauri Mac shell against the native app. Keep Apple recognition and delivery adapters. Make that a separate migration with history, dictionary, preference, and recovery backups and parity tests.

Then add authenticated application updates with signature verification and recovery from interrupted updates. Use versioned assets, a supported-platform download selector, and a maintained compatibility matrix. Track model and native-library licenses in the release notices. Expand ARM64/GPU/distro support based on measured demand and performance.

## Sequence, budget, and completion criteria

Recommended order: Mac installation repair and one-command launcher → older-Mac compatibility and model onboarding → optional trusted Mac distribution → portable prototype → Windows beta → Linux beta → additional architectures and shared-core consolidation. Signing work can proceed independently once credentials exist.

Rough planning range for one experienced engineer: about 2–3 engineering weeks for the expanded initial Mac usability/older-OS beta, and about 10–17 engineering weeks total including initial Windows/Linux betas. Intel/additional older OS targets and production hardening can add work. These are estimates, not delivery commitments; revise after the compatibility build and portable prototype. Access to real target machines, Windows signing eligibility, Apple enrollment, and Linux compositor behavior are dependencies.

The no-membership option can improve installation immediately, but cannot promise the same first-launch experience as Developer ID/notarized distribution. A membership decision is not required to begin Phase 1 or the portability prototype.

Every public target must install without developer tools, explain model setup, operate locally after setup, preserve text when delivery is unavailable, and publish only the OS/architecture/editor capabilities actually tested. Build success and pure unit tests alone do not prove clean-machine installation or cross-app dictation.

## Owner's personal/work-machine acceptance run

The owner confirmed that both the personal and work Mac run macOS 26. Chip architectures remain unconfirmed; detect them before selecting the beta artifacts. Both machines can validate ordinary installation and a deliberately selected downloaded-model path. They cannot validate launch on macOS 14/15: obtain an additional older-OS test environment, with real hardware for final microphone/acceleration/insertion checks. Do not remove developer tools or personal data from an existing Mac to simulate a clean install; use a separate test machine/appropriate clean environment for that check.

| Test | Required result |
| --- | --- |
| Personal Mac (macOS 26), website download | Install/open, complete setup, and dictate without using a development checkout. Test both Apple recognition and an explicitly selected downloaded model. |
| Work Mac (macOS 26), website download | Same two recognition paths where organizational policy allows them; blocked permissions/network/install paths produce a specific explanation. |
| Repository launcher, both Macs | One command chooses a compatible prebuilt version and launches the actual installed path. No Swift/Xcode/Homebrew prompts. |
| Clean Mac without developer tools | DMG and extracted-source launcher both work; first model downloads entirely through the app. |
| Oldest supported macOS | Launch and dictate with the recommended downloaded model; no newer-API crash. |
| macOS 26 | Apple engine and downloaded-model fallback both work. |
| Apple provider unavailable during tests | Inject an unavailable capability in automated tests and verify fallback/setup; explicitly select a downloaded model on both Macs for end-to-end checks. This is not a substitute for older-OS launch testing. |
| Setup interrupted/offline/disk full | Recoverable explanation and retry; no false ready state or corrupt cache. |
| Relaunch with network disabled | Reuse the installed model; microphone recording and local recognition still work. |
| Automatic insertion denied | Transcript remains visibly available to copy; no repeated permission loop. |
| Cross-app use | Test a native editor, browser text field, Electron editor, and terminal; cover hold/toggle, focus changes, clipboard changes, cancellation, and sleep/wake. |
| Upgrade/rerun | Retain history, dictionary, settings, and model cache; avoid duplicate app copies and redundant downloads. |

For each run, record app version, OS/chip, installation route, selected model/version, whether developer tools were present, number of user steps, and pass/fail. Collect diagnostics without transcript or audio content. Set a measurable UX gate: one launcher command after obtaining the repository, one model-setup action, and no manual dependency installation; OS consent and any community Gatekeeper exception are counted separately and documented.

This plan is not evidence that the changes work yet. Release acceptance requires the implemented binary, automated policy/model-selection tests, and completed clean-machine and personal/work-machine runs. A managed work Mac may require IT approval that neither a launcher nor model substitution can grant.
