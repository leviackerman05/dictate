# Dictate architecture

## Module boundaries

`DictateCore` is a platform-independent Swift target. It contains dictionary
models, the correction engine, atomic/history models, retention, and the
deterministic state machine. The `Dictate` executable contains SwiftUI views and
narrow AppKit adapters.

```text
SwiftUI views ── AppModel ── DictationController
                              ├─ AudioCaptureService → AsyncStream<AudioChunk>
                              ├─ SpeechRecognitionService → on-device Speech
                              ├─ FocusSnapshotService → AXUIElement / pasteboard
                              ├─ PermissionService → platform permission APIs
                              └─ DictateCore matcher + stores
```

`TranscriptRewriter` is a protocol in the core target. v1 uses
`NoOpTranscriptRewriter`; no cloud or LLM implementation is present.

## State machine

```text
idle → preparing → listening → transcribing → inserting → idle
  └────────────── any active state ───────────────→ failed
  └────────────── cancellation ──────────────────→ idle
```

The value type `DictationStateMachine` accepts explicit events. A second start
while inserting returns `ignoredWhileFinalizing`; cancellation cannot commit a
partial transcript. Silence resets to idle without an archive item or insertion.

## Concurrency

UI-observable objects are `@MainActor`. The audio callback copies samples and
`yield`s them into one ordered `AsyncStream`; it never creates one task per audio
buffer. Recognition has one consumer task for the stream and one Speech task.
Stores are actors and use atomic JSON writes. Core value types are `Sendable` so
test fakes can cross task boundaries without shared mutable state.

The current adapter uses Apple's public `SFSpeechAudioBufferRecognitionRequest` in
on-device mode and exposes unavailable model state. macOS manages Speech model
assets; there is no public installer API that can be safely driven by this app.

## Delivery

Focus is captured before audio starts. Direct Accessibility insertion sets the
selected text attribute on the previously focused element. The overlay is an
`NSPanel` with a non-activating style and cannot become key or main. If direct
insertion is not supported, a pasteboard snapshot is restored after a short delay
following synthetic Command-V. Failures create a visible failed insertion result.

## Persistence

History and dictionary documents use versioned Codable models. JSON encoders use
ISO-8601 dates and sorted pretty keys. `Data.write(options: .atomic)` ensures a
failed encode or write leaves the prior valid file in place. Raw audio never enters
the persistence layer.
