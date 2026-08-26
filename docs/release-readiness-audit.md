# Release-readiness audit

Audit date: 2026-08-26

Target: Apple silicon, macOS 26 or newer

Scope: local repository only; no deployment, publishing, signing identity, or
notarization submission was performed.

## Outcome

The repository now has a reproducible offline recognition benchmark, expanded
policy and correction tests, explicit permission and storage explanations, a
privacy/data-flow record, and a local release-package preflight. The checks run
during this audit passed:

- `swift test`: 55 tests, 0 failures.
- `./Scripts/run-benchmark.sh --help`: release harness built and displayed its
  interface without preparing or downloading a model.
- Missing-audio error probe: exited 3 and wrote valid JSON and Markdown with a
  per-engine `failed` status and explicit AVFAudio error, without downloading a
  model.
- `./Scripts/release-preflight.sh`: passed on Apple silicon with Xcode 26.5,
  Swift 6.3.3, and the macOS 26.5 SDK.
- Package result: arm64, minimum macOS 26.0, bundle ID
  `app.dictate.desktop`, version 1.0 (1), valid ad-hoc signature, valid DMG and
  SHA-256 checksum.
- Gatekeeper result: not accepted, which is expected because the community
  build is not Developer ID signed or notarized.

The app is not claimed to be Developer ID signed, notarized, App Store reviewed,
or benchmarked for accuracy. Those claims require credentials or representative
audio that were deliberately not supplied or invented.

## Runtime map

### Recording and recognition

1. `ShortcutGestureReducer` converts key-down/key-up events into start, finish,
   or cancel actions for hold-to-talk and click-to-toggle.
2. `AppModel` forwards the action to `DictationController`.
3. `AudioCaptureService` creates a fresh `AVAudioEngine` for the session and
   streams mono float samples through an `AsyncStream`. It writes no audio file.
4. The selected recognizer consumes the stream:
   - Apple: `SpeechAnalyzer` with the OS-managed speech asset.
   - Parakeet: FluidAudio with the selected locally cached Core ML model.
   - Whisper: WhisperKit with the selected locally cached Core ML model.
5. Cancellation is checked before, during, and after inference. FluidAudio and
   WhisperKit do not expose an interrupt for every in-flight Core ML operation;
   when cancellation cannot stop the operation, its result is discarded.

### Correction, delivery, and recovery

1. The settled recognizer transcript is retained as the raw transcript.
2. `CorrectionMatcher` applies enabled dictionary rules as deterministic,
   non-recursive post-processing. Longest and higher-priority matches win; equal
   matches use a stable content/ID key instead of input array order.
3. The corrected transcript is saved to `SessionRecoveryJournal` before external
   delivery so an unavailable target or delivery failure does not erase it.
4. Focus policy requires a currently focused editable target. It does not fall
   back to an old field when focus is absent, changed, closed, or unavailable.
5. Native fields use Accessibility insertion first. WebKit/Electron editors use
   guarded paste first because their selected-text Accessibility bridges are
   often incomplete.
6. Pasteboard restoration occurs only if the temporary transcript is still the
   current pasteboard value. A concurrent user/app clipboard change is preserved.
7. On failure, the completed text remains available through Copy, Retry, and
   History when history is enabled. Recovery clears only after successful
   insertion or an explicit copy/discard action.

### Persistence

- History: `~/Library/Application Support/Dictate/history.json`.
- Dictionary: `~/Library/Application Support/Dictate/dictionary.json`.
- Preferences and the latest recoverable transcript: local `UserDefaults`.
- Raw microphone audio: memory only; no app or temporary audio file path exists
  in the capture/recognition flow.

## A. Reproducible benchmark

`Scripts/run-benchmark.sh` builds the production executable and launches its
`benchmark` command. Required input is an audio file and one or more engine IDs;
a UTF-8 reference transcript is optional.

```sh
make benchmark ARGS='--audio /path/sample.wav \
  --reference /path/reference.txt \
  --engine all \
  --json /tmp/dictate-benchmark.json \
  --markdown /tmp/dictate-benchmark.md'
```

Both reports include schema version, timestamp, Mac model, architecture,
processor, memory, logical CPU count, OS, audio filename/duration, engine/model,
recognition duration, real-time factor, normalized word error rate when a
reference is supplied, raw recognizer output, status, and error detail.

The harness uses the production recognizer implementations but explicitly
refuses model downloads. Missing local assets are reported as `unavailable`.
Dictionary correction and text insertion are excluded. No audio fixture,
copyrighted recording, benchmark report, or fabricated result is checked in.
`WordErrorRate` has unit coverage for substitutions, insertions, deletions,
case, punctuation, diacritics, and an empty reference.

## B. Focused-field and insertion verification

Automated tests cover:

- the original field remaining focused;
- switching fields before completion;
- closed, missing, and unavailable targets;
- absence of a current editable target;
- partial delivery failure and complete text recovery;
- Accessibility missing or revoked;
- guarded pasteboard restoration;
- Unicode, punctuation, multiline, numeric, and long recovery payloads;
- explicit paste-first policy for WebKit/Electron roles;
- no fallback to preserved targets from global shortcut, main window, menu bar,
  or retry paths.

The repository does not pretend that a pure SwiftPM test can validate another
process's live Accessibility tree. Manual checks for native, browser,
Electron/WebKit, secure, and unsupported fields remain in
`docs/evidence/manual-compatibility-matrix.md`. Run that matrix on the packaged
build before publishing a release.

## C. Dictionary correction verification

Tests cover exact and case-insensitive phrases, capitalization, names, longest
overlap, priority, punctuation, separators, Unicode boundaries, unrelated words,
numbers, non-recursive replacement, deterministic equal-priority ordering, and
duplicate normalization. The history model preserves both raw and corrected
text; audits identify each applied rule.

Apple can receive relevant vocabulary as recognition context. Parakeet and
Whisper currently rely on the shared post-recognition correction step, so the
personal dictionary remains deterministic across engines.

## D. Permission UX

Before prompting, onboarding now explains:

- Microphone is required and raw audio remains in memory only for the session.
- Accessibility is optional and enables automatic insertion.
- Without Accessibility, completed text remains available to Copy or History.
- History/dictionary storage and local pending-recovery/preferences storage.
- A direct link to the repository privacy policy.

The same storage and policy link is available in Settings. Declining
Accessibility no longer causes an insertion attempt to display the system prompt
again. Only an explicit permission action opens or prompts System Settings, and
the user can continue onboarding without automatic insertion.

## E. Privacy verification

Source and dependency inspection found no app-level account, analytics,
telemetry, crash-reporting, advertising, or transcript-upload client. Logging
records lifecycle state, bundle IDs, Accessibility roles, frames, counts, and
errors, not transcript or pasteboard content.

Expected network-capable paths are model preparation only:

- Apple-managed `SpeechAnalyzer` assets;
- FluidAudio downloads from the selected `FluidInference` Hugging Face repo;
- WhisperKit downloads from `argmaxinc/whisperkit-coreml`.

The benchmark's offline preparation methods check installed assets and never
enter those download paths. `PRIVACY.md` and `THIRD_PARTY_NOTICES.md` now record
these distinctions and the resolved package/model repositories. Downloaded model
artifacts are excluded from the app bundle by preflight.

Atomic JSON persistence can create a short-lived sibling file during the atomic
replace operation; this contains history or dictionary JSON, not raw audio. No
raw-audio temporary cleanup routine is necessary because capture has no disk
write path. A debug assertion verifies that the audio engine, sink, and running
flag are cleared after `stop()`.

## F. Packaging and release preflight

`make preflight` now performs these local checks:

- full Xcode and macOS 26 SDK;
- release build and app assembly;
- arm64-only executable and minimum macOS 26.0;
- bundle ID, marketing version, build version, package metadata;
- Microphone and Speech Recognition usage descriptions;
- icon, menu glyph, localization, and SwiftPM resource bundle;
- absence of bundled Core ML model assets;
- code-signature structural verification and truthful signature classification;
- local Gatekeeper assessment without changing system security;
- DMG metadata, mounted app, and Applications symlink;
- SHA-256 checksum generation.

The release workflow calls this same preflight before uploading the DMG and
checksum. No Apple certificate, notary profile, App Store credential, GitHub
token, or Vercel credential was requested, created, or changed during this
audit. Developer ID signing and notarization remain intentionally unresolved.

## G. Documentation

The README now states the platform, local data behavior, optional Accessibility
behavior, model-download boundary, current unsigned/unnotarized state, source
build command, preflight command, benchmark format, test scope, MIT license, and
links to the installation, privacy, third-party, compatibility, and audit docs.
Only existing repository screenshots are used.

## Remaining release gates

Before publishing a public build:

1. Run the live compatibility matrix on the exact packaged app, including at
   least one native editor, browser editor, and Electron/WebKit editor.
2. Run the benchmark with a creator-owned or permissively licensed fixture and
   preserve its provenance beside any published result.
3. Review every selected model card/license at the resolved download version
   before redistributing model artifacts. Current packaging does not redistribute
   them.
4. Decide whether to enroll in Apple's Developer Program. If credentials become
   available, add a separate Developer ID signing/notarization path and verify it
   without weakening the community path.
5. Confirm a GitHub release actually contains both DMG and checksum before using
   a direct `releases/latest/download` link.

Suggested repository topics (not applied): `macos`, `swift`, `dictation`,
`speech-recognition`, `local-first`, `whisper`, `parakeet`, `coreml`,
`accessibility`, `apple-silicon`.
