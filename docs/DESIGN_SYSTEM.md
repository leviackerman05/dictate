# Dictate design system

Dictate is a precise writing instrument: a cool paper surface, manuscript-like
transcript typography, and restrained controls. It is not a recorder, cassette
deck, dashboard, or ambient audio visualization.

## Tokens

| Token | Value | Use |
| --- | --- | --- |
| canvas | `#F3F6F5` | Window and overlay paper field |
| surface | `#FCFDFC` | Opaque reading surface |
| ink | `#18201E` | Primary text |
| mutedInk | `#68726F` | Secondary text and metadata |
| hairline | `#D6DDDA` | Rules and settled breath lines |
| action | `#245E52` | Selection, focus, primary action |
| recording | `#E05A47` | Active recording and critical failure only |

Spacing is based on 4 points: 4, 8, 12, 16, 24, 32, and 48. Fields use a 6-point
radius, contextual surfaces 10, and the non-activating overlay 16. Shadows are
reserved for the overlay and are wide and soft.

System New York is used through SwiftUI's serif design for transcript excerpts and
editorial empty states. SF Pro remains the default for controls; SF Mono is used for
metadata, durations, shortcut descriptions, and diagnostics.

## Wireframes

Main window:

```text
┌──────────────┬──────────────────────────────────────────────┐
│ Dictate      │ History        [ search       ] [ ··· ]       │
│              ├──────────────────────────────────────────────┤
│  History     │ Today                                          │
│  Dictionary  │  09:42  00:08                                  │
│  Settings    │  A short corrected transcript in New York      │
│              │  ─────────────────────────────────────────     │
│              │  09:18  00:04                                  │
│ ● Ready      │  Another dictated fragment                     │
│ Right Option │  ─────────────────────────────────────────     │
└──────────────┴──────────────────────────────────────────────┘
```

Dictionary:

```text
┌────────────────────┬─────────────────────────────────────────┐
│ Dictionary       + │ Entry                                    │
│ [ search        ]  │ [Vocabulary] [Corrections]                │
│ [All][Vocab][Corr] │ heard form  →  written form               │
│ ● Claude Code      │ Use this entry                            │
│ ● cloud code → …   │ Live example: … cloud-code … → …         │
└────────────────────┴─────────────────────────────────────────┘
```

Settings:

```text
┌──────────────────────────────────────────────────────────────┐
│ Shortcut          Push-to-talk key       Right Option         │
│ Speech            Microphone             Available            │
│ Insertion         Accessibility          Optional             │
│ Privacy           Keep history           [on]                 │
│                   Retention              Forever              │
│ About             Dictate · macOS 26+                         │
└──────────────────────────────────────────────────────────────┘
```

Overlay:

```text
                 ┌─────────────────────────────────────┐
                 │ ● Listening   Speak when ready      │
                 │   ─────── breath line ─────────────  │
                 └─────────────────────────────────────┘
```

## Breath line

The breath line is the sole expressive animation. While listening, it is a thin
left-to-right line under the live transcript whose amplitude follows a smoothed
microphone level. On commit it settles to the hairline rule beneath the history
entry using a 420ms critically damped motion. Start uses a 160ms ease-out; small UI
feedback uses 120–180ms ease-out. With Reduce Motion, travel becomes a local change
in opacity and thickness. Idle has no looping animation.

The coral signal is always paired with text, shape, and an accessibility state
announcement. Increased contrast and reduced transparency are respected through
system materials and semantic colors; no control depends on color alone.
