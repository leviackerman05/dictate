---
name: Dictate for Windows
description: Compact local dictation workspace with familiar Windows controls.
colors:
  bg: "#f7f8fa"
  side: "#eef1f5"
  panel: "#fff"
  raised: "#f1f4f8"
  text: "#1d2533"
  muted: "#596577"
  line: "#dce2e9"
  action: "#245bdd"
  selected: "#e0eafd"
  success: "#23734b"
  error: "#b12e35"
  action-text: "#fff"
  dark-bg: "#171a20"
  dark-side: "#1d2129"
  dark-panel: "#222731"
  dark-raised: "#2b3240"
  dark-text: "#edf1f7"
  dark-muted: "#b1bdce"
  dark-line: "#3c4656"
  dark-action: "#99b8ff"
  dark-selected: "#303e5a"
  dark-success: "#89d8ac"
  dark-error: "#ffa0a6"
  dark-action-text: "#142441"
typography:
  headline:
    fontFamily: "\"Segoe UI Variable Text\", \"Segoe UI\", system-ui, sans-serif"
    fontSize: "28px"
    fontWeight: 650
    lineHeight: "1.2"
    letterSpacing: "-.025em"
  workspace-title:
    fontFamily: "\"Segoe UI Variable Text\", \"Segoe UI\", system-ui, sans-serif"
    fontSize: "22px"
    fontWeight: 600
    lineHeight: "1.4"
    letterSpacing: "-.02em"
  title:
    fontFamily: "\"Segoe UI Variable Text\", \"Segoe UI\", system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 650
    lineHeight: "1.4"
  body:
    fontFamily: "\"Segoe UI Variable Text\", \"Segoe UI\", system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: "1.6"
  transcript:
    fontFamily: "\"Segoe UI Variable Text\", \"Segoe UI\", system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: "1.75"
  label:
    fontFamily: "\"Segoe UI Variable Text\", \"Segoe UI\", system-ui, sans-serif"
    fontSize: "12px"
  button:
    fontFamily: "\"Segoe UI Variable Text\", \"Segoe UI\", system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 600
  metric:
    fontFamily: "\"Segoe UI Variable Text\", \"Segoe UI\", system-ui, sans-serif"
    fontSize: "32px"
    fontWeight: 600
    letterSpacing: "-.03em"
rounded:
  tag: "4px"
  key: "5px"
  segment: "6px"
  control: "7px"
  search: "8px"
  panel: "12px"
  workspace: "14px"
  voice: "18px"
spacing:
  step-4: "4px"
  step-6: "6px"
  step-7: "7px"
  step-8: "8px"
  step-10: "10px"
  step-12: "12px"
  step-14: "14px"
  step-16: "16px"
  step-18: "18px"
  step-20: "20px"
  step-22: "22px"
  step-24: "24px"
  step-26: "26px"
  step-28: "28px"
  step-32: "32px"
  step-34: "34px"
  step-36: "36px"
  step-48: "48px"
components:
  button-primary:
    backgroundColor: "{colors.action}"
    textColor: "{colors.action-text}"
    typography: "{typography.button}"
    rounded: "{rounded.control}"
    padding: "9px 14px"
  button-primary-dark:
    backgroundColor: "{colors.dark-action}"
    textColor: "{colors.dark-action-text}"
    typography: "{typography.button}"
    rounded: "{rounded.control}"
    padding: "9px 14px"
  button-secondary:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.text}"
    typography: "{typography.button}"
    rounded: "{rounded.control}"
    padding: "9px 14px"
  button-secondary-hover:
    backgroundColor: "{colors.raised}"
    textColor: "{colors.text}"
  button-quiet:
    backgroundColor: "transparent"
    textColor: "{colors.muted}"
    typography: "{typography.button}"
    rounded: "{rounded.control}"
    padding: "6px 8px"
  input:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.text}"
    rounded: "{rounded.control}"
    padding: "9px 11px"
  navigation-current:
    backgroundColor: "{colors.selected}"
    textColor: "{colors.text}"
    rounded: "{rounded.control}"
    padding: "11px 13px"
  panel:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.text}"
    rounded: "{rounded.panel}"
    padding: "22px"
  model-tag:
    textColor: "{colors.muted}"
    rounded: "{rounded.tag}"
    padding: "3px 6px"
  segmented-control:
    backgroundColor: "{colors.raised}"
    rounded: "{rounded.search}"
    padding: "3px"
  switch:
    backgroundColor: "{colors.raised}"
    rounded: "{rounded.panel}"
    width: "36px"
    height: "21px"
  shortcut-capture:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.text}"
    rounded: "{rounded.control}"
    padding: "9px 14px"
