# Builder prompt: repair Dictate first, then offer GUI choices

You are working in an existing native macOS repository named **Dictate**. This is a
targeted repair and design exploration. Do not scaffold a replacement app and do not
rewrite working history, dictionary, correction, or persistence code.

Read these files first:

1. `docs/CURRENT_STATE_AUDIT.md`
2. `docs/ARCHITECTURE.md`
3. `README.md`
4. The current shortcut, controller, state-machine, delivery, overlay, model-provider,
   and build files named in the audit.

Inspect `git status` before editing. Preserve all user changes, local history,
dictionary data, bundle permissions, and existing repository history. The inspected
baseline was commit `a101474`; do not reset or discard later work. Never log or place
transcript text in test output.

## Scope boundary

The product has only:

- push-to-talk / click-to-toggle dictation into the currently focused text field;
- History;
- Dictionary;
- Settings needed for shortcuts, transcription models, permissions, and privacy.

Do not add a notetaker, document editor, meeting recorder, folders, projects, team
features, summaries, AI chat, cloud sync, or an LLM rewriting workflow.

This task has two gates:

1. **Correctness gate:** repair recording, stopping, cancellation, delivery, fallback,
   and model lifecycle; prove them with tests and manual checks.
2. **Design gate:** present distinct GUI directions and wait for the owner to choose.
   Do not redesign the main app before that choice. If you cannot ask for a choice,
   stop after the correctness gate and provide the GUI options without implementing
   one.

## Required user behavior

### Hold to talk

- Physical key-down starts exactly one recording.
- Keeping the key held continues recording.
- Physical key-up stops audio capture immediately and exactly once.
- Repeated `flagsChanged`, key repeat, or duplicated monitor events never start or
  finish an extra session.
- A release received during permission/model preparation is remembered. Once capture
  becomes active, it must stop immediately rather than recording indefinitely.
- Navigation between History, Dictionary, and Settings has no effect on recording or
  stopping. Controls always derive from one session model, not view lifecycle.

### Click to toggle

- First press-and-release starts recording.
- Second press-and-release stops it.
- Key-up always clears the physical pressed latch, even though it does not stop the
  first toggle session.
- Autorepeat is ignored.
- A third press while finalization is in progress does not create a new session.
- The in-app button and menu-bar command are ordinary toggles regardless of the
  selected physical-key mode: Start when idle; stop when recording; disabled with a
  `Finishing…` label while finalizing.

### Cancellation

- Escape cancels from both inside Dictate and while another app is frontmost. Install
  local and global monitors, or an equivalent reliable pair, and a menu command.
- Cancel stops capture, cancels the selected recognizer, prevents late completion,
  inserts nothing, and returns to idle.
- A hard maximum session duration provides a final safety net and produces a visible,
  recoverable error rather than an endless recording.

## Refactor the shortcut path into testable ordered semantics

Do not patch the current `isPressed` branches ad hoc. Introduce a pure reducer such as
`ShortcutGestureReducer` with explicit inputs (`physicalDown`, `physicalUp`, repeat,
mode, session phase) and outputs (`start`, `requestStop`, `none`). Unit-test it without
Quartz.

Feed Quartz and AppKit events through one serial ordered path. Do not create an
independent unstructured task for every press/release event. Keep the source event's
key code, side-specific modifier identity, event type, and selected shortcut. Check
the selected modifier flag—not “any of Command/Option/Fn”—when deciding whether that
specific key is still down.

Handle event-tap disabled/time-out events by re-enabling the tap. Define whether the
shortcut event is observed or consumed; consume only the configured shortcut and only
when needed. Avoid swallowing unrelated modifier keys.

Add tests for Right Option, Right Command, Fn, and custom shortcuts in both modes:

- down, duplicate down, up;
- down/up faster than preparation;
- modifier plus another modifier;
- release while navigation changes;
- key repeat;
- cancel before and after stop;
- event-tap fallback path;
- click-to-toggle start, release, second press, second release.

## Make stop/finalization explicit

