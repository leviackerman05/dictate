# GPT-5.6 Luna prompt: implement the selected Dictate UI theme

Use this message with GPT-5.6 Luna after replacing the selection placeholders:

```text
Implement the Dictate UI theme phase in this existing repository.
Primary selected theme: [THEME NAME AND NUMBER]
Optional second theme: [THEME NAME AND NUMBER, or NONE]

Read PROMPT_GPT_5_6_LUNA_UI.md and follow it exactly. Treat the corresponding images
under docs/theme-concepts/ as visual references at original detail. Do not change the
recording, recognition, insertion, dictionary-matching, or persistence behavior unless
a compilation error directly caused by the UI work requires a minimal compatibility
change.
```

The remainder of this document is the implementation specification.

## Role and outcome

You are the senior product designer and native macOS UI engineer for **Dictate**.
Implement the selected visual theme—or two independent selectable themes—across the
entire existing app. Each selected theme must have a deliberately designed light mode
and dark mode.

This is an implementation task, not another concept exercise. Work directly in the
existing repository, preserve current history and dictionary data, and complete the
UI end to end. Do not scaffold another application or rewrite the functional core.

If the selection placeholders above have not been replaced with valid theme names,
stop and ask the owner to select from the seven numbered boards. Do not choose silently.

## Read before editing

1. `PRODUCT.md`
2. `docs/CURRENT_STATE_AUDIT.md`
3. `PROMPT_BUILDER_REPAIR_AND_GUI.md`
4. `docs/theme-concepts/README.md`
5. The selected PNG board or boards under `docs/theme-concepts/`
6. `Sources/Dictate/DesignSystem.swift`
7. All current SwiftUI/AppKit UI files, including the main shell, History, Dictionary,
   Settings, onboarding, overlay controller/view, menu bar, and accessibility helpers.

Inspect `git status`, current tests, and the running app before editing. Preserve user
changes and do not reset, clean, or replace unrelated work.

The concept images are visual authority for composition, density, typography
character, palette, and component relationships. They are not behavioral authority:
generated labels, counts, example controls, dates, or model names may be fictional or
misspelled. Use the current code and product documents for factual copy and behavior.

## Product boundary

Dictate is a focused input utility:

- hold a shortcut, speak, release, and insert at the original cursor;
- click-to-toggle as an optional recording behavior;
- History for safe recovery and past transcripts;
- Dictionary for vocabulary and deterministic correction pairs;
- secondary Settings for shortcut, models, permissions, privacy, appearance, and
  theme.

Do not add a notetaker, text editor, meetings, folders, projects, documents, AI chat,
summaries, rewriting, collaboration, or cloud sync.

The UI must not regress shortcut monitoring, recording finalization, cancellation,
focus capture, insertion, copy recovery, Apple SpeechTranscriber, Parakeet, History,
or Dictionary behavior.

## Theme selection model

Add two independent persisted preferences:

1. `AppTheme`: the selected visual theme.
2. `AppearancePreference`: `system`, `light`, or `dark`.

If one theme was selected, ship that theme and its light/dark variants; do not expose
a fake theme chooser containing unfinished concepts. If two themes were selected,
ship exactly those two and add a visual Theme chooser in Settings. Switching themes
must update the main window, Dictionary, Settings, onboarding, empty/error states, and
the global recorder overlay without relaunching.

Never blend two selected concepts into one hybrid. Each has its own coherent tokens,
layout grammar, materials, typography, and motion. Shared product behavior and domain
components remain common.

## Design-system architecture

Replace the single static palette with a semantic theme system. Use names based on
meaning, never hue:

```text
background
surface
surfaceRaised
surfaceSelected
textPrimary
textSecondary
textDisabled
border
borderStrong
action
actionText
recording
success
warning
failure
focusRing
overlayBackground
overlayText
overlayBorder
```

Also theme:

- typography roles: display, navigation, transcript, body, label, metadata;
- spacing rhythm;
- radii and border widths;
- shadows/materials;
- icons and status marks;
- selection, hover, press, focus, disabled, and destructive states;
- motion durations, curves, and Reduce Motion alternatives;
- main-window structure and recorder-overlay geometry.

Use an environment-injected `ThemeContext` or equivalent so leaf views consume
semantic tokens. Do not scatter `if theme == ...` color branches throughout views.

