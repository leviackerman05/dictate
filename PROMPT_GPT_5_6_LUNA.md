# Implementation prompt for GPT-5.6 Luna

You are the lead macOS engineer and product designer for a new application named
**Dictate**. Work directly in the repository you have been given. It begins with no
application source and no inherited implementation history. Build the app end to
end; do not stop after creating a plan or mockup.

## Non-negotiable clean-room rule

This is an original implementation inspired only by the general idea of
push-to-talk dictation.

- Do not clone, fetch, download, import, translate, or copy source code from
  `per-simmons/murmur-youtube` or any fork of it.
- Do not use its product name, bundle identifier, type names, file layout, prose,
  visual design, icons, assets, tests, commit history, contributor metadata, or
  distinctive “1980s tape recorder” styling.
- Do not present anyone else's work as the repository owner's work.
- You may implement commonplace product behavior from this specification using
  Apple platform documentation and independently written code.
- Before adding any third-party dependency, verify its license, record the license
  in `THIRD_PARTY_NOTICES.md`, and explain why the dependency is necessary. Prefer
  Apple frameworks and no dependency when practical.

The repository and product name must be **Dictate**. Use `Dictate` for Swift package,
target, executable, window, menus, docs, and test names. Use the development bundle
identifier `app.dictate.desktop`; make it configurable in one obvious place for a
future owner-controlled reverse-DNS identifier.

## Product thesis

Dictate turns speech into ready-to-use writing without moving a person's attention
away from the app they are working in. Hold a configurable key, speak, and release.
Dictate transcribes locally, applies deterministic personal corrections, then
inserts the result into the text field that was focused before recording.

The app is for writers, founders, researchers, and developers who dictate many short
fragments throughout the day. Its single most important quality is trust: it must be
private, predictable, fast, and visibly clear about what is happening.

## Platform and technical constraints

- macOS 26 or newer.
- Swift 6.2 with strict concurrency enabled.
- SwiftUI for application views; use AppKit only for capabilities SwiftUI cannot
  correctly provide, such as a non-activating overlay, global modifier-key events,
  accessibility insertion, and window behavior.
- Swift Package Manager project that produces a proper double-clickable `.app` via
  documented build/install commands.
- A normal macOS application with Dock icon, app menu, resizable main window, and
  Settings scene opened by Command-comma.
- A secondary menu bar item for state, start/stop, opening the app, and quitting.
- Local speech recognition through Apple's current on-device Speech framework APIs.
  Handle speech-model asset availability and installation as explicit UI states.
- No account, analytics, tracking, telemetry, advertisements, or cloud dependency.
- Store history and preferences locally. Never log transcript text by default.
- Do not add OpenAI or another LLM to v1. Keep a `TranscriptRewriter` protocol so a
  separately consented rewrite tier could be added later.

Use current official Apple documentation rather than guessing API signatures. If a
framework API differs from the specification, preserve the user-visible behavior
and document the platform constraint.

## Core recording behavior

Implement a deterministic state machine with these states:

`idle -> preparing -> listening -> transcribing -> inserting -> idle`

Any stage may transition to `failed(recoverableError)`, and cancellation must return
to `idle` without inserting partial text.

1. The default push-to-talk key is Right Option. Settings also offers Fn, Right
   Command, and a user-recorded non-conflicting shortcut.
2. Key-down starts capture; key-up finishes it. Repeated modifier events must not
   start duplicate sessions.
3. A clickable Record button in the main window and menu bar provides the same state
   transitions for accessibility and testing.
4. Capture microphone audio in order. Never create one unstructured task per audio
   buffer. Copy buffers before the audio callback returns and send them through one
   ordered stream.
5. Stream volatile transcription results into the UI while listening. Commit only
   final results to history.
6. Preserve the previously focused application and text element. The recording
   overlay must never become key or steal focus.
7. Insert through the macOS Accessibility API when supported. Provide a pasteboard
   plus synthetic Command-V fallback that restores the user's prior pasteboard
   contents after a short, safe delay. Surface insertion failures instead of losing
   the transcript.
8. Silence creates no history item and inserts nothing.
9. Escape cancels the active session.
10. Starting a new session while finalization is in progress is ignored with subtle
    visual feedback; it must not corrupt either session.

## Personal dictionary

People can teach Dictate names, jargon, and corrections. The dictionary must be
usable entirely from the UI and also portable as a human-readable JSON file.

