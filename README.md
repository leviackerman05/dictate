<p align="center">
  <img src="Sources/Dictate/Resources/AppIcon.svg" width="104" height="104" alt="Dictate app icon">
</p>

<h1 align="center">Dictate</h1>

<p align="center">Hold a key. Say what you mean. Release and keep writing.</p>

<p align="center">
  Website: <a href="https://dictate-macos.vercel.app">dictate-macos.vercel.app</a>
</p>

<p align="center">
  <a href="https://github.com/leviackerman05/dictate/releases/latest/download/Dictate.dmg"><img alt="Download Dictate" src="https://img.shields.io/badge/Download-Dictate.dmg-3155D9?style=for-the-badge&logo=apple&logoColor=white"></a>
  <a href="https://dictate-macos.vercel.app"><img alt="Dictate website" src="https://img.shields.io/badge/Visit-Website-4E7C62?style=for-the-badge&logo=vercel&logoColor=white"></a>
  <a href="https://github.com/leviackerman05/dictate/releases"><img alt="GitHub releases" src="https://img.shields.io/badge/GitHub-Releases-4E7C62?style=for-the-badge&logo=github&logoColor=white"></a>
</p>

<p align="center">
  <img alt="macOS 26 or newer" src="https://img.shields.io/badge/macOS-26%2B-3155D9?style=flat-square">
  <img alt="Apple silicon" src="https://img.shields.io/badge/Apple%20silicon-native-4E7C62?style=flat-square">
  <img alt="Local first" src="https://img.shields.io/badge/transcription-local%20first-3155D9?style=flat-square">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-4E7C62?style=flat-square&logo=swift&logoColor=white">
</p>

<p align="center">
  <img src="docs/evidence/ui/dictate-dashboard.png" width="1100" alt="Dictate dashboard in dark mode">
</p>

Dictate is a small macOS app for getting spoken words into the field you are
already using. Pick a shortcut, hold it while you speak, and release it to
finish. If Dictate cannot safely return the words to your current field, the
transcript stays available to copy instead.

Recognition and correction run on your Mac after the selected model is
installed. There is no account, telemetry, analytics service, or raw-audio
file. Accessibility is optional: without it, Dictate keeps completed text
available to copy instead of repeatedly asking for permission.

## Download

[Check the Releases page](https://github.com/leviackerman05/dictate/releases) for
a release that contains `Dictate.dmg` and `Dictate.dmg.sha256`. If no DMG is
attached yet, build from source below.

Dictate currently requires macOS 26 or newer on Apple silicon. Public builds are
distributed through GitHub Releases. This is currently an open-source community
build: it is not signed with an Apple Developer ID or notarized by Apple. After
dragging Dictate to Applications, macOS may ask you to Control-click the app and
choose **Open** the first time. See the full [installation and checksum
guide](docs/INSTALLATION.md); it does not recommend disabling macOS security.

## Using Dictate

1. Allow Microphone access. Allow Accessibility access if you want automatic
   insertion into other apps.
2. Choose a trigger key and either **Hold to talk** or **Click to toggle**.
3. Put the cursor in a text field, then dictate.
4. Review previous transcripts in History or teach Dictate names and preferred
   corrections in Dictionary.

Dictate supports Apple's on-device speech model, NVIDIA Parakeet, and Whisper.
Apple may install an OS-managed speech asset, while Parakeet and Whisper models
are downloaded from their documented Hugging Face repositories. Raw microphone
audio is only used for the active recording session and is not written to disk.

<p align="center">
  <img src="docs/evidence/ui/dictate-statistics.png" width="1100" alt="Dictate statistics screen in dark mode">
</p>

## Build it locally

You will need Swift 6.2 or newer and the macOS 26 SDK.

```sh
swift test
swift build -c release --product Dictate
make app
```

The app bundle will be written to `build/Dictate.app`. To use your own bundle
identifier:

```sh
DICTATE_BUNDLE_IDENTIFIER=com.example.dictate make app
```

Launch the locally built app with:

```sh
open build/Dictate.app
```

To reproduce the release package checks:

```sh
make preflight
```

This creates an arm64 app and DMG, validates bundle metadata, permissions text,
resources, signature integrity, DMG contents, and produces a SHA-256 checksum.
It reports the current ad-hoc signing state; it does not Developer ID sign or
notarize the build.

## Benchmark recognition locally

The benchmark uses the same recognizers as the app, accepts your own audio and
reference transcript, and writes machine-readable JSON plus a Markdown report.
It never downloads a model; prepare the model in Dictate first.

```sh
make benchmark ARGS='--audio /path/to/sample.wav \
  --reference /path/to/reference.txt \
  --engine apple --engine parakeet --engine whisperBase \
  --json /tmp/dictate-benchmark.json \
  --markdown /tmp/dictate-benchmark.md'
```

Each result records the engine and model, hardware and OS, audio and recognition
duration, real-time factor, word error rate when a reference is supplied, raw
recognizer output, and explicit unavailable or failure details. Dictionary
correction and text insertion are intentionally excluded so the recognition
result stays comparable. No benchmark result is checked into this repository.

## Test

```sh
swift test
swift build -c release --product Dictate
```

The suite covers shortcut state transitions, transcript recovery, deterministic
dictionary correction, focus-target policy, paste-first editor delivery, guarded
pasteboard restoration, and benchmark metric calculation. Live cross-app focus
and insertion checks remain a manual macOS integration step documented in the
[compatibility matrix](docs/evidence/manual-compatibility-matrix.md).

## Project notes

- [Privacy policy](PRIVACY.md)
- [Installation and release checks](docs/INSTALLATION.md)
- [Release-readiness audit](docs/release-readiness-audit.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Design system](docs/DESIGN_SYSTEM.md)
- [Dictionary format](docs/DICTIONARY_SCHEMA.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)

Dictate is still early. If something behaves differently in a particular app,
please [open an issue](https://github.com/leviackerman05/dictate/issues) and say
which app and macOS version you were using.

## License

Dictate is available under the [MIT License](LICENSE).