Tokens alone are insufficient for structurally different concepts. When selected
themes have genuinely different composition—such as Focus Deck versus One-Bit
Modern—create theme-specific shell/layout implementations behind shared History,
Dictionary, Settings, and session view models. Do not force every theme through the
old `NavigationSplitView` merely to maximize code reuse.

Centralize all values. No hard-coded RGB values, font sizes, radii, shadows, or
animation durations inside feature views.

## Shared surface requirements

Every selected theme, in both light and dark mode, must cover:

- main application shell and window chrome treatment;
- History populated, empty, searching, selected, pinned, correction-audit, copied,
  insertion-failed, and multi-delete states;
- Dictionary empty, populated, searching, filtered, selected, editing, adding,
  validation warning, import/export notice, enabled, and disabled states;
- Settings sections and all controls;
- onboarding and Microphone/Accessibility permission states;
- Apple SpeechTranscriber and Parakeet model selection, unavailable, downloading,
  validating, loading, ready, retry, and failure states;
- menus, tooltips, keyboard focus, contextual actions, confirmation dialogs, and
  transient notices;
- recorder overlay states: preparing, recording, finalizing, inserted, text ready,
  copied, cancelled, and failed.

Native sheets, alerts, context menus, and the menu bar may retain platform behavior,
but their labels, surrounding presentation, icons, and launch points must feel
intentional within the theme.

## Recorder overlay is part of the theme

The global recorder must be designed at the same time as the main app, not after it.

- Non-activating `NSPanel`; never becomes key or main.
- Approximately 160-200 points wide and 32-40 points high.
- Never show live transcript text.
- Recording: non-color status cue, small level response, and `Recording`.
- Finalizing: restrained progress cue and `Finishing`.
- Success: check/status mark and `Inserted`, visible briefly.
- Recovery: `Text ready` and a real `Copy` button; remains actionable and text remains
  safe in History.
- After copy: `Copied`, then dismiss.
- Failure: concise actionable state without exposing transcript content.
- Light and dark variants must be designed independently and pass contrast.
- Theme changes update the overlay even if the main window is closed.
- Respect Reduce Motion by substituting opacity, fill, or discrete state changes.

Use the selected concept's signature consistently. Examples:

- Quiet Ribbon: metadata ribbon becomes the recorder's slim leading status band.
- Night Signal: cyan/orange signal ticks become the level response.
- Color Index: the current date color becomes the recorder edge, with labels retained.
- Focus Deck: the bottom command deck compresses into the global recorder strip.
- One-Bit Modern: one-pixel frame, inverted status, and integer-scale indicators.
- Iridescent Edge: spectral hairline is the sole flourish around an opaque pill.
- Signal Steps: the step sequence compresses into the level/finalization timeline.

## Theme specifications

Implement only the selected theme or themes, but preserve this written direction when
rationalizing details from the mockup.

### 1. Quiet Ribbon

- Structure: slim top band; History/Dictionary centered; no permanent sidebar;
  continuous centered history stream; narrow metadata ribbons.
- Light: Mist `#F1F3F8`, Paper `#FCFCFE`, Ink `#161922`, Indigo `#5965E8`, Coral
  `#F05F52`, Quiet `#747A8A`.
- Dark: Midnight `#111724`, Raised `#192231`, Text `#F0F2F8`, Indigo `#8A8FFF`, Coral
  `#F57468`, Quiet `#9299AA`.
- Type: humanist sans UI, literary serif transcript, mono metadata.
- Signature: metadata ribbon carries time, duration, insertion status, and corrections.

### 2. Night Signal

- Structure: narrow icon rail; dense full-height signal log; oversized timestamps;
  Dictionary as integrated slide-over inspector.
- Light: Ice `#F4F7FB`, White `#FFFFFF`, Navy `#101827`, Cyan `#1FB7AE`, Orange
  `#FF7657`, Steel `#6F7C95`.
- Dark: Deep Navy `#0D1321`, Panel `#151D2E`, Text `#EDF2FF`, Cyan `#55D8D0`, Orange
  `#FF7657`, Muted `#8C98B3`.
- Type: sharp grotesque, large tabular timestamps, mono utility.
- Signature: transcript luminance and signal marks communicate delivery state.

### 3. Color Index

- Structure: horizontal date index; full-width daily columns; Dictionary as searchable
  overlay sheet with indexed filters.