Support two entry kinds:

1. **Vocabulary**: a preferred word or phrase used to bias speech recognition, such
   as a person's name or product name.
2. **Correction**: a heard form and a written form, such as `cloud code` ->
   `Claude Code`.

Requirements:

- Add, edit, delete, enable/disable, search, import, and export entries.
- Persist stable IDs, creation/update dates, entry kind, source phrase, target
  phrase where relevant, and enabled state.
- Validate empty entries and exact duplicates. Warn—but allow saving—when a pattern
  is so short or broad that it may alter ordinary prose.
- Pass only a bounded, relevance-ranked set of enabled vocabulary entries to the
  recognizer as contextual bias. Quiet audio must not invent dictionary words.
- After transcription, apply corrections case-insensitively, longest source first.
  Require full phrase boundaries. Between words, accept whitespace, no whitespace,
  or a hyphen, so `cloud code`, `CloudCode`, and `cloud-code` can map to
  `Claude Code` without changing `cloud`, `Cloudflare`, or a larger token.
- Correction output must not be recursively corrected during the same pass.
- Save an audit record with the history item listing each applied change. In the UI,
  show a compact “1 correction” disclosure that reveals before and after text.
- Isolate matching logic in a small, platform-independent Swift target and cover it
  with table-driven tests, including Unicode, punctuation, overlapping phrases,
  mixed case, glued words, hyphenated words, false positives, and empty input.

Define and document a versioned JSON schema. Imports must validate before replacing
or merging data and must never silently discard existing entries.

## History and data controls

Each completed item records an ID, timestamp, original transcript, corrected text,
duration, insertion result, and correction audit. Do not store raw audio.

- Search history by transcript text.
- Copy, retry insertion, pin, and delete an item.
- Select multiple items and delete them with confirmation.
- Group entries under Today, Yesterday, and calendar dates.
- Empty state: “Your dictated text will appear here.” followed by a working
  “Start recording” action.
- Privacy settings include “Keep history” and a retention choice: one day, one week,
  one month, forever. Turning history off affects future recordings and clearly
  offers to delete existing history as a separate confirmed action.
- Provide “Delete all history” and “Export history” actions.
- Use atomic local writes. A failed write must not destroy the last valid store.

## Original visual direction: the editorial voice desk

Do not imitate a recorder, cassette deck, retro appliance, neon audio tool, generic
SaaS dashboard, or translucent card collection. Dictate should feel like a precise,
contemporary writing instrument: part manuscript margin, part audio workspace.

The interface has one memorable signature called the **breath line**. While
recording, a thin animated line travels left-to-right through the active transcript,
rising and falling with the live microphone level. When the transcript is committed,
the animation decelerates and becomes the quiet horizontal rule beneath that history
entry. This connects spoken input to written output without drawing a conventional
waveform box. It is the only expressive animation; keep everything else restrained.

### Design tokens

Create `DesignSystem.swift` and express every view value through semantic tokens.
No one-off colors, radii, shadows, spacing, or animation durations in components.

Color:

- `canvas`: `#F3F6F5` — cool paper, never pure white.
- `surface`: `#FCFDFC` — reading surface.
- `ink`: `#18201E` — graphite with a green undertone.
- `mutedInk`: `#68726F` — secondary text that still passes contrast.
- `hairline`: `#D6DDDA` — dividers and settled breath lines.
- `action`: `#245E52` — deep mineral green for selection, focus, and primary action.
- `recording`: `#E05A47` — coral signal used only for active recording, destructive
  confirmation, and critical microphone errors. Never use it decoratively.

Typography:

- Use the system's New York face for large transcript excerpts and empty-state
  editorial copy. It makes the spoken words feel authored.
- Use SF Pro for navigation, buttons, settings, and body UI.
- Use SF Mono for durations, shortcut glyph descriptions, input level values, and
  diagnostics.
- Prefer Dynamic Type text styles and relative hierarchy over hard-coded point
  sizes. Cap transcript measure near 68 characters for readable lines.

Geometry and spacing:

- Base spacing unit: 4 points. Semantic steps: 4, 8, 12, 16, 24, 32, 48.
- Corner radii: 6 for fields, 10 for contextual surfaces, 16 only for the floating
  recording overlay. Do not make every region a rounded card.
