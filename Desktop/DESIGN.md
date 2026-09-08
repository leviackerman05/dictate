---
name: Dictate portable desktop
description: The existing Dictate visual language applied to the Windows desktop beta.
colors:
  bg: "#f7f6f2"
  side: "#efeee9"
  panel: "#ffffff"
  raised: "#f4f3ef"
  text: "#20211f"
  muted: "#64655f"
  line: "#d8d8d0"
  action: "#3155d9"
  accent: "#6454ad"
  selected: "#e5e0f4"
  success: "#397353"
  error: "#b63535"
  dark-bg: "#1c1d18"
  dark-side: "#202127"
  dark-panel: "#292b32"
  dark-raised: "#30323b"
  dark-text: "#f1f0e8"
  dark-muted: "#b6b6ae"
  dark-line: "#464842"
  dark-action: "#9aaeff"
  dark-accent: "#b8a6ff"
  dark-selected: "#4a436f"
  dark-success: "#88c69d"
  dark-error: "#ff9b91"
  dark-action-text: "#182037"
typography:
  headline:
    fontFamily: 'Georgia, "Times New Roman", serif'
    fontSize: "36px"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "-0.025em"
  title:
    fontSize: "17px"
    fontWeight: 700
    lineHeight: 1.4
  body:
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif'
    fontSize: "14px"
    lineHeight: 1.6
  label:
    fontSize: "13px"
    fontWeight: 600
  transcript:
    fontFamily: "Georgia, serif"
    fontSize: "19px"
    lineHeight: 1.7
rounded:
  control: "8px"
  navigation: "10px"
  recording: "12px"
  panel: "16px"
spacing:
  icon-gap: "8px"
  actions: "10px"
  field-gap: "16px"
  panel: "24px"
components:
  button-primary:
    backgroundColor: "{colors.action}"
    textColor: "{colors.panel}"
    rounded: "{rounded.control}"
    padding: "9px 13px"
  button-primary-dark:
    backgroundColor: "{colors.dark-action}"
    textColor: "{colors.dark-action-text}"
  button-secondary:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.text}"
    rounded: "{rounded.control}"
    padding: "9px 13px"
  button-quiet:
    backgroundColor: "transparent"
    textColor: "{colors.text}"
    padding: "6px 8px"
  input:
    backgroundColor: "{colors.bg}"
    textColor: "{colors.text}"
    rounded: "{rounded.control}"
    padding: "10px 12px"
  navigation-current:
    backgroundColor: "{colors.selected}"
    textColor: "{colors.text}"
    rounded: "{rounded.navigation}"
    padding: "14px 16px"
  panel:
    backgroundColor: "{colors.panel}"
    rounded: "{rounded.panel}"
    padding: "24px"
---

# Design System: Dictate portable desktop

## Overview

**Creative North Star: "A calm place for your words"**

This is a code-led extension of Dictate's incumbent native interface: warm neutral or charcoal surfaces, blue actions, violet navigation selection, and serif page headings. The name above describes the existing direction; it is not a new brand identity. Scope is `Desktop/`; the native Swift app and website retain their own implementations.

**Key Characteristics:**

- Persistent desktop navigation and quiet, bordered content panels.
- Legible transcripts, explicit local processing states, and visible recovery actions.
- System controls with a restrained serif heading and transcript voice.

Source of truth: `src/style.css` and `src/main.ts`. Product statements are limited to the README and implementation; no `PRODUCT.md` exists. Compare `../docs/evidence/ui/dictate-dashboard.png` with `../docs/evidence/ui/portability/portable-*.png`. These portable captures use synthetic mock IPC. The finish review returned **ship within the reviewed browser/source UI scope**, including resolved form-draft, focus, and navigation fixes; this does not establish native runtime, microphone, or editor-insertion validation. App icon outputs are conversions of `../Sources/Dictate/Resources/AppIcon.svg`; no generated raster artwork was introduced.

## Colors

Blue `action` identifies primary actions, focus, activity bars, and audio levels. Violet `accent` colors quick-action icons; `selected` marks the current navigation item. Green and red accompany textual readiness, recording, and error states.

Warm `bg` and `side` separate the workspace from white `panel` surfaces. Charcoal dark equivalents preserve that hierarchy. Muted text and fine `line` borders provide structure. Dark-mode primitives map to the same CSS custom properties via `data-theme=dark`; appearance supports system, light, and dark.

## Typography

Serif headlines provide the app's recognizable voice; system sans handles controls, labels, descriptions, and metrics. Paragraphs stop at (72ch). Transcripts preserve whitespace, allow selection, and wrap long unbroken text. Metadata and totals use tabular numerals. Compact labels are (12px); activity totals are (48px), statistics (36px).

## Layout

A fixed sidebar (220px) anchors a content area with (34px) padding and maximum width (1500px). Dashboard and setup panels use two columns with (24px) gaps. At (980px) and below, the sidebar becomes (184px), main padding becomes (26px 22px), headings become (32px), setup/dashboard/form grids become one column, and model actions stack. Preserve this desktop layout; it is not a mobile-navigation pattern.

The activity panel keeps a (1:2) metric/chart split. Main bottom padding (100px) reserves room for the recording bar. Actions wrap, dictionary content can shrink and wrap, and transcript rows separate with fine rules.

## Elevation & Depth

Tonal surfaces and borders do most of the work. Ordinary panels have no shadow. Only the fixed recording bar lifts above content with `0 8px 24px #0002`. Its level meter transitions over (0.1s ease-out); reduced-motion preference disables transitions and animation. Additional extension metadata and representative component previews live in `.impeccable/design.json`; synthesized tonal ramps there are preview aids, not new runtime tokens.

## Shapes

Controls are gently rounded, panels more generous, and navigation sits between them. Panels and fields use a (1px) border. Status dots are circular; keyboard hints use compact (4px) corners. Do not copy the native screenshot's larger radii into portable components without changing the actual shared CSS deliberately.

## Components

- **Buttons:** Primary for record, model setup, save, and recovery copy; bordered secondary for supporting actions; quiet for row actions. Hover raises neutral surfaces or slightly darkens primary fills. Disabled buttons use half opacity and cannot be activated. Focus outlines are (3px) action blue with (3px) offset.
- **Navigation:** Six named destinations with icons, a violet current row, and `aria-current=page`. Navigation completes onboarding when needed and moves focus to the destination heading. State refreshes preserve a matching focused control.
- **Forms:** Dictionary and settings drafts survive state refreshes and navigation. Successful saves reset the relevant draft; failed saves preserve it. Edit/cancel intentionally resets the dictionary draft. Preserve caret/selection where applicable and explicit input labels.
- **Panels and rows:** Dashboard, model, onboarding, and recovery panels share one border/radius vocabulary. History uses selectable serif text and disclosure of dictionary corrections; search preserves typing focus. Empty states explain the next useful action.
- **Recording and recovery:** Phase text distinguishes microphone preparation, listening, transcription, and delivery. Feedback uses polite live announcements; model progress uses status semantics. Unresolved recovery disables new recording and exposes Copy, delayed retry, and Dismiss. Show capability-specific guidance supplied by the native adapter.

## Do's and Don'ts

- **Do** preserve the warm/charcoal palette, blue actions, violet sidebar selection, and serif app headings.
- **Do** retain drafts, keyboard focus, text selection, clear status copy, and recoverable transcript actions when extending screens.
- **Do** verify representative light/dark and minimum-window states against the evidence captures.
- **Don't** turn synthetic browser captures into claims of native microphone or OS integration testing.
- **Don't** replace the existing icon identity or introduce decorative raster assets to extend ordinary app UI.
