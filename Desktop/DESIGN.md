---
name: Dictate shared desktop workspace
description: Windows renderer aligned to the native Mac Dictate visual system.
colors:
  background: "#F7F6F2"
  surface: "#FFFFFF"
  raised: "#FBFAF7"
  text: "#11110F"
  muted: "#686861"
  border: "#DDDCD5"
  sidebar: "#F0F1F6"
  selection: "#E1DEFF"
  action: "#3155D9"
  violet: "#5D50D8"
  blue: "#2E73E6"
  moss: "#4E7C62"
  amber: "#E5AA2F"
  coral: "#C94B43"
  dark-background: "#151512"
  dark-surface: "#20201D"
  dark-raised: "#292925"
  dark-text: "#F3F0E7"
  dark-muted: "#AAA79D"
  dark-border: "#3A3A34"
  dark-sidebar: "#17181D"
  dark-card: "#202127"
  dark-selection: "#3B3563"
  dark-action: "#7390FF"
typography:
  display:
    fontFamily: "Georgia, serif"
    fontSize: "44px"
    fontWeight: 700
    lineHeight: "1.05"
  page-title:
    fontFamily: "Georgia, serif"
    fontSize: "34px"
    fontWeight: 700
    lineHeight: "1.1"
  body:
    fontFamily: "\"Segoe UI Variable Text\", \"Segoe UI\", system-ui, sans-serif"
    fontSize: "13px"
    lineHeight: "1.5"
  label:
    fontFamily: "\"Segoe UI Variable Text\", \"Segoe UI\", system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 650
  metadata:
    fontFamily: "ui-monospace, \"Cascadia Mono\", monospace"
    fontSize: "9px"
rounded:
  field: "8px"
  surface: "12px"
  card: "13px"
  modal: "18px"
  capsule: "999px"
---

# Design System: Dictate shared desktop workspace

## Overview

**Creative North Star: “The same calm writing instrument on every desktop.”**

The Windows renderer follows the native Mac app’s structure, visual hierarchy,
palette, editorial headings, restrained borders, and local-first language. Platform
controls remain honest to Windows: Segoe is the UI face, Windows shortcut names are
used, and available Windows recognition engines replace Apple-only engines.

The source of truth for shared tokens is `../Sources/Dictate/DesignSystem.swift`.
The Windows implementation lives in `src/main.ts` and `src/style.css`. Linux is
outside the current distribution scope.

## Colors

Use the exact light and dark semantic colors listed above. The lavender sidebar
selection, blue action, violet index, moss success, amber warning, and coral failure
are the shared Dictate identity. Surfaces rely on one-pixel borders and small tonal
steps. Shadows belong only to primary floating actions and onboarding depth.

## Typography

Editorial page headings use a system serif on Mac and Georgia on Windows. Navigation,
controls, forms, and dense content use each platform’s system sans face. Monospace is
reserved for short dates, times, sizes, and status metadata.

## Layout

The persistent navigation rail is 220–224 points/pixels wide. At the 1120×750
reference window, content uses a 36px top inset and a bounded 1040px reading width.
Dashboard, History, Dictionary, Statistics, AI models, and Settings share navigation
names and comparable structures with Mac. At 760×560 the rail remains visible and
the content scrolls vertically without horizontal overflow.

Onboarding uses a centered 740×600 panel. Microphone, model, and insertion status
remain visible with the footer actions; the required path never needs an internal
scroll. Optional model and recording choices live in Setup options.

## Elevation & Depth

One-pixel borders and semantic surface shifts create most depth. The recording action
may use a soft blue lift; onboarding uses a dimmed backdrop and restrained shadow.
Ordinary cards remain flat.

## Shapes

Fields use 8px corners, surfaces 12–13px, and onboarding 18px. Recording actions,
segmented controls, status pills, and switches use capsules. Dense continuous lists
share edges and dividers instead of turning every row into a floating card.

## Components

- **Navigation:** waveform wordmark, WORKSPACE label, six shared destinations, and a
  bottom local/private readiness indicator.
- **Dashboard:** editorial greeting, current model, recording capsule, weekly line
  chart, quick actions, and recent transcriptions.
- **Recorder overlay:** a centered 62×22 signal pebble within a transparent 152×22
  host. Nine blue bars show listening and three dots show processing. It has no text,
  copy icon, or action buttons; failed transcripts remain recoverable in the main app.
- **History:** seven-day index, search and count toolbar, dated transcript cards,
  insertion status, and expandable copy/pin/delete actions.
- **Dictionary:** count, add/import/export actions, color-indexed continuous rule
  list, correction direction, enable, edit, and delete controls.
- **Statistics:** Week, Month, and Year ranges update metrics and activity buckets.
- **AI models:** current model strip, recommended model, performance summary, and
  grouped Parakeet/Whisper catalog. Only engines supported by the platform appear.
- **Settings:** General, Audio, and Permissions tabs. Appearance offers System,
  Light, and Dark. Windows supports a single key, key combination, or supported mouse
  button; Right Ctrl is the default suggestion.
- **Insertion:** Windows verifies an external focused element, refuses password fields,
  guards against focus changes, and sends Unicode text without replacing clipboard
  contents. Failed delivery retains the transcript for copy or retry.

- **Evidence:** `../docs/evidence/ui/windows-beta6/` contains light, dark, onboarding,
settings-tab, minimum-window, and recorder-pebble Chromium captures with synthetic
Tauri IPC. These prove renderer
layout and frontend interactions. GitHub Actions provides native Windows compilation,
runtime inspection, and offline speech inference. A physical Windows test is still
required for microphone, global shortcut, editor insertion, installer policy, and
native Segoe rasterization.

## Do's and Don'ts

- Keep the Mac and Windows information architecture and visual tokens aligned.
- Preserve platform-specific labels, engines, permissions, and input behavior.
- Never claim synthetic browser evidence proves native Windows integration.
- Keep every model and transcription path local after the explicit model download.
- Use no paid API, subscription, account, or hosted transcription service.
