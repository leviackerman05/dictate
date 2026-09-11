# Dictate privacy

This document describes the current open-source code and should be updated if
Dictate's data flows change.

## What stays on your computer

- Live microphone samples exist only in memory for the active recording and
  recognizer session. Dictate does not write raw microphone audio to disk or a
  temporary file. Stopping or cancelling closes the stream and releases the
  audio engine; Parakeet and Whisper discard their in-memory sample arrays when
  recognition returns.
- `history.json` and `dictionary.json` are stored in
  `~/Library/Application Support/Dictate/`.
- Shortcut, appearance, retention, selected model, onboarding, and other
  preferences use the app's local `UserDefaults` domain.
- The most recent completed but undelivered transcript is kept in local
  `UserDefaults` until insertion succeeds or the user explicitly copies or
  discards it. This recovery journal contains text, never audio.
- History is optional. Turning **Keep history** off affects future dictations;
  deleting existing history remains a separate action.
- On Windows, preferences, dictionary entries, optional history, pending
  recovery text, and downloaded models live under the platform application-data
  directory for `app.dictate.portable` (normally under `%APPDATA%`).

## Network access

Dictation and dictionary correction run locally after the selected model is
installed. Dictate's source contains no account, advertising, telemetry,
analytics, crash-reporting, or transcript-upload client.

Network access can still occur when a model is prepared:

- Apple's `SpeechAnalyzer` may ask macOS to install an Apple-managed speech
  asset.
- Parakeet models are downloaded by FluidAudio from the matching
  `FluidInference` model repository on Hugging Face.
- Whisper models are downloaded by WhisperKit from
  `argmaxinc/whisperkit-coreml` on Hugging Face.
- The Windows beta downloads pinned Whisper or NVIDIA Parakeet files from their
  public Hugging Face repositories and verifies SHA-256 checksums before loading
  them.

The benchmark command is deliberately offline-only and reports a model as
unavailable instead of downloading it.

## Permissions and pasteboard use

- Microphone permission is required to record.
- Accessibility permission is optional and is used to identify the focused
  editable element and insert text into other apps. Without it, completed text
  remains recoverable through Copy and History.
- For editors that require paste delivery, Dictate temporarily writes the
  completed transcript to the system pasteboard and sends Command-V. It restores
  the earlier pasteboard only if no other app changed it in the meantime.

Operational logs include state, app bundle identifiers, Accessibility roles,
and character counts for diagnosis. They do not intentionally include
transcript text, dictionary contents, raw audio, or pasteboard contents.

## Verification scope

The release-readiness audit records the searches and tests used to verify these
claims: [`docs/release-readiness-audit.md`](docs/release-readiness-audit.md).
Third-party code and downloadable model notices are listed in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## Windows beta

The Windows app processes audio in memory with CPU whisper.cpp or NVIDIA
Parakeet. Raw audio is not written to files. No audio, transcript, or dictionary
is sent with model-download requests.

`data.json` in the platform application-data directory for `app.dictate.portable`
contains preferences, dictionary, optional history, and pending recovery text.
Downloaded models are in its `models/` subdirectory. Windows normally uses
`%APPDATA%`.

Windows automatic insertion uses UI Automation plus Unicode input, preserving
the existing clipboard. Explicit Copy replaces its contents at the user's request.
The app does not install a global input-monitoring service or upload key events.