- Light: Chalk `#F7F6F2`, Ink `#11110F`, Cobalt `#3155D9`, Marigold `#E5AA2F`, Moss
  `#4E7C62`, Error `#C94B43`.
- Dark: Soot `#151512`, Charcoal `#22221D`, Bone `#F3F0E7`, Cobalt `#7390FF`, Gold
  `#F2C25D`, Sage `#7DB492`.
- Type: rounded display labels, neutral sans reading, mono time.
- Signature: restrained indexed color communicates chronology with redundant labels.

### 4. Focus Deck

- Structure: content above a persistent bottom command deck; Dictionary slides from
  right; no traditional sidebar. The deck becomes the global recorder outside app.
- Light: Bone `#ECE9E1`, White `#FFFFFF`, Carbon `#20211F`, Slate `#646A68`, Blue
  `#2E6BFF`, Record `#E35247`.
- Dark: Carbon `#171816`, Graphite `#242622`, Bone `#F1EEE6`, Blue `#6792FF`, Coral
  `#F06A5E`, Silver `#999D98`.
- Type: condensed sans navigation, humanist sans transcripts, mono metadata.
- Signature: one command-deck object persists across in-app and global contexts.

### 5. One-Bit Modern

- Structure: compact top strip; continuous ruled History; overlapping rectangular
  Dictionary editor; controlled dithering and selected-state inversion.
- Light: Paper `#FAFAF7`, Ink `#101010`, 25% and 50% ordered dither, Blue `#3457FF`,
  Failure `#E64A42`.
- Dark: Ink `#101010`, Paper `#F5F5EF`, reversed dithers, Blue `#6F87FF`, Failure
  `#F0645D`.
- Type: bitmap-inspired display/navigation, modern sans body, pixel/mono utility.
- Signature: exact one-pixel geometry and inversion; body text stays highly readable.

### 6. Iridescent Edge

- Structure: top-line navigation; wide opaque content fields; spectral edges show
  state; Dictionary uses edge-banded rows and a clean inspector.
- Light: Cloud `#F7F8FA`, White `#FFFFFF`, Slate `#242830`, Muted `#747A84`, Mint
  `#78D8C4`, Rose `#EF8EA6`, Violet `#8A78E8`.
- Dark: Eclipse `#11141A`, Cloud Dark `#1B2028`, Text `#EFF2F6`, Muted `#89919F`, Mint
  `#75E0CC`, Rose `#FF91AD`, Violet `#9A8BFF`.
- Type: thin humanist UI, medium readable sans transcript, mono time.
- Signature: color is confined to narrow diffracted edges; surfaces remain opaque.

### 7. Signal Steps

- Structure: top row of twelve slim step markers; history and dictionary align to its
  rhythm; firm rectangular controls; no literal audio-device metaphor.
- Light: Warm Gray `#F3F1EC`, Ink `#1B1B1A`, Red `#E64B3C`, Orange `#EE8A32`, Yellow
  `#E7C94A`, Blue `#3E68D8`, White `#FFFFFF`.
- Dark: Charcoal `#171817`, Raised `#242522`, White `#F4F0E8`, Red `#F05B4D`, Orange
  `#F19A43`, Yellow `#ECD35C`, Blue `#6488EE`.
- Type: compact grotesque caps, readable sans transcripts, segmented/tabular time.
- Signature: the step sequence expresses chronology, recording level, and finalization.

## Light and dark mode quality bar

Dark mode is not an inverted light palette. For each selected theme:

- redefine surface elevation, border contrast, muted text, focus, hover, selection,
  recording, success, warning, failure, and overlay colors;
- avoid pure black-on-white glare and large saturated fields;
- maintain hierarchy when screenshots are viewed in grayscale;
- test increased contrast and reduced transparency;
- meet at least WCAG AA contrast for meaningful text and controls;
- keep window vibrancy/material use subordinate to legibility;
- verify inactive-window and disabled-control states.

Support live System appearance changes without stale colors or rebuilding the window.

## Typography and assets

Prefer licensed, bundled fonts only when they materially define the selected concept.
Otherwise use system faces deliberately. Record all licenses and ensure fonts render
offline. Never use a display face for long transcripts if it harms reading.

Use SF Symbols only when they fit the chosen grammar. One-Bit Modern and other highly
specific themes may need a small original icon set drawn in Swift/Core Graphics at
integer scale. Do not mix visually incompatible icon families.

