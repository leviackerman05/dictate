# Ready-to-paste prompt for GPT-5.6 Luna

```text
Implement the final Dictate UI and brand system in this existing native macOS
repository. This is an implementation task, not a concept-generation task. There is
one approved design; do not offer alternatives and do not invent another theme.

REPOSITORY ROOT
/Users/aditidubey/Documents/ChatGPT/dictate

AUTHORITATIVE VISUAL REFERENCES
Open these files at original resolution before editing:
1. docs/final-design/dictate-final-ui.png
2. docs/final-design/dictate-brand-system.png

AUTHORITATIVE WRITTEN REFERENCES
Read these completely before editing:
1. PRODUCT.md
2. DESIGN.md
3. docs/CURRENT_STATE_AUDIT.md
4. PROMPT_BUILDER_REPAIR_AND_GUI.md

Then inspect git status, Package.swift, the current SwiftUI/AppKit implementation,
resources, localization, tests, and build scripts. Preserve all existing user and
builder changes. Never reset, clean, or overwrite unrelated work.

OUTCOME
Ship the single approved Color Index visual system across Dictate, including History,
Dictionary, Settings, onboarding and permissions, menu-bar presence and menus, every
empty/loading/error/recovery state, the global Signal Pebble recorder, System/Light/
Dark appearance, and the Dictate app icon plus monochrome menu-bar glyph.

Do not implement a theme picker. Color Index is the product identity. Appearance is an
independent persisted preference with System, Light, and Dark.

PRODUCT BOUNDARY
Dictate is an OS-level writing-input utility: hold a global shortcut, speak, release,
and insert the transcription at the text cursor that was focused before recording.
It contains History, Dictionary, and secondary Settings. Do not add a notetaker,
meeting recorder, document editor, folders, projects, summaries, AI chat, rewriting,
collaboration, cloud sync, or dashboard statistics.

FUNCTIONAL SAFETY — NO REGRESSIONS
The existing repair work is behaviorally authoritative. UI work must preserve:
- hold-to-talk starts on physical key-down and finalizes exactly once on physical
  key-up, including when the main window is closed or another app is active;
- click-to-toggle starts on the first trigger and finalizes on the next trigger;
- cancellation always works and never strands the recorder in a listening state;
- the original external app, focused element, and selection are captured before any
  overlay appears;
- the non-activating overlay never becomes key/main or steals the insertion target;
- final text is inserted at that original cursor using the existing delivery path;
- if insertion cannot happen, the transcript remains in History and recovery exposes
  a real Copy action;
- Apple SpeechTranscriber and NVIDIA Parakeet TDT 0.6B v3 keep their existing
  implementations and status models;
- Dictionary corrections, persistence, History, localization, permissions, and
  accessibility behavior keep working.

Do not rewrite the recording, recognition, shortcut, delivery, or persistence core to
make UI implementation easier. Make only minimal compatibility changes needed to
expose existing state to views, and add focused tests for any such change.

VISUAL AUTHORITY AND FACTUAL AUTHORITY
The PNGs are authority for composition, density, hierarchy, color relationships,
component geometry, and identity. Generated sample dates, counts, transcripts, and
labels are illustrative. Current models, behavior, persistence, permissions, and
localized product copy are factual authority. Never ship mock data from the boards.

DESIGN-SYSTEM ARCHITECTURE
Refactor Sources/Dictate/DesignSystem.swift into semantic light/dark tokens. Views
must consume meanings rather than literal hues. At minimum centralize background,
surface, raised/selected surfaces, primary/secondary/disabled/inverse text, borders,
focus ring, action, listening, success, warning, failure, overlay colors and shadow,
Color Index accents, typography roles, spacing, radii, border widths, and motion.

Use the palette and geometry in DESIGN.md as the starting specification. Tune only
when native rendering or contrast requires it. Do not scatter hard-coded RGB, font
sizes, radii, or animation durations throughout feature views. Dark mode must be
purpose-designed, not an automatic inversion. Remove the current forced-light scheme.

MAIN WINDOW
Replace the permanent NavigationSplitView/sidebar presentation with the approved
compact top navigation while keeping native macOS window behavior and keyboard focus.
The top band contains the small Dictate mark/title, History and Dictionary navigation,
and quiet Settings access. Do not add a dashboard or bottom command deck.

HISTORY
- Implement the horizontal seven-day date index plus All.
- Derive days from real History data/current calendar; handle locale, month/year,
  daylight-saving, and empty-day boundaries correctly.
- Use cobalt for the current day and restrained amber/moss/coral index hairlines.
- Include History heading, Today filter, search, and real item count.
- Use one continuous transcript list with dividers, not a card per row.
- Rows show timestamp, transcript, duration, inserted/not-inserted state, and overflow.
- Preserve copy, retry insertion, pin, correction audit/learn, multi-selection,
  deletion, export, empty, and search behavior.
- Use monospaced numerals only for timestamp/duration/shortcut metadata.

DICTIONARY
Use the Color Index character with Focus Deck's efficient list/editor structure:
- search and Add at the top;
- All, Vocabulary, and Corrections filters with real counts;
- compact left list showing phrase, replacement, category, and metadata;
- cobalt selected row with a non-color selection cue;
- right editor with Phrase, Replacement, Notes (optional), Delete, and Save;
- preserve existing validation, enabled state, corrections, import/export, search,
  keyboard behavior, and persistence;
- at narrow supported widths, adapt the editor into a sheet or stacked detail without
  clipping controls or losing focus.

SETTINGS
Use Quiet Ribbon's calm grouped-control discipline inside Color Index. Organize the
real settings into General, Shortcut, Recording & Models, Insertion & Permissions,
Appearance, Data & Privacy, Updates, and About. Use aligned labels, compact help copy,
and native-behaving controls.

Appearance provides System, Light, and Dark and updates every surface, including the
Signal Pebble, without relaunching. Do not display a theme chooser. Show actual model
names and existing Apple/Parakeet readiness, download, validation, loading, retry,
unavailable, and removal states. Do not use vague “on-device model” copy when a
concrete implemented model name is available.

SIGNAL PEBBLE — GLOBAL RECORDER
Implement this mandatory component as a non-activating NSPanel. It must not become
key/main, steal focus, or alter the captured insertion target. Default placement is
unobtrusive near the bottom center. Safe drag/docking is optional; do not let it delay
correctness. It may share the low-interruption principle of a modern dictation bar,
but must not copy Wispr Flow's logo, silhouette, proportions, gradients, or motion.

STATE 1 — DICTATE READY
- Persistently visible while Dictate's global shortcut service is enabled and the app
  is available, even when the shortcut is not held.
- Approximately 104–120 points wide and 28–32 points high.
- Extremely low prominence: static neutral surface/outline, hollow status ring, and
  small “Dictate ready” label.
- No waveform, glow, pulsing, recording color, or audio-level motion.
- Do not start or imply microphone capture in this state. It means the service is
  available, not that audio is being recorded.
- Reveal the shortcut on hover/focus or in a tooltip rather than showing it constantly.
- Add a Show ready indicator setting if none exists; default it on. The menu-bar item
  must still communicate whether Dictate is running when it is hidden.

STATE 2 — LISTENING (HOLD)
- On shortcut key-down, morph to roughly 136–150 × 34–38 points.
- Use a cobalt filled status bead and 7–9 responsive vertical level bars.
- No live transcript and no persistent “Recording” label.
- Physical shortcut release immediately exits listening and finalizes exactly once.

STATE 3 — PROCESSING (RELEASE)
- Make it unambiguous that recording stopped.
- Compress waveform bars into three restrained traveling cobalt dots.
- Optional concise “Finishing…” label.
- Never continue showing active audio levels after release.

STATE 4 — INSERTED SUCCESS
- Brief moss check pulse and accessible success announcement.
- Return to the quiet Dictate ready state instead of disappearing permanently.

STATE 5 — INSERTION FAILED / RECOVERY
- Only this state expands horizontally.
- Show “Text ready — click Copy” and a real keyboard-accessible Copy button.
- Never show transcript prose inside the pebble.
- Keep text safe in History. Copy writes the exact final corrected text.
- After copy, announce confirmation briefly and return to Dictate ready.

STATE 6 — CANCELLED OR FAILED
- Provide a concise non-color icon plus accessible message.
- Escape and the existing cancellation path must work. A right-click menu may expose
  Cancel/Hide/Settings; do not add a large permanent Stop button.
- Return safely to Dictate ready.

The overlay needs independent light and dark surfaces and sufficient contrast. Respect
Reduce Motion with opacity/discrete changes, plus Reduce Transparency and Increased
Contrast. Avoid constant animation during ordinary work.

BRAND AND ICON
Use docs/final-design/dictate-brand-system.png as reference for one mark: a capital D
whose negative space contains an insertion cursor and whose open bowl resolves into
compact signal bars. It represents voice becoming inserted text.

- Rebuild the mark as clean repo-native vector geometry; do not ship the raster board
  as the app icon.
- Replace/update Sources/Dictate/Resources/AppIcon.svg and the asset-catalog icon
  source consistently with correct macOS icon safe area.
- Create a monochrome template version for the menu bar that remains legible at 16–18
  points and adapts automatically to menu-bar appearance.
- Use the small mark beside the Dictate title where shown, but do not repeat it
  decoratively throughout the app.
- Large icon may use tiny amber/moss/coral signal ticks; the core mark works in one
  color.
- Do not use, trace, or resemble the Apple logo. Do not use a microphone pictogram,
  speech bubble, generic waveform circle, or copied competitor branding.

MOTION
Use one restrained motion grammar: 120–180 ms direct feedback and 180–260 ms state
morphs. Drive the Signal Pebble waveform from real input level only while listening.
Success is one short pulse. No springy wobble, decorative gradients, continuous idle
animation, or gratuitous transitions.

ACCESSIBILITY AND NATIVE BEHAVIOR
- VoiceOver labels/announcements for navigation, filters, insertion/model/recorder
  states, and recovery actions.
- Full Keyboard Access, visible focus, correct tab order, and Escape behavior.
- Never rely on color alone.
- Support Increased Contrast, Reduce Transparency, and Reduce Motion.
- Preserve localization and add keys for every new user-facing string.
- Use native controls where behavior matters, then style their surroundings.
- The ready overlay must not repeatedly announce or interrupt screen-reader work.

IMPLEMENTATION ORDER
1. Audit current UI/state architecture and map existing states to new surfaces without
   modifying behavior.
2. Implement semantic design tokens and persisted appearance preference.
3. Implement the app mark, app icon source, and menu-bar template glyph.
4. Replace the main shell and implement History.
5. Implement Dictionary list/editor and responsive fallback.
6. Implement grouped Settings and Appearance.
7. Implement the full Signal Pebble state presentation, including persistent ready
   visibility without idle microphone capture or focus theft.
8. Bring onboarding, permissions, alerts, menus, empty/error/model states, localization,
   and accessibility into the system.
9. Build, test, run, and capture visual evidence.

VERIFICATION
- Run the repository's existing build and test commands.
- Add focused unit tests for appearance persistence and extracted overlay state mapping.
- Preserve/run shortcut gesture, transcription accumulator, delivery, Dictionary,
  History, and model-status tests.
- Launch and inspect populated/empty History, Dictionary list/editor, Settings,
  onboarding/permissions, and every Signal Pebble state.
- Capture light/dark screenshots of History, Dictionary, Settings, and the complete
  Signal Pebble state matrix.
- In another app, focus an editable field, hold shortcut, speak, release, confirm the
  recording stops immediately, insertion occurs at the original cursor, and the
  pebble returns to Dictate ready.
- Test click-to-toggle separately.
- Deny Accessibility and verify Text ready + Copy recovery with no text loss.
- Confirm the ready pebble never activates Dictate, changes external selection, or
  opens the microphone before the trigger.
- Verify System/Light/Dark updates every surface without relaunching.
- Inspect the 16–18 point menu-bar glyph in both menu-bar appearances.

Do not claim manual checks you could not run. Record environment-only blockers exactly.

ACCEPTANCE CRITERIA
- The result visibly matches both final reference boards as one Color Index product.
- There are no alternative themes or leftover theme-choice UI.
- History, Dictionary, Settings, onboarding, menu bar, and recorder share the same
  semantic system in light and dark.
- Dictate ready remains visible but quiet while available; it has no idle waveform and
  does not capture audio.
- Hold-to-talk stops on release and the listening visualization stops with it.
- Successful text inserts at the original cursor; failed insertion preserves text and
  exposes Copy.
- Overlay never shows transcript prose and never steals focus.
- App mark is an original D + insertion cursor + signal design that works as both app
  icon and tiny monochrome menu-bar glyph.
- No notetaker, meetings, summaries, dashboard, sidebar, or copied branding is added.
- Build/tests pass and final handoff lists changed files, commands/results, screenshots,
  and honest remaining risks.

FINAL HANDOFF FORMAT
1. Outcome summary.
2. Changed files grouped by design system, surfaces, overlay, brand/resources,
   localization, and tests.
3. Verification commands with pass/fail results.
4. Screenshot paths.
5. Any unverified manual behavior or remaining risk.
```
