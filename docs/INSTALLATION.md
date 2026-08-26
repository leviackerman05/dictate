# Installing Dictate

Dictate requires Apple silicon and macOS 26 or newer.

## Community DMG

When a GitHub release includes `Dictate.dmg`:

1. Download `Dictate.dmg` and `Dictate.dmg.sha256` from the same release.
2. Verify the checksum:

   ```sh
   shasum -a 256 -c Dictate.dmg.sha256
   ```

3. Open the DMG and drag Dictate to Applications.
4. The current community build is ad-hoc signed, not Developer ID signed or
   notarized. If Gatekeeper blocks the first launch, Control-click Dictate in
   Applications, choose **Open**, then confirm **Open**.

Do not disable Gatekeeper or remove quarantine attributes system-wide. A future
Developer ID-signed and notarized build should open normally; its release notes
must say so explicitly rather than reusing the community-build instructions.

## Build from source

Install full Xcode with the macOS 26 SDK, then run:

```sh
swift test
make app
open build/Dictate.app
```

The bundle uses `app.dictate.desktop` by default. A local developer can override
it without editing tracked files:

```sh
DICTATE_BUNDLE_IDENTIFIER=com.example.dictate make app
```

## Reproduce the release checks

```sh
make preflight
```

This builds the release app and DMG, checks architecture, deployment target,
bundle metadata, usage strings, resources, signature integrity, model exclusion,
DMG contents, and writes `dist/Dictate.dmg.sha256`. It reports the actual signing
and Gatekeeper state; it does not sign with Developer ID or submit to Apple.
