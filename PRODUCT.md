# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS

## Users

Dictate is for people who want to speak short passages directly into whichever text
field they are already using. The primary user is the repository owner; broader
audience descriptions remain an open decision.

## Product Purpose

Hold a configured shortcut, speak, release, and receive accurate local transcription
at the previously focused cursor. Dictate preserves completed text in History and
lets the user teach recognition and deterministic replacements through Dictionary.
Success means the interaction is fast enough to disappear into ordinary writing.

## Positioning

Dictate is an OS-level writing input utility, not a notetaker. Its distinguishing
workflow is push-to-talk delivery into the current text field, backed by a transparent
personal correction dictionary and local recovery history.

## Operating Context

Dictate runs while another macOS application has an editable field focused. The user
holds a global shortcut, speaks, and releases it without switching applications. A
small non-activating recorder appears at the bottom of the screen. The main app is
opened mainly to review History, manage Dictionary, or adjust Settings.

## Capabilities and Constraints

- Native macOS application.
- Primary destinations are History and Dictionary; Settings is secondary.
- Hold-to-talk stops on physical key release.
- Click-to-toggle stops on the next shortcut press.
- Completed text is inserted at the original cursor when permission and a valid target
  permit it.
- When insertion is unavailable, the text remains in History and a visible Copy action
  prevents loss.
- Apple SpeechTranscriber and NVIDIA Parakeet TDT 0.6B v3 are the intended local
  transcription providers.
- No notetaker, document editor, meeting bot, folders, projects, AI chat, or cloud
  rewrite workflow.
- Every selectable theme must cover the entire app, Settings, onboarding, empty/error
  states, and the global recorder overlay in coordinated light and dark modes.

## Brand Commitments

- Product name: Dictate.
- The approved visual world is **Color Index**: warm paper-white and graphite surfaces,
  cobalt action color, and restrained amber, moss, and coral indexing accents.
- The main app has no permanent sidebar. History uses a horizontal date index;
  Dictionary uses a compact list-and-editor workspace; Settings uses calm grouped
  controls.
- The global recorder is the **Signal Pebble**, including an ultra-quiet persistent
  `Dictate ready` state when the service is available but is not capturing audio.
- The Dictate mark is a minimal paper-white paragraph form with a cobalt voice point.
  It represents speech resolving into written text without a microphone, waveform,
  quotation mark, or speech bubble.
- Light and dark appearances are equally authored parts of the same identity.

## Evidence on Hand

- Existing SwiftUI implementation under `Sources/Dictate/`.
- Existing current-state audit at `docs/CURRENT_STATE_AUDIT.md`.
- Existing repair prompt at `PROMPT_BUILDER_REPAIR_AND_GUI.md`.
- The running app has demonstrated accurate transcription into History.
- Approved visual references live under `docs/final-design/`.

## Product Principles

1. Speak and return to work.
2. Never lose successfully transcribed text.
3. Make recording state unmistakable without showing distracting live prose.
4. Keep personal language and history understandable and under the user's control.
5. Visual expression must never compromise shortcut reliability or text delivery.

## Accessibility & Inclusion

All themes must preserve keyboard navigation, VoiceOver labels, sufficient contrast,
non-color state cues, increased-contrast behavior, reduced transparency, and Reduce
Motion. Light and dark modes are equally designed products, not automatic inversions.
