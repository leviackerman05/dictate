# Dictate Design System

## Direction

Dictate uses one visual identity: **Color Index**. It is a compact, editorial macOS
utility that uses color to aid scanning, never as decoration. The interface should
feel authored and contemporary while retaining native keyboard, focus, menu, window,
and accessibility behavior.

The authoritative visual references are:

- `docs/final-design/dictate-final-ui.png`
- `docs/final-design/dictate-brand-system.png`

Generated sample copy is illustrative. Existing product behavior and localized copy
remain authoritative.

## Product Mark

The mark is a minimal paper-white paragraph form with a cobalt voice point on graphite.
It represents speech resolving into written text without relying on a literal
microphone, waveform, quotation mark, or speech bubble. Use a repo-native vector for
the shipping icon and menu-bar template image; the reference board is not itself a
final icon export.

The core mark must work in one color at 16 points. Color Index accents are optional at
large sizes only. Never imitate the Apple logo or Wispr Flow branding.

## Color

Use semantic tokens rather than feature-local RGB values.

| Role | Light | Dark |
|---|---|---|
| Background | `#F7F6F2` | `#151512` |
| Surface | `#FFFFFF` | `#20201D` |
| Raised surface | `#FBFAF7` | `#292925` |
| Primary text | `#11110F` | `#F3F0E7` |
| Secondary text | `#686861` | `#AAA79D` |
| Border | `#DDDCD5` | `#3A3A34` |
| Action / focus | `#3155D9` | `#7390FF` |
| Amber index | `#E5AA2F` | `#F0BE4F` |
| Moss / success | `#4E7C62` | `#69B783` |
| Coral / failure | `#C94B43` | `#F06A5E` |

Color must never be the only state cue.

## Typography and Geometry

- Modern system grotesk/sans for navigation, controls, labels, and transcript text.
- Monospaced numerals only for timestamps, duration, shortcuts, and technical status.
- Crisp 1-point borders; restrained shadows used only for floating surfaces.
- Field radius: 8 points. Surface radius: 12 points. Signal Pebble radius: 14–18
  points depending on state.
- Base spacing rhythm: 4, 8, 12, 16, 24, and 32 points.
- Avoid glassmorphism, decorative gradients, oversized cards, and excessive blur.

## Main Surfaces

### History

- No permanent sidebar.
- Compact title bar with the Dictate mark, History/Dictionary navigation, search, and
  Settings access.
- Horizontal seven-day index plus `All`. Use cobalt, amber, moss, and coral hairlines
  sparingly to improve day recognition.
- One continuous transcript list with dividers rather than a card per transcript.
- Rows expose timestamp, text, duration, insertion state, and overflow actions.
- Hover actions, keyboard selection, empty/search states, correction audit, and copy
  recovery must share this grammar.

### Dictionary

- Compact list-and-editor workspace.
- Search, add, and All/Vocabulary/Corrections filters above the list.
- List shows phrase, replacement, category, and modification metadata.
- Selected entry is cobalt and opens Phrase, Replacement, Notes, Delete, and Save in
  the right editor.
- At narrower supported widths, the editor may become a sheet while preserving focus
  and keyboard access.

### Settings

- Calm grouped controls derived from Quiet Ribbon: clear section titles, aligned
  labels, compact help copy, and native-feeling toggles, segmented controls, pickers,
  buttons, and shortcut capture.
- Cover General, Shortcut, Recording/model, Insertion/permissions, Appearance,
  Data & Privacy, Updates, and About without creating a generic sidebar clone.
- Appearance offers System, Light, and Dark. There is no theme chooser: Color Index is
  the product identity.

## Signal Pebble

The global recorder is a non-activating floating `NSPanel`. It must not become key,
steal focus, or change the insertion target. It may be repositioned or docked, but its
default location is unobtrusive near the bottom center.

1. **Dictate ready** — persistent while the service is enabled and available. A static,
   low-contrast 104–120 × 28–32 point pebble with a hollow status ring and `Dictate
   ready`. No waveform, glow, or recording color. The microphone is not capturing in
   this state. Reveal the shortcut only on hover/focus if useful.
2. **Listening (hold)** — 136–150 × 34–38 points. Cobalt status bead and 7–9 live
   level bars. No transcript and no persistent `Recording` label. Physical shortcut
   release transitions immediately out of this state.
3. **Processing (release)** — live bars compress into three moving dots. Optional
   concise `Finishing…` label. Never imply continued recording.
4. **Inserted success** — brief moss check pulse, then return to `Dictate ready`.
5. **Insertion failed** — expand only now. Show `Text ready — click Copy` and a real
   `Copy` button. Keep the transcript in History. After copy, show a brief confirmation
   and return to ready.
6. **Cancelled/failed** — concise non-color icon and accessible label, then safely
   return to ready. Escape/right-click provides cancellation without a large stop
   control.

Animations must be deterministic, subtle, and replaced with opacity/discrete state
changes when Reduce Motion is enabled.

## Accessibility

Support VoiceOver, Full Keyboard Access, sufficient contrast, Increased Contrast,
Reduce Transparency, and Reduce Motion. State changes need text or icon semantics in
addition to color. The tiny menu-bar glyph and product mark require meaningful
accessibility labels where they are interactive.
