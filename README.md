<p align="center">
  <img src="Sources/Dictate/Resources/AppIcon.svg" width="104" height="104" alt="Dictate app icon">
</p>

<h1 align="center">Dictate</h1>

<p align="center">Hold a key. Say what you mean. Release and keep writing.</p>

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

Everything runs on your Mac. There is no account, analytics service, or stored
raw audio.

## Download

[Download the latest DMG](https://github.com/leviackerman05/dictate/releases/latest/download/Dictate.dmg), open it, and drag Dictate into Applications.

Dictate currently requires macOS 26 or newer on Apple silicon. Public builds are
distributed through GitHub Releases. Until they are Developer ID signed and
notarized, macOS may ask you to Control-click Dictate and choose **Open** the
first time.

## Using Dictate

1. Allow Microphone access. Allow Accessibility access if you want automatic
   insertion into other apps.
2. Choose a trigger key and either **Hold to talk** or **Click to toggle**.
3. Put the cursor in a text field, then dictate.
4. Review previous transcripts in History or teach Dictate names and preferred
   corrections in Dictionary.

Dictate supports Apple's on-device speech model, NVIDIA Parakeet, and Whisper.
Raw audio is only used for the active recording session and is never saved.

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

## Project notes

- [Privacy policy](PRIVACY.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Design system](docs/DESIGN_SYSTEM.md)
- [Dictionary format](docs/DICTIONARY_SCHEMA.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)

Dictate is still early. If something behaves differently in a particular app,
please [open an issue](https://github.com/leviackerman05/dictate/issues) and say
which app and macOS version you were using.
