# Dictate current-state audit

Date: 2026-08-23
Baseline inspected: `a101474` (`Fix recording pipeline and add local model providers`)

This is a diagnosis and builder handoff, not a replacement implementation. The
existing repository, local history, dictionary data, and recent commits must be
preserved.

## What was inspected

- The running Dictate app on History, Dictionary, and Settings.
- Shortcut monitoring, dictation orchestration, state machine, audio capture,
  Apple recognition, Parakeet integration, focus capture, insertion, overlay,
  Settings, build scripts, tests, and current documentation.
- The app's current visual composition at its active window size.

## What currently works

- The app launches as Dictate and exposes History, Dictionary, and Settings.
- Microphone capture and Apple SpeechTranscriber produce accurate transcripts.
- Completed transcripts reach local History. Two recent recordings were visible in
  the running app, so capture and recognition are not the primary failure.
- Dictionary and history persistence structures exist.
- A non-activating bottom overlay exists.
- FluidAudio and a Parakeet adapter have been started in source.

## Primary product failures

### 1. Click-to-toggle cannot toggle off

`ShortcutMonitor` sets `isPressed = true` on the first key-down. In click-to-toggle
mode, key-up deliberately does not call `finishIfNeeded()`, but it also never clears
the pressed latch. The second key-down therefore fails the `!isPressed` condition and
does nothing. This directly explains a recording that starts and cannot be stopped by
pressing the shortcut again.

Relevant area: `Sources/Dictate/ShortcutSupport.swift`, especially the event handlers
around lines 153-208.

### 2. Shortcut events are reordered through unstructured tasks

Each Quartz/AppKit event creates a separate `Task { @MainActor ... }`. Press and
release are logically ordered input events, but this implementation has no explicit
serial event channel or testable reducer. The UI actor is also doing recognition
feeding and conversion work. A delayed or reordered release can leave the latch set.

Relevant area: `Sources/Dictate/ShortcutSupport.swift`, around lines 99-121.

### 3. Hold release is not a first-class session event

`DictationController.finish()` only stops audio when the published state is exactly
`listening` or `transcribing`. It has no queued stop for a release received during
`preparing`, no `finalizing` state, and no idempotent stop request. The UI remains in
an active recording state while the recognizer drains and finalizes, which is why a
Finish recording control can appear after the physical key was already released.

Relevant area: `Sources/Dictate/DictationController.swift`, lines 97-101, and
`Sources/DictateCore/Session/DictationStateMachine.swift`.

### 4. Escape does not cancel in every app context

The app installs only a global Escape monitor. Global monitors do not replace the
need for a local monitor when Dictate itself is active. There is also no menu command
or visible recovery path guaranteed for a stuck session.

Relevant area: `Sources/Dictate/AppDelegate.swift`, around lines 32-36.

### 5. Automatic insertion is disabled by the current permission state

The running Settings screen showed Accessibility as `Optional`. The controller passes
that Boolean into delivery. When it is false, `FocusSnapshotService` calls `copyOnly`
instead of attempting insertion. This is why accurate text reaches History but does
not appear at the cursor.

The Settings copy says a pasteboard fallback will be used “when possible,” but the
implementation does not attempt that fallback in this permission state. The UI and
behavior contradict one another.

Relevant area: `Sources/Dictate/DictationController.swift`, lines 194-203, and
`Sources/Dictate/Delivery/TextDeliveryService.swift`.

### 6. Delivery success is over-reported

The pasteboard fallback posts Command-V and immediately returns `.inserted`; it does
not know whether a target existed or whether the target accepted the paste. It also
captures whichever app is frontmost at recording start, which can be Dictate itself
when recording begins from the UI. A durable “last external focus” target does not
exist.

### 7. Copy-only recovery disappears immediately

For `.copiedOnly`, the controller sets a feedback string, sends insertion success,
resets to idle, clears live state, and causes the overlay to order out. The feedback
is therefore not presented as a persistent, clickable recovery. There is no bottom
message with a Copy button, even though the transcript remains available in History.

Relevant area: `Sources/Dictate/DictationController.swift`, lines 126-156, and
`Sources/Dictate/AppDelegate.swift`'s overlay state handling.

### 8. The overlay is larger and noisier than requested

The current overlay contains status, a full one-line live transcript, recording dot,
and breath line. The requested overlay should be much smaller and must not show live
transcription text.

Relevant area: `Sources/Dictate/OverlayView.swift`.

### 9. Parakeet is only partially integrated

- `modelIsAvailable` is `true` whenever FluidAudio can be imported; it does not mean
  model assets exist or are loaded.
- Model download happens implicitly inside the first transcription, with no explicit
  download state, progress, retry, or storage information.
- `cancel()` is a no-op. Cancellation after the input stream closes can still proceed
  into resampling, model load, and inference.
- The manual `swiftc` fallback build does not link FluidAudio. In that build,
  `canImport(FluidAudio)` is false, so Parakeet is compiled out even though it is
  declared in `Package.swift`.