Extend the session model to distinguish audio capture from recognition finalization.
A suitable state flow is:

```text
idle -> preparing -> recording -> finalizing -> delivering -> idle
                     |              |
                     +-- cancel ----+----> idle
```

Live partial text may be internal data; it does not need to appear in the global
overlay. A `stopRequested` event must be accepted from `preparing`, `recording`, and
live-transcribing phases. Stop is idempotent. `AudioCaptureService.stop()` must close
the ordered stream once. The state changes to `finalizing` immediately on key release,
before the recognizer finishes draining.

Keep finalization off the real-time audio callback and avoid expensive conversion or
model work monopolizing `MainActor`. Observable UI updates belong on the main actor;
audio processing and inference do not.

## Deliver text to the original cursor

Capture a durable delivery target before recording begins:

- focused AX element, when Accessibility permits it;
- external application's PID/bundle ID;
- whether the element supports selected-text replacement;
- never treat Dictate's main window, Settings, menu bar, or overlay as the intended
  external target.

Maintain the last valid external target when Dictate becomes frontmost, so starting
from the Dictate button can still deliver to the last editor only when that target is
still alive and valid. Do not guess a stale target silently; fall back to copy
recovery.

Delivery cascade:

1. If a valid AX target exists and selected text is settable, replace the selection.
2. Otherwise, if permission and a valid external app allow synthetic input, reactivate
   that app and use pasteboard plus Command-V.
3. Restore the previous pasteboard only if its change count still matches Dictate's
   temporary value. Never overwrite clipboard content the user created in the
   meantime.
4. If there is no valid target, permission is missing, or insertion cannot be
   established, preserve the final text in History and expose a pending copy action.

Do not report `.inserted` merely because Command-V events were posted. Use a richer
result such as:

```text
insertedViaAccessibility
insertedViaPaste
copiedForRecovery
noTarget
permissionMissing
deliveryFailed
```

The UI copy must be truthful: Accessibility is **Required for automatic insertion**,
not “Optional” if the promised behavior is paste-at-cursor. Without it, transcription
still works and the recovery flow must be excellent.

## Bottom overlay specification

Replace the current large transcript capsule with one compact non-activating status
pill. Do not show live transcription in it.

- Target footprint: approximately 160-200 points wide and 32-40 points high; adapt to
  localized content but do not become a transcript bar.
- Recording: coral dot, tiny 3-5 segment level motion, `Recording`.
- Finalizing: quiet progress motion, `Finishing`.
- Delivered: check, `Inserted`, dismiss after about one second.
- No target/failure: `Text ready` plus a real `Copy` button. Keep it available long
  enough to act on, and keep the transcript permanently recoverable in History.
- After Copy: show `Copied`, then dismiss. Starting a new recording may dismiss an old
  delivery notice but must not delete its History item.
- The panel must never become key or main. The Copy action must work without changing
  the target selection.
- Respect Reduce Motion; use opacity/level changes instead of looping travel.

Separate session state from transient delivery notice state. Returning the session to
idle must not instantly destroy the pending Copy UI.

## Complete the transcription-model integration

Do not add a second Parakeet adapter; finish the one that exists.

### Apple provider

Use the public API name in user-facing UI:

- Title: **Apple SpeechTranscriber**
- Secondary label: **macOS 26 · On-device · Streaming**

Do not invent an acoustic model marketing name that Apple's public API does not
expose. Continue using `SpeechAnalyzer` with `SpeechTranscriber` and explicit asset
availability/install states.

### Parakeet provider

Use:

- Title: **NVIDIA Parakeet TDT 0.6B v3**
- Secondary label: **FluidAudio · Core ML · On-device · 25 languages**

Use FluidAudio's supported v3 Core ML model path. At implementation time, inspect the
current FluidAudio release and migration notes. The baseline package uses `0.12.4`,
while later release lines have different download/model-hub APIs; pin one tested
version and update code and notices together. Do not claim the model is available
just because `canImport(FluidAudio)` is true.

