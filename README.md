# Dictate

Dictate is a native macOS push-to-talk dictation notebook for writers, founders,
researchers, and developers. Hold a shortcut, speak, release, and Dictate
transcribes locally, applies deterministic personal corrections, and inserts the
result into the text field that was focused before recording.

The product is called Dictate everywhere and uses the configurable development
bundle identifier `app.dictate.desktop`. The bundle script accepts
`DICTATE_BUNDLE_IDENTIFIER` for an owner-controlled reverse-DNS identifier later.

## Requirements

- macOS 26 or newer at runtime.
- Swift 6.2 or newer and Xcode with the macOS 26 SDK for the full app build.
- Microphone and Speech Recognition permissions for recording.
- Accessibility permission for automatic insertion into another application.
  Dictate remains useful for copying transcripts without it.

The included SwiftPM manifest uses a compatibility platform floor because the
Command Line Tools manifest API available in some environments predates the
macOS 26 enum. The produced app bundle enforces `LSMinimumSystemVersion` 26.0.

## Build and test

From the repository root:

```sh
swift test
swift build -c release --product Dictate
make app
```

`make app` creates `build/Dictate.app`. To use an owner-controlled development
identifier:

```sh
DICTATE_BUNDLE_IDENTIFIER=com.example.dictate make app
```

The bundle script creates a normal Dock application with a resizable SwiftUI
window, app menu, Settings scene, menu bar item, resource bundle, permissions
usage descriptions, and the original vector icon source.

## Install and uninstall

For a local install:

```sh
mkdir -p "$HOME/Applications"
cp -R build/Dictate.app "$HOME/Applications/Dictate.app"
open "$HOME/Applications/Dictate.app"
```

Remove that local copy by moving `$HOME/Applications/Dictate.app` to the Trash.
This does not remove local history or dictionary data. Those live under the user
Application Support directory in the `Dictate` folder and can be removed from
the app's own controls or Finder after quitting the app.

## First run and permissions

The first-run window checks Microphone, Speech Recognition, and Accessibility in
that order, derives state from Apple's permission APIs, opens the relevant System
Settings pane, and rechecks when Dictate becomes active again. Accessibility is
optional for notebook/copy use; the insertion status is explicit when it is not
available. Dictate does not use a stored “completed” flag as permission truth and
does not issue privacy-reset commands.

## Privacy

Speech recognition is requested in on-device mode. Raw audio is streamed through
the active session and never stored. History and the personal dictionary are
local JSON documents written atomically; no account, analytics, tracking,
advertising, telemetry, or cloud dependency exists. See [PRIVACY.md](PRIVACY.md).

## Features implemented

- Deterministic `idle → preparing → listening → transcribing → inserting → idle`
  state machine with cancellation, silence handling, failure states, and busy
  finalization protection.
- Right Option, Fn, Right Command, and a shortcut model ready for recording a
  custom non-conflicting shortcut. Repeated modifier events are de-duplicated.
- Ordered copied audio stream, on-device Speech adapter, contextual vocabulary,
  focus snapshot, Accessibility insertion, and pasteboard/Command-V fallback.
- Personal dictionary with vocabulary and correction entries; search, filters,
  enable/disable, add/edit/delete, import/merge/replace validation, export, JSON
  schema, risk warnings, bounded vocabulary selection, and correction audit.
- Searchable, grouped history with pin, copy, retry insertion, multi-select
  deletion, retention, export, and an empty-state Start recording action.
- SwiftUI split-view interface, Settings scene, onboarding, menu bar controls,
  non-activating recording overlay, reduced-motion breath line, accessibility
  labels/state announcements, localized English string catalog, and original
  caret/breath-line vector icon.

## Documentation

- [Design system and wireframes](docs/DESIGN_SYSTEM.md)
- [Architecture and concurrency boundaries](docs/ARCHITECTURE.md)
- [Dictionary schema and matching algorithm](docs/DICTIONARY_SCHEMA.md)
- [Privacy policy](PRIVACY.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)
- [Execution checklist and verification boundary](docs/EXECUTION_CHECKLIST.md)

## Verification status

Verified in the available environment:

- Swift 6 source typechecking for all `DictateCore` files.
- Swift 6 macOS source typechecking for all `Dictate` files against the macOS 26
  SDK, with no source errors.
- Repository audit for copied reference names, generated artifacts, and secrets.

Not verifiable in this environment:

- `swift test` and full `swift build`: the installed Command Line Tools have a
  Swift compiler/SDK revision mismatch and no XCTest module/full Xcode runtime.
- Human microphone, Speech model installation, Accessibility insertion,
  pasteboard restoration, VoiceOver, and visual screenshot verification on a
  signed macOS 26 machine.

The GitHub Actions workflow runs `swift test` and a release build on a macOS
runner with the normal Xcode toolchain.
