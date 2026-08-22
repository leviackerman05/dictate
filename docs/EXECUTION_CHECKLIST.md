# Dictate execution checklist

- [x] Confirm the available Swift toolchain and keep the implementation clean-room.
- [x] Define semantic visual tokens and original editorial voice-desk wireframes.
- [x] Scaffold Swift Package Manager targets and a documented `.app` bundle script.
- [x] Implement table-driven correction matching, schema validation, and atomic stores.
- [x] Implement the deterministic dictation state machine with cancellation and busy-session behavior.
- [x] Add protocol-shaped boundaries for capture, recognition, permissions, focus, insertion, and rewriting.
- [x] Add SwiftUI/AppKit main window, overlay, onboarding, settings, menu bar, localization scaffolding, and icon source.
- [x] Add unit tests for lexicon, archive, session, and interface state behavior.
- [x] Directly typecheck and link the Swift 6 sources against the macOS 26 SDK;
  run a standalone core smoke check where XCTest is unavailable.
- [ ] Human-verify microphone capture, Speech model availability, Accessibility insertion,
  fallback pasteboard restoration, VoiceOver, and screenshot appearance on a signed
  macOS 26 machine.

The local environment has Swift 6.3.2 Command Line Tools but no full Xcode. Direct
Swift 6 typechecking is used below; the package manifest itself is intended for the
full Xcode/macOS build environment.