Implement a real model lifecycle:

```text
notInstalled
downloading(progress)
validating
loading
ready
failed(actionableError)
```

- Provide Download, Retry, and Remove model controls.
- Display download/storage information using authoritative metadata; do not invent a
  size.
- Do not begin a Parakeet recording until the model is ready.
- Keep Apple SpeechTranscriber as a working default while Parakeet downloads.
- Check cancellation after the input stream closes, before/after resampling, before
  model load, and before/after inference. A cancelled Parakeet task must never deliver
  late text.
- Document the FluidAudio software license and NVIDIA model's CC BY 4.0 attribution in
  `THIRD_PARTY_NOTICES.md` and the distribution bundle as required.
- Parakeet can be batch-on-release if the selected FluidAudio API does not provide the
  desired stable streaming path. Label that behavior accurately; do not fake partials.

## Make the build prove Parakeet is present

The current `swift test` environment has a compiler/SDK revision mismatch. Fix the
documented toolchain selection instead of hiding it. Remove unconditional error
suppression such as `swift build ... || true` from the release path.

The final `.app` must be built through a configuration that actually resolves and
links FluidAudio. A manual fallback where `canImport(FluidAudio)` becomes false is not
an acceptable Parakeet build. Add a build-time or test assertion that the shipping
configuration contains the Parakeet provider, and inspect the final binary/bundle.

Run tests with a matching full Xcode toolchain and macOS 26 SDK. Report the exact
`xcode-select`/`DEVELOPER_DIR`, Swift version, SDK version, commands, and results.

## Correctness acceptance matrix

Complete and report every cell that can be tested:

| Mode | Start source | Target | Accessibility | Provider | Expected result |
|---|---|---|---|---|---|
| Hold | Right Command | TextEdit focused field | Allowed | Apple | release stops; text inserted once |
| Hold | Right Option | browser text field | Allowed | Apple | release stops; text inserted once |
| Hold | Fn | valid external field | Allowed | Apple | release stops; no emoji picker collision |
| Hold | shortcut | no editable target | Allowed | Apple | History saved; Copy pill shown |
| Hold | shortcut | target | Denied | Apple | History saved; permission/copy recovery shown |
| Toggle | shortcut twice | external field | Allowed | Apple | second press stops; one insertion |
| Toggle | in-app button twice | external field | Allowed | Apple | second click stops; one insertion |
| Either | any | any | any | Parakeet ready | stops, batch-finalizes, delivers once |
| Either | any | any | any | Parakeet absent | recording blocked; Download action shown |
| Either | any | any | any | either | Escape cancels; no insertion/history partial |

Also test silence, very short press/release, rapid repeated presses, app navigation
during recording, app deactivation/reactivation, recognizer error, model download
error, insertion failure, pasteboard mutation during fallback, and target app quit.

Do not call a cell verified unless it was actually exercised. Automated reducer and
state-machine tests are required, but they do not replace one real end-to-end test in
a separate editable app.

## UI handoff gate

The visual exploration now lives in `docs/theme-concepts/`, with seven complete boards
covering light mode, dark mode, and recorder overlays. Do not invent or implement a UI
direction during this repair task.

After the correctness gate passes, tell the owner the app is ready for the separate UI
phase. The owner will select finalists from the seven boards and use
`PROMPT_GPT_5_6_LUNA_UI.md` for implementation. Do not combine concepts or modify the
main visual structure before that selection.

## Handoff format

Return:

1. Root causes confirmed or revised with evidence.
2. Files changed and why.
3. Automated commands and exact results.
4. Manual acceptance-matrix results.
5. Any cells still requiring the owner's permission or physical microphone test.
6. Confirmation that the repository is ready for the separate theme-selection and UI
   phase.

Do not say “fixed” merely because source compiles. The task is fixed only when release
stops reliably in hold mode, a second press stops toggle mode, Escape cancels, text is
inserted at a real external cursor when permitted, and no-target text remains visibly
copyable and safe in History.
