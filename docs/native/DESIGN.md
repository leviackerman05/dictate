---
name: Dictate native onboarding refinement
description: Scoped conventions for the reviewed SwiftUI onboarding overlay.
rounded:
  onboarding: "18px"
  recording-options: "12px"
spacing:
  onboarding-padding: "32px"
  section-gap: "22px"
  options-padding: "28px"
  error-padding: "24px"
components:
  onboarding-panel:
    width: "740px"
    height: "600px"
    padding: "{spacing.onboarding-padding}"
    rounded: "{rounded.onboarding}"
  options-sheet:
    width: "560px"
    padding: "{spacing.options-padding}"
  error-popover:
    width: "380px"
    padding: "{spacing.error-padding}"
---

# Design System: Dictate native onboarding refinement

## Overview

**Creative North Star: "A calmer writing instrument"**

Keep first setup focused on microphone access, speech-model preparation, and optional cursor insertion. This records the finished native onboarding refinement only; the existing SwiftUI design system remains authoritative for the rest of the app.

Sources: `../../Sources/Dictate/OnboardingView.swift`, the onboarding overlay in `../../Sources/Dictate/MainWindowView.swift`, and `DesignSystem.Layout` in `../../Sources/Dictate/DesignSystem.swift`. Review disposition: **ship** for the reviewed native UI scope. The three reviewed first-use, onboarding, and options captures remain local; this document does not embed or publish them.

## Colors

Reuse the existing adaptive `DesignSystem.ColorToken` palette: `surface` and `primaryText` for the panel, `secondaryText` for supporting copy, `action` for setup and insertion cues, `success` for ready states, and `failure` for the error-details action. Preserve the app's light/dark appearance behavior and native control rendering.

## Typography

Retain the existing `BrandTitle`, the bold system-serif onboarding heading (30pt), and system-sans supporting text (13pt). Step labels use SwiftUI headline styles; details and progress use caption styles. The options sheet uses a bold title2 heading and the existing rounded recording-control labels. No new font or type system is introduced.

## Layout

The core onboarding panel is fixed at 740 × 600 points with 32-point padding and 22-point spacing between major groups. Keep its required setup path and footer actions visible without a core scroll view. The host window provides at least the panel height plus 32 points while onboarding is active.

Move model selection and recording preferences into the separate 560-point-wide options sheet with 28-point padding. Long diagnostic text belongs in the 380-point-wide error popover, with 24-point padding and a scrollable diagnostic region capped at 140 points high. Frontmatter geometry uses portable CSS-unit notation; SwiftUI source values are points.

## Elevation & Depth

The main window sits behind a black scrim at 0.28 opacity. The onboarding overlay retains the existing shadow: black at 0.16 opacity, radius 24 points, vertical offset 8 points. Native sheet and popover presentation supply their own depth.

## Shapes

The core panel uses an 18-point corner radius and the existing one-point semantic border. The recording-options group retains its 12-point corners and capsule mode selector. Keep platform-native bordered, prominent, borderless, and link button styles.

## Components

- **Core setup:** Microphone permission, speech-model preparation, and optional insertion remain in reading order, separated by native dividers. “Start using Dictate” enables only when microphone permission is granted and the dictation controller reports ready; “Explore first” remains available.
- **Setup state:** Observe `PermissionService` and `DictationController` directly alongside `AppModel`, so permission and model-progress changes update the view. Refresh permissions on appearance and permission-change notifications. Show determinate download progress when available, otherwise the current preparation stage; preserve cancel and retry actions.
- **Options sheet:** Keep model and recording choices separate from the core panel. Disable model selection during setup, explain how to change models, and retain the Done default keyboard action.
- **Error popover:** Keep the core panel's error action brief. Show recovery guidance and selectable, bounded diagnostic text in the popover.
- **Modal background:** While onboarding is present, the underlying main-window content is disabled and accessibility-hidden. Keep the onboarding controls available to keyboard and accessibility navigation.

## Do's and Don'ts

- **Do** keep required setup and footer actions visible together in the fixed core panel.
- **Do** retain the existing SwiftUI palette, fonts, buttons, permission semantics, and controller observations.
- **Do** keep optional preferences and lengthy diagnostics in their separate presentations.
- **Don't** turn this refinement into a root design-system or portable Desktop redesign.
- **Don't** copy or publish the local review screenshots or private diagnostic content.