---

# Design System: Dictate for Windows

## Overview

**Creative North Star: "A Windows control workspace"**

Dictate’s Windows renderer is a compact dictation utility with Segoe typography, slate surfaces, blue actions and familiar grouped controls. One recording action anchors Dictation; task-specific rows and forms give History, Dictionary, Statistics, Speech models and Settings their own useful density. This documents the implemented Desktop renderer, replacing the previous warm/serif specification.

Scope is `Desktop/`. The native SwiftUI Mac app is unaffected, and Linux support is withdrawn. The committed direction comes from `PRODUCT.md` and `.impeccable/surfaces/windows-workspace.md`; implementation values come from `src/style.css` and behavior from `src/main.ts`. Existing application icons and the waveform identity remain; this redesign introduces no shipping raster artwork.

**Key Characteristics:**

- Persistent desktop navigation with honest current-page state.
- Compact sans typography, fine borders and continuous model rows.
- Explicit local-processing states, preserved drafts and recoverable words.

## Colors

The light theme pairs a cool slate-white field with white panels, a slate navigation rail and blue actions. The dark theme uses charcoal/slate layers with pale blue actions and a dark action label. The frontmatter preserves the exact source values; `dark-*` names document the overrides of the same runtime variables under `data-theme=dark`.

- **Action blue (`action`):** primary buttons, current navigation icons, focus outlines, carets and audio levels. `action-text` supplies the correct foreground in each theme.
- **Blue selection (`selected`):** current navigation backgrounds, shortcut capture and selected text; no separate violet accent remains.
- **Slate neutrals (`bg`, `side`, `panel`, `raised`):** app field, rail, containers and subtle hover/active grouping. `text`, `muted` and `line` separate content, supporting copy and dividers.
- **State colors (`success`, `error`):** readiness, model use, errors and recording indicators, paired with explicit text. Color alone does not describe the operation.

Appearance offers System, Light and Dark. The renderer reads the saved preference; System follows `prefers-color-scheme` and its change event. Saving applies settings. Sidecar tonal ramps are synthesized preview aids, not extra runtime palette tokens.

## Typography

All interface text, headings, transcripts and keyboard hints use `"Segoe UI Variable Text", "Segoe UI", system-ui, sans-serif`. There is no serif display face or distinct monospace family. The root is 14px; ordinary paragraphs are 13px/1.6 with a 72ch maximum, and transcripts are 15px/1.75, preserve line breaks, wrap long words and permit selection.

The page heading is 28px/1.2 at weight 650, falling to 25px at 780px. Standard section titles are 15px/1.4 at weight 650; the central dictation title is 22px at weight 600, setup introduction 24px/1.25, and statistics 32px at weight 600. Controls are 13px/600; supporting metadata commonly uses 11–12px. Numeric statistics, times and model facts use tabular numerals. Most text uses sentence case.

## Layout

The flex shell fills 100vh. Body scrolling is disabled; the main content area scrolls independently. The sidebar is 204px with `26px 12px 18px` padding and the main area has `28px 32px 32px` padding. There is no main maximum-width token. The reference content viewport is 1120×750; the supported minimum captured by this review is 760×560.

At a maximum width of 1000px, the sidebar becomes 176px and main padding 24px. At 780px, the sidebar becomes 158px, main padding 20px, page heading actions wrap, settings rows may wrap, search result counts hide, and dictionary Type occupies the first full row of a two-column form. Sidebar navigation stays visible.

Setup is a 35%/remaining two-column workspace with a 475px minimum height; it changes to 31% at 1000px. At 780px it becomes one column and hides the introductory panel. At a maximum height of 620px, setup steps tighten, workspace minimum height clears, and the page heading margin reduces. Small settings windows intentionally scroll to the save and local-data controls.

Dictation centers the primary action in a 280px-minimum workspace, followed by a compact session summary and up to three recent dictations. Speech models use continuous separated rows. Settings use bordered groups with aligned controls; the final CSS gives groups `16px 20px` padding and a 14px bottom gap, with 12px vertical row padding. Dictionary uses a `140px 1fr 1fr` form grid, narrowed to `110px 1fr 1fr` at 1000px. Statistics use three columns and a separate seven-day table-like list.

## Elevation & Depth

Borders and tonal layers do most of the work. Ordinary panels have no shadow. The selected segmented option uses `0 1px 3px #00000016`; the fixed recording bar uses `0 6px 24px #0003`. The bar sits 18px from the bottom and centers within the content area, offset for each sidebar width. The source does not reserve a separate large bottom gutter for it.

