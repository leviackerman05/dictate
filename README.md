<p align="center">
  <img src="Sources/Dictate/Resources/AppIcon.svg" width="104" height="104" alt="Dictate app icon">
</p>

<h1 align="center">Dictate</h1>

<p align="center">Hold a key. Say what you mean. Release and keep writing.</p>

<p align="center">
  Website: <a href="https://dictate-macos.vercel.app">dictate-macos.vercel.app</a>
</p>

<p align="center">
  <a href="https://dictate-macos.vercel.app/download"><img alt="Download Dictate" src="https://img.shields.io/badge/Download-Dictate.dmg-3155D9?style=for-the-badge&logo=apple&logoColor=white"></a>
  <a href="https://dictate-macos.vercel.app"><img alt="Dictate website" src="https://img.shields.io/badge/Visit-Website-4E7C62?style=for-the-badge&logo=vercel&logoColor=white"></a>
  <a href="https://github.com/leviackerman05/dictate/releases"><img alt="GitHub releases" src="https://img.shields.io/badge/GitHub-Releases-4E7C62?style=for-the-badge&logo=github&logoColor=white"></a>
</p>

<p align="center">
  <img alt="macOS 14 or newer" src="https://img.shields.io/badge/macOS-14%2B-3155D9?style=flat-square">
  <img alt="Apple silicon" src="https://img.shields.io/badge/Apple%20silicon-native-4E7C62?style=flat-square">
  <img alt="Local first" src="https://img.shields.io/badge/transcription-local%20first-3155D9?style=flat-square">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-4E7C62?style=flat-square&logo=swift&logoColor=white">
</p>

<p align="center">
  <img src="docs/evidence/ui/dictate-dashboard.png" width="1100" alt="Dictate dashboard in dark mode">
</p>

Dictate is a small native macOS app for getting spoken words into the field you are
already using. Pick a shortcut, hold it while you speak, and release it to
finish. If Dictate cannot safely return the words to your current field, the
transcript stays available to copy instead.

Recognition and correction run on your Mac after the selected model is
installed. There is no account, telemetry, analytics service, or raw-audio
file. Accessibility is optional: without it, Dictate keeps completed text
available to copy instead of repeatedly asking for permission.

## Download

[Download Dictate for Mac or Windows](https://dictate-macos.vercel.app/download).
The **v1.1.0-beta.7 community beta** includes the native Mac app and a Windows
app aligned to the same Dictate interface, with single-key shortcuts, dark mode,
and offline Parakeet recognition. No developer tools, account, API key, or payment is needed to
use an installer. Physical-device acceptance testing is still pending; see
[the validation record](docs/evidence/portability-validation.md).

| Platform | Installer | Requirements |
| --- | --- | --- |
| Mac | DMG; drag to Applications | Apple silicon, macOS 14+; Apple speech requires compatible macOS 26 |
| Windows beta | User installer | Windows 10/11, x64; free WebView2 runtime installed if missing |

Linux support is paused. Older Linux release assets are unsupported previews.
The unsigned Windows beta may be blocked by Smart App Control; see the
[installation guide](docs/INSTALLATION.md#windows-beta).

Mac builds are ad-hoc signed, without paid Apple signing or notarization. For an
unverified-developer warning, attempt to open the trusted app, then use **System
Settings → Privacy & Security**, scroll down to **Security**, and choose **Open Anyway**.
This is on the main page, not inside Files and Folders. A warning that malware
was detected, the app will damage your computer, or the app is damaged needs
investigation; do not bypass it. Managed computers may require an
administrator. See [installation and checksums](docs/INSTALLATION.md).

Already cloned or extracted the repository on a compatible Mac?

```sh
./Scripts/start.sh
```

This installs the pinned, checksum-verified prebuilt release and opens its actual
installed path. It never invokes Xcode or compiles local source changes.

## Using Dictate

1. Allow Microphone access and set up the speech model. On Mac the button is
   **Set up speech model**; **Enable insertion** opens the optional Accessibility step.
2. Use the suggested shortcut, or open **Setup options** on Mac to choose a
   trigger key and either **Hold to talk** or **Click to toggle**.
3. Put the cursor in a text field, then dictate.
4. Review previous transcripts in History or teach Dictate names and preferred
   corrections in Dictionary.

On supported macOS 26 Macs, setup defaults to Apple Speech, including a one-time
reset of older saved selections in beta 4. Later explicit choices are preserved.
The native Mac app supports Apple's on-device speech model where available,
NVIDIA Parakeet, and Whisper. Windows offers CPU Whisper Tiny/Base/Small and
NVIDIA Parakeet TDT v3 with verified in-app downloads. No NVIDIA GPU is needed.
On Windows, hold **Right Ctrl** to speak and release to finish. Assign a key,
combination, or middle/side mouse button in **Settings → Recording shortcut**,
and the change is saved immediately. Parakeet downloads 670 MB; 8 GB RAM is recommended.
Apple may install an OS-managed speech asset, while Parakeet and Whisper models
are downloaded from their documented Hugging Face repositories. Raw microphone
audio is only used for the active recording session and is not written to disk.

<p align="center">
  <img src="docs/evidence/ui/dictate-statistics.png" width="1100" alt="Dictate statistics screen in dark mode">
</p>

## Build it locally

Building the native Mac app requires full Xcode, Swift 6.2 or newer, and the
macOS 26 SDK. This is a developer requirement, separate from using the app.
For Windows development, see [Desktop/README.md](Desktop/README.md).

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