Do not ship the concept PNGs as interface backgrounds. Recreate the system natively in
SwiftUI/AppKit so it adapts, localizes, scales, and remains accessible.

## Motion

Give each theme one signature motion system, reflected in the recorder:

- motion must explain recording, finalizing, insertion, or navigation state;
- no ambient animation when idle;
- no decorative bouncing, glowing, or endless waveform loops;
- no transition should delay a recording command or hide state;
- Reduce Motion receives a deliberate alternative, not simply zero duration.

Keep rendering lightweight while the microphone and recognizer are active.

## Settings information architecture

Settings remains secondary and opens with Command-comma. Organize it into:

- Recording: shortcut and hold/toggle behavior;
- Transcription: Apple SpeechTranscriber, Parakeet lifecycle, language/model state;
- Delivery: Accessibility permission and copy fallback behavior;
- Appearance: Theme when two ship, Appearance System/Light/Dark, Reduce Motion follows
  system;
- Privacy: history retention and deletion;
- About.

Theme the Settings presentation, but keep switches, pickers, keyboard recording,
permission actions, destructive confirmations, and VoiceOver semantics trustworthy.

## Implementation order

1. Capture baseline screenshots and record the current functional test status.
2. Confirm the selected theme name(s) and locate the exact board image(s).
3. Write `docs/THEME_SYSTEM.md` with the chosen tokens, typography, structure, states,
   light/dark mapping, recorder mapping, and Reduce Motion behavior.
4. Introduce the semantic theme/appearance infrastructure and persistence.
5. Implement the selected main-window shell without changing domain behavior.
6. Implement History and all its states.
7. Implement Dictionary and all its states.
8. Implement Settings, onboarding, permissions, model states, dialogs, and notices.
9. Implement the matching global recorder overlay last only after its in-app visual
   primitive exists; it must still be completed before validation.
10. Audit keyboard navigation, VoiceOver, contrast, localization, resizing, and
    light/dark live switching.
11. Build and run tests. Fix all regressions caused by the UI work.
12. Capture the complete screenshot matrix and compare it to the selected concept at
    readable scale. Perform one bounded correction pass.
13. Update docs to match the shipped interface.

## Screenshot and verification matrix

For every selected theme, capture at minimum:

```text
light-history-populated
dark-history-populated
light-history-empty
dark-dictionary-list-editor
light-settings
dark-settings
light-onboarding-permissions
dark-parakeet-downloading-or-error
light-overlay-recording
dark-overlay-recording
light-overlay-text-ready-copy
dark-overlay-text-ready-copy
```

Also verify minimum window size, a wide window, inactive window, increased contrast,
Reduce Motion, and a real system appearance switch while the app is running.

Run existing state-machine, dictionary, persistence, and recording tests even though
the task is visual. Add focused UI tests for theme persistence, appearance resolution,
semantic contrast mapping, and overlay state rendering. Do not claim an interaction
passed unless it was actually exercised.

## Acceptance criteria

- The app no longer reads visually as the original stock `NavigationSplitView` plus
  grouped Form composition.
- The chosen board is recognizable in layout, density, palette, typography character,
  and signature interaction without being used as a static background.
- If two themes ship, each remains a complete independent system and switching is
  immediate and persisted.
- Every theme has genuinely designed light and dark variants.
- Main app, History, Dictionary, Settings, onboarding, model states, and recorder all
  share the selected grammar.
- The recorder stays compact, never shows transcript text, and preserves all required
  operational states.
- History and Dictionary keep all current behavior and data.
- Recording and delivery behavior do not regress.
- Keyboard, VoiceOver, contrast, Reduce Motion, increased contrast, resizing, and
  localization remain functional.
- No hard-coded one-off visual values remain in feature views.
- No placeholder UI, fake data path, lorem ipsum, copied third-party branding, or
  unlicensed asset ships.

## Final handoff

Return:

1. selected theme(s) implemented;
2. structural and token decisions;
3. files changed;
4. build/test commands with exact results;
5. screenshot paths for the full matrix;
6. functional regression results for recording and delivery;
7. accessibility checks;
8. any unverified item requiring the owner's physical microphone, permission, or
   external-app test.

Do not call the UI finished because one attractive History screenshot exists. It is
finished only when the complete app and the global recorder form one coherent theme in
both light and dark mode while the dictation workflow still works.