- Use 1-pixel hairlines and almost no shadow. The floating overlay may use one soft,
  wide shadow to establish that it sits above the current app.
- The main content is a continuous reading surface separated by rules, not a grid of
  cards.
- Respect macOS window materials in the sidebar and toolbar, but keep the reading
  surface opaque for legibility.

Motion:

- Breath-line samples may respond quickly to input but render with smoothing to
  avoid jitter.
- Start: 160 ms ease-out. Settle: 420 ms critically damped spring. UI feedback:
  120–180 ms ease-out.
- Honor Reduce Motion by replacing travel with a local opacity and thickness change.
- Never use looping ambient motion when idle.

### Main window

Use a native macOS split view with a narrow source-list sidebar and a large reading
surface.

Sidebar:

- Wordmark “Dictate” at the top; no ornamental logo beside it.
- Navigation: History, Dictionary, Settings.
- A small status row at the bottom: permission state plus the active shortcut.

History reading surface:

- A compact toolbar contains search, a date filter, and a quiet overflow menu.
- The newest transcript sits first. Entries are typographic rows divided by a thin
  rule, not floating cards.
- Each row leads with timestamp and duration in SF Mono, then the corrected transcript
  in New York, followed by restrained actions revealed on hover or keyboard focus.
- Pinned entries use a slim mineral-green margin mark, not a badge.
- The active transcription appears at the top in place, with partial words gently
  changing opacity and the breath line crossing beneath the current baseline.

Dictionary surface:

- A two-column master-detail layout inside the reading surface.
- Left column: search, segmented filter (All, Vocabulary, Corrections), rows, and an
  Add button.
- Right column: a plain editing form with live examples of what will match. For
  corrections, render heard text, a right arrow, and written text as one readable
  sentence instead of two unrelated boxes.
- Risk warnings appear inline with a concrete example and do not block saving.

Settings:

- Also opens as a standard Settings scene with Command-comma.
- Sections: Shortcut, Speech, Insertion, Privacy, and About.
- Keep controls native. Do not custom-style toggles, popups, or permission buttons
  when standard macOS controls communicate better.

Recording overlay:

- Bottom center, narrow enough not to cover writing, and always non-activating.
- Opaque cool-paper capsule with a coral recording dot, live transcript fragment,
  and the breath line along its lower edge.
- Listening, processing, insertion success, recoverable failure, and cancellation
  must each be visually and accessibly distinct.
- It disappears promptly after success but remains on recoverable failure with
  “Copy text” and “Try inserting again” actions available from the main window or a
  notification, because the non-activating overlay itself must not steal focus.

### App icon

Create an original vector-based icon asset using macOS icon conventions. The concept
is a single dark-green editorial insertion caret intersected by one coral horizontal
breath line on the cool-paper field. It must remain recognizable at 16 pixels. Do not
use a microphone, waveform in a circle, cassette, quotation mark, or another app's
silhouette.

## Accessibility and keyboard use

- Every action must be reachable without a pointer.
- Provide sensible tab order, visible focus, menu commands, and VoiceOver labels,
  values, hints, and state announcements.
- Never communicate recording state with coral alone; pair it with text, shape, and
  an accessibility announcement.
- Meet WCAG AA contrast for text and meaningful controls.
- Support increased contrast, reduced transparency, Reduce Motion, and large text.
- Localize all user-facing strings through string catalogs. Ship English only for
  now, but do not embed English text throughout view code.

## Permissions and onboarding

Build a first-run window that explains and checks Microphone, Speech Recognition,
and Accessibility permissions one at a time. Each step states exactly why the grant
is needed, opens the correct System Settings pane when appropriate, rechecks when the
app returns to the foreground, and offers a meaningful retry path.

The app must remain useful as a transcript notebook without Accessibility access:
recording and copying work, but automatic insertion is disabled with a clear status.
Do not repeatedly nag after a person declines.

Permission state must be derived from platform APIs, not a stored “completed” flag.
Never run broad privacy-reset commands in build scripts or documentation.

## Architecture

Choose clear domain names independent of the reference project. A suitable original
module map is:

```text
Sources/
  DictateApp/             app entry, scenes, commands, dependency composition
  Capture/                microphone session and ordered audio stream
  Recognition/            on-device recognizer adapter and model availability
  Session/                dictation state machine and session orchestration
  Delivery/               focus snapshot and text insertion strategies
  Lexicon/                dictionary models, store, matcher, import/export
  Archive/                transcript history models, store, retention
  Interface/              main window, overlay, onboarding, settings, menu bar
  DesignSystem/           tokens, reusable primitives, icon source
Tests/
  LexiconTests/
  SessionTests/
  ArchiveTests/
  InterfaceTests/
```

Use protocols at system boundaries and constructor injection so microphone,
recognizer, clock, persistence, permissions, and insertion can be replaced by fakes.
Keep observable UI state on the main actor. Keep audio callbacks lean and move work
off the real-time audio thread. Avoid shared mutable global state.

Add structured OSLog categories, but redact transcripts, dictionary contents, and
pasteboard data. Errors exposed to the interface should be typed and actionable.

## Repository deliverables

Create all source and resource files needed to build and use the app, plus:

- `README.md`: product description, requirements, build, test, install, uninstall,
  permissions, privacy, troubleshooting, and limitations.
- `docs/DESIGN_SYSTEM.md`: tokens, component rules, window wireframes, accessibility
  behavior, and breath-line motion specification.
- `docs/ARCHITECTURE.md`: state machine, data flow, concurrency boundaries, storage,
  and insertion strategy.
- `docs/DICTIONARY_SCHEMA.md`: versioned JSON schema and correction algorithm.
- `PRIVACY.md`: plain-language local-data policy.
- `THIRD_PARTY_NOTICES.md`: even if it states no third-party runtime dependencies.
- `.gitignore`, SwiftFormat/SwiftLint configuration only if the tool is actually used,
  and a small `Makefile` or scripts with safe, narrowly scoped commands.
- A GitHub Actions workflow that builds and runs tests on an available macOS runner.
- Unit tests and a small set of screenshot/UI tests for idle, recording, empty
  history, populated history, dictionary editor, and denied permissions.

Do not commit generated build products, downloaded speech models, personal
dictionaries, transcripts, provisioning profiles, signing identities, or secrets.

## Implementation order

Work continuously through these milestones. Do not ask for design approval unless a
platform constraint makes the brief impossible.

1. Inspect the empty repository and available Xcode/Swift toolchain.
2. Write a short execution checklist and the design-system document. Include compact
   ASCII wireframes of the main window, dictionary, Settings, and overlay.
3. Scaffold the Swift package/app bundle and tests with the `Dictate` identity.
4. Implement and test the Lexicon correction engine and atomic stores.
5. Implement the session state machine with fakes and exhaustive transition tests.
6. Implement capture, on-device recognition, permissions, focus snapshot, and text
   delivery adapters.
7. Implement the complete interface from semantic tokens, including all empty,
   loading, recording, processing, success, denied, and failure states.
8. Add onboarding, menu commands, menu bar item, Settings, localization scaffolding,
   app icon, privacy controls, and retention.
9. Build the `.app`, run all tests, run static checks, and fix every failure you can
   reproduce.
10. Review the running interface at multiple window sizes and accessibility settings.
    Capture screenshots for visual verification when tools allow it.
11. Audit the repository for inherited names/identifiers, sensitive data, copied
    material, placeholder UI, hard-coded design values, and unfinished stubs.
12. Update README and docs to match the implementation exactly.

## Definition of done

Do not call the task complete until all of the following are true:

- A fresh checkout builds and tests with documented commands.
- The resulting app is named Dictate everywhere and has no reference-project names,
  contributors, remotes, identifiers, assets, or source.
- A person can complete onboarding, hold the shortcut, speak, release, see live text,
  receive corrected text in the previously focused field, and find the item in
  history.
- The overlay never becomes key and automatic insertion does not change the focused
  destination.
- Dictionary matching passes its complete table-driven suite and reports correction
  audits in history.
- Denied or missing permissions have working recovery paths.
- User history, dictionary content, and pasteboard data do not appear in logs.
- The interface follows the documented tokens, is keyboard/VoiceOver operable, honors
  macOS accessibility preferences, and has no generic placeholder styling.
- The app icon and breath-line interaction are original and visually coherent at
  shipping quality.
- README accurately distinguishes verified behavior from remaining limitations.

At the end, provide a concise handoff containing the implemented features, exact
commands run and their results, unverified behavior requiring a human microphone or
permission test, and the paths to the built `.app` and key documentation. Do not
claim a check passed unless you actually ran it.