Button backgrounds and switch thumbs transition over .14s ease-out. Pressing an enabled button translates it down 1px. The audio level changes over .1s ease-out. The listening symbol runs a 1.5s ease-in-out loop that reaches .94 scale and 24px corners halfway through. Reduced-motion preference disables animations and transitions globally. No backdrop blur or decorative material effect is used.

## Shapes

Controls and navigation have 7px corners. Search and segmented containers use 8px; panels, settings groups and the recording bar use 12px; setup and dictation workspaces use 14px. Model tags use 4px corners, keyboard hints 5px and selected segments 6px. The 58px voice symbol has 18px corners. Status dots and switch thumbs are circular. Fine 1px borders and dividers establish grouping; continuous list rows retain square shared boundaries.

## Components

- **Buttons:** primary for recording, save and key setup/copy actions; bordered secondary for supporting actions; quiet for low-emphasis row actions. Default minimum height is 36px and quiet is 30px. Disabled controls use .5 opacity. Focus is a 2px action-color outline with 3px offset; search groups use a 2px offset. Danger actions use error-colored text.
- **Navigation:** six destinations retain icons and text. `aria-current=page` and selection fill appear only when onboarding is complete and the page is actually visible. Setup has no falsely selected destination. Explicit sidebar navigation moves focus to the page heading.
- **Forms and drafts:** named dictionary/settings fields, radio selections and checkboxes survive render refreshes and navigation in in-memory drafts. Matching controls regain focus; text/search caret selections are restored where supported. Successful saves reset the submitted form draft; errors preserve it. Dictionary edit/cancel resets that draft deliberately. These are session drafts, not promised disk persistence.
- **Shortcut capture:** the first settings row shows the current draft or a “Press a key or mouse button…” state with a 2px blue border and selected background. Capture pauses the native shortcut, accepts a lone modifier on release, a nonmodifier key/chord on press, or middle/back/forward mouse buttons. Escape and window blur cancel; other actions stop capture. Left/right mouse buttons are excluded. Right Ctrl, F8 and Mouse back presets update the draft. Capture returns focus to its button, and Save changes commits the settings. Browser checks prove this renderer flow only.
- **Segments and switches:** recording mode and appearance use labeled radio groups with an inset selected surface; checkboxes with switch semantics handle insertion and history. Focus outlines remain visible on the hidden radio's visible segment. The 36×21px switch moves its 13px thumb from 3px to 18px and changes to the action colors when checked.
- **Models, tags and history:** models share continuous rows with download/installed/in-use state, compact neutral tags and actions. Availability is supplied by the native snapshot; this design spec does not certify model operation. History provides search, export, selectable sans-serif transcripts and correction disclosure; empty states explain the next useful action.
- **Recording and recovery:** saved hold/toggle mode determines shortcut guidance. With automatic insertion off, Dictation says words stay ready to copy. Phase labels distinguish starting the microphone, listening, local transcription and returning words. Recovery presents the transcript, Copy text, delayed retry and Dismiss; unresolved recovery disables new recording. Dismiss and destructive data actions use confirmations. Feedback is politely announced and setup progress/recording use status semantics.
- **Overlay and evidence modes:** `?overlay` renders a separate 280×64px status-and-level strip. It is distinct from the main window's fixed recording bar and from shortcut capture mode. The 18 reviewed PNGs in `../docs/evidence/ui/windows-beta5/` show six pages and setup in light/dark plus selected 760×560 states. They use synthetic Tauri IPC in Chromium on macOS, including fallback font rendering. Recording, recovery and populated variants are source-inspected unless a separate capture explicitly demonstrates them. `finish-verdict.md` resolves the three scored finish fixes; it is not whole-release certification or evidence of native Windows/Segoe, physical input, microphone, insertion or inference. Native tests retain their own evidence.

## Do's and Don'ts

- Do preserve Segoe typography, slate surfaces, blue actions and compact grouped controls.
- Do reflect saved recording mode and insertion preferences in guidance, and preserve drafts, focus and text selection.
- Do check light, dark and minimum-window states using clearly labeled evidence.
- Don't reintroduce oversized serif headings, warm/violet styling or Mac-specific shortcut labels into this Windows renderer.
- Don't describe synthetic browser evidence as native Windows, Segoe, microphone, physical-input, inference or installer validation.
- Don't change the existing Dictate icon identity or add decorative shipping raster assets for this interface.
