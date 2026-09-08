# Portable fixtures

`portable-dictionary.json` is shared by Swift and Rust correction tests. It uses
schema 1 and whole-second ISO 8601 timestamps compatible with both apps.

`synthetic-speech.f32` contains mono 16 kHz little-endian float32 PCM, generated
on 2026-09-08 using the host Mac's built-in `say -v Samantha`, then converted
with `afconvert`. It says: “This is a local dictation test. Keep my words on this
computer.” No human recording, microphone input, or personal data is included.
It is test data only and is not packaged in user installers. The smoke test
loads the verified public Whisper Tiny model; inference runs offline.