- The package currently requests FluidAudio from `0.12.4`, while the inspected
  upstream release line has advanced and includes newer model download APIs. The
  builder must migrate intentionally, not just change the version and guess APIs.

Relevant areas: `Sources/Dictate/Recognition/ParakeetRecognitionService.swift`,
`Package.swift`, and `Scripts/build-app.sh`.

### 10. The build is not presently reproducible with the selected command-line toolchain

`swift test` failed during this audit because the installed compiler and macOS SDK
revisions do not match. The build script suppresses an initial SwiftPM failure with
`|| true` and falls back to a manual build that omits the FluidAudio product. A green
manual app bundle therefore does not prove that the Parakeet configuration builds.

## Why the interface feels like a stock Mac app

The visual identity is dominated by platform defaults:

- `NavigationSplitView` with a fixed source-list sidebar.
- Standard blue selected rows and SF Symbols.
- `.listStyle(.sidebar)` and `.listStyle(.plain)`.
- A grouped `Form` for Settings.
- Conventional toolbar search and ellipsis menus.
- History rendered as standard list rows separated by rules.

The serif transcript type and custom colors do not outweigh that structure. A real
redesign needs a different information architecture and window composition, not a
new tint on the same split view.

## GUI directions from the initial audit

This initial text study and the later seven-board exploration are archived. The owner
approved one consolidated direction, represented by the shipped application and the
boards in `docs/final-design/`.

All directions keep exactly two primary destinations: History and Dictionary.
Settings remains secondary, opened from a gear/menu or Command-comma. None adds a
notetaker, editor, meeting bot, folders, projects, or AI chat.

### Option A — Quiet Ribbon (recommended)

Audience: people dictating short fragments throughout the day.
Single job: verify that speech landed, then get back to work.

- Structure: remove the permanent source-list sidebar. Use a slim custom top band
  with Dictate at left, History/Dictionary in the center, and model/settings status at
  right. History is one centered continuous stream, not a platform List.
- Signature: a narrow colored ribbon at the left of each transcript carries time,
  insertion result, and correction count. It compresses the metadata without making
  the transcript look like a note card.
- Palette: Mist `#F1F3F8`, Paper `#FCFCFE`, Ink `#161922`, Indigo `#5965E8`, Coral
  `#F05F52`, Quiet `#747A8A`.
- Type: Instrument Sans or system sans for UI; Literata for transcript text; SF Mono
  for time and duration. Bundle fonts only if licensing and app size are acceptable.
- Tradeoff: least “Mac-like” while staying calm and usable; best general direction.

### Option B — Night Signal

- Structure: a 64-point icon rail, dense full-height history canvas, and a slide-over
  dictionary inspector. No title/sidebar split view.
- Signature: transcript rows brighten from dim navy to clear white as insertion moves
  from processing to delivered; the color change is state, not decoration.
- Palette: Deep Navy `#0D1321`, Panel `#151D2E`, Text `#EDF2FF`, Cyan `#55D8D0`,
  Signal Orange `#FF7657`, Muted `#8C98B3`.
- Type: Söhne-like system grotesque plus SF Mono; no serif.
- Tradeoff: distinctive and focused, but a permanent dark interface is less neutral
  for long reading sessions.

### Option C — Color Index

- Structure: full-width canvas with a horizontal day index across the top. Each day
  opens as a typographic column. Dictionary is a searchable overlay sheet rather than
  a second nested sidebar.
- Signature: days receive a restrained rotating index color, while transcript text
  remains black on a neutral surface. Color communicates chronology.
- Palette: Chalk `#F7F6F2`, Ink `#11110F`, Cobalt `#3155D9`, Marigold `#E5AA2F`,
  Moss `#4E7C62`, Error `#C94B43`.
- Type: system rounded display labels, neutral sans body, SF Mono metadata.
- Tradeoff: more expressive and memorable; requires careful accessibility work so
  chronology never depends on color alone.

### Option D — Focus Deck

- Structure: compact landscape window with a persistent command strip across the
  bottom, History above it, and Dictionary opening as a right-side deck. Large empty
  areas and fewer visible controls.
- Signature: the command strip mirrors the global recording pill, so the same visual
  object lives inside and outside the app.
- Palette: Bone `#ECE9E1`, Carbon `#20211F`, Slate `#646A68`, Electric Blue `#2E6BFF`,
  Record Red `#E35247`, White `#FFFFFF`.
- Type: condensed sans for navigation, humanist sans for transcripts, tabular mono
  for metadata.
- Tradeoff: feels most like a standalone product; the compact deck gives less room
  to browse long history.

## Recommended execution order

1. Add diagnostics and failing tests for current behavior.
2. Repair ordered shortcut semantics and cancellation.
3. Add an explicit finalizing state and idempotent stop requests.
4. Repair focus capture, insertion, and copy recovery.
5. Complete Parakeet model lifecycle and reproducible dependency linking.
6. Run the full interaction matrix with a real editable target app.
7. Implement the approved Color Index system, Signal Pebble, and Dictate identity
   represented in `docs/final-design/`.
