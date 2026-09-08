# Beta 4 onboarding and download flow

Recorded September 8, 2026. Zero paid APIs, signing, hosting upgrades, or paid CI runners were used. Release builds use standard runners in the public repository; hosting remains the existing Vercel Hobby project.

## Changes

- On macOS 26 devices supporting Apple Speech, a one-time defaults migration selects Apple Speech over an older saved/cached Parakeet choice and reopens setup. Future explicit choices persist. Unsupported Apple APIs or languages retain a downloadable local-model fallback. This uses local app preferences, not browser cookies.
- Mac setup is 740 × 600 points, with core steps and completion controls outside a scroll view. Model and shortcut customization are in a separate setup sheet; long failure details have their own bounded popover. Accessibility insertion uses a bordered native button.
- Loading an existing model, downloading, checking files, and finishing setup have separate status text. The sidebar now observes the dictation controller directly so readiness updates immediately. Background controls are disabled and hidden from accessibility while onboarding is open.
- The website uses browser OS hints without login, storage, or server tracking. A manual OS choice always remains available. Mobile/tablet/ChromeOS/unknown visitors choose a desktop; browsers with JavaScript disabled see every installer. Chip architecture is not inferred: requirements remain explicit.
- The visible Mac guide includes the user-supplied Open Anyway screenshot and explains where the Security section is, including that it is not inside Files and Folders. Supporting disclosures have a flatter appearance. Homepage copy and buttons are refined while retaining the headline and interactive preview.

## Verified locally

- 63 XCTest tests plus one Swift Testing dictionary fixture passed. Selection tests cover migration over cached/saved Parakeet, later explicit preferences, unavailable Apple APIs, and an empty provider catalog.
- Native release build and DMG preflight passed on macOS 26.5.2 / Apple M2: build 11004, arm64, macOS 14 deployment target, bundle resources and strict ad-hoc signature integrity. Gatekeeper rejection remains expected for this non-notarized build.
- Actual native app opened with existing user data and selected Apple Speech, reached Ready, remained on Apple after restarting, opened/closed setup options, and completed onboarding. The sidebar correctly reported Ready. Setup's accessibility tree excluded background controls and had no core scroll area. The setup screenshot was taken against Settings to avoid publishing private transcripts; review screenshots remain local.
- Astro check/build, release-link source consistency, and three platform-policy tests passed. A local Chromium harness passed Mac/Windows/Linux, iPad desktop-mode, Android, and ChromeOS simulations; manual fragment selection and query override; no-JavaScript fallback; and light/dark 1440px desktop and 390px mobile checks, without horizontal overflow or JavaScript errors.
- Website finish reviewer disposition: **ship**, scoped to the six supplied website captures and changed source. The source release version advanced after those captures; layout did not change.

## Limits

This was an existing Mac installation with microphone and Accessibility already enabled and Apple speech files available. It does not prove fresh permission prompts, a first Apple asset download, real microphone accuracy, or cross-app insertion on another device. The owner reports opening the earlier beta on a macOS 26 work Mac; Windows/Linux physical-device results remain pending. Older macOS, Intel Macs (no installer), and ARM Windows/Linux remain as documented in the beta 3 record.

Release publication and live download checks are recorded below once the immutable beta 4 build completes.
