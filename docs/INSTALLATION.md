# Installing Dictate

The [download page](https://dictate-macos.vercel.app/download) suggests an
installer for your operating system; you can always choose another computer. These community builds are free and use local speech recognition.
No Xcode, Rust, Node, Python, Git, account, or paid API is needed to use them.
Initial model setup requires an internet connection; dictation then works offline.

## Mac: install, open, set up

Requires Apple silicon and macOS 14+. Intel installers are not published. This
beta compiles for macOS 14; older-OS runtime testing remains pending.

1. Open `Dictate.dmg` and drag Dictate to **Applications**.
2. Open **Dictate** from Applications or Spotlight.
3. Allow microphone access and choose a speech model in setup. Grant
   Accessibility only if you want automatic insertion into other apps.

On supported macOS 26 devices, Apple recognition is the default and uses an OS-managed asset.
Existing saved model choices are preserved. Open **Setup options** to change your model or shortcut.
Older macOS uses a downloadable local model. Setup shows progress, supports
cancel/retry, and does not silently download a different model on launch.

The community app is ad-hoc signed, not Developer ID signed or notarized. For
an **unverified developer / cannot verify** warning from a trusted download,
first attempt to open it and choose **Done** in the warning. Open **System Settings →
Privacy & Security** and scroll toward the bottom of the main page to **Security**,
below “Allow applications from.” Click **Open Anyway** beside the Dictate message,
authenticate, then confirm **Open**. This is not inside **Files and Folders**.
If the button is missing, try opening the app again and return to this page.
The download page includes a screenshot of the exact row to look for.
[Apple's guide](https://support.apple.com/en-us/102445).

A warning that malware **was detected**, the app **will damage your computer**,
or the app **is damaged** is different:
stop and check the release and checksum. Do not disable Gatekeeper or remove
quarantine. Work administrators may prohibit unnotarized apps; this project
cannot override that policy for free or otherwise.

Applications is the expected installed location. `build/Dictate.app` exists
only after building source. For troubleshooting, use Finder or
`open /Applications/Dictate.app` (or `open ~/Applications/Dictate.app` for a
per-user installation).

### Optional repository launcher

After cloning or extracting a repository ZIP, run:

```sh
./Scripts/start.sh
```

`./Scripts/start.sh --check` only checks OS/architecture. The launcher installs
the release pinned in `Release/version.txt`, verifies its SHA-256 manifest and
bundle signature, preserves download quarantine, and opens the exact installed
path. Quit Dictate before updating. History, preferences, and models stay in
Application Support. It does not compile your edits. A cloned repository still
needs Git to clone; downloading its ZIP does not.

## Windows beta

1. Run `Dictate-Windows-x64-setup.exe` on Windows 10/11 x64.
2. Open Dictate; NVIDIA Parakeet starts downloading automatically (670 MB). Cancel or choose Whisper Tiny (78 MB) in Setup options if you prefer.
3. Start recording, allow the microphone if prompted, then finish. Use the
   global shortcut in a destination editor or copy the result from Dictate.

The per-user installer needs no compiler. It can install Microsoft's free
WebView2 runtime when missing. It is unsigned: Windows may display an
unknown-publisher/SmartScreen warning. Proceed only for a trusted download and
according to your organization's policy; do not bypass malware detections.

**Smart App Control (Windows 11):** If the message says “Smart App Control
blocked an app that may be unsafe,” there is no **Run anyway** button or
per-app exception. This unsigned beta may not run while that protection is
active. We do not recommend disabling Windows protection to install Dictate.
A managed work computer may also have administrator-enforced restrictions.

**SmartScreen:** A “Windows protected your PC” reputation warning is different.
It may offer **More info → Run anyway** if policy permits. Only use that option
for a download you trust; it does not override Smart App Control.
[Microsoft’s Smart App Control FAQ](https://support.microsoft.com/en-us/windows/security/threat-malware-protection/smart-app-control-frequently-asked-questions).

Automatic insertion uses Windows accessibility to validate the current editor,
then sends Unicode text without changing your clipboard. Elevated, password,
and inaccessible fields keep the transcript ready to copy. If confirmation is
uncertain, inspect the destination before retrying to avoid duplicate text.

Right Ctrl is the default recording shortcut. Change it in Settings → Recording
shortcut; changes save automatically. The idle indicator can be hidden in
Settings → General. Quit Dictate from the tray menu before updating; closing
the window only hides it. See [Windows notes](../Desktop/README.md) for models
and local-data details.

## Linux support is paused

Current builds and development support are limited to Mac and Windows. Older
Linux release assets are unsupported previews; Linux build and installation
instructions have been withdrawn.

## Verify a download (optional)

Download the artifact and its matching `.sha256` from the same release. On Mac
run `shasum -a 256 -c Dictate.dmg.sha256`.
On Windows use `Get-FileHash .\Dictate-Windows-x64-setup.exe -Algorithm SHA256`
and compare it with the release's checksum. `manifest.json` also records all
file sizes and hashes. A matching checksum confirms integrity, not notarization.

## Build from source

See the main README for [Mac](../README.md#mac) and
[Windows](../README.md#windows) prerequisites, build commands, and output paths.
Optional tests and packaging checks are in the [developer guide](DEVELOPMENT.md).
