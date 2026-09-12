# Developer checks

Start with the [Mac and Windows build instructions](../README.md#build-locally).
These checks are optional for building and using the app.

## Mac

Run from the repository root:

```sh
swift test
make preflight
```

`make preflight` builds the arm64 app and DMG, verifies bundle metadata,
permissions text, resources, signature integrity, and DMG contents, then writes
a SHA-256 checksum. It does not notarize the app.

To use a separate bundle identity for a developer build:

```sh
DICTATE_BUNDLE_IDENTIFIER=com.example.dictate make app
```

### Recognition benchmark

Prepare your chosen models in Dictate first. The benchmark uses the app's
recognizers and never downloads models:

```sh
make benchmark ARGS='--audio /path/to/sample.wav \
  --reference /path/to/reference.txt \
  --engine apple --engine parakeet --engine whisperBase \
  --json /tmp/dictate-benchmark.json \
  --markdown /tmp/dictate-benchmark.md'
```

Results include hardware, model, audio duration, recognition time, real-time
factor, and word error rate against the optional reference. Dictionary correction
and insertion are excluded. Live insertion checks are recorded in the
[compatibility matrix](evidence/manual-compatibility-matrix.md).

## Windows

Run in PowerShell from `Desktop` after `npm ci`:

```powershell
npm run build
npm test
node ../Scripts/prepare-desktop-runtime.mjs
cargo test --release --locked --manifest-path src-tauri/Cargo.toml --bin dictate-desktop
```

For the opt-in offline recognition smoke test, install Python 3.11+ and run
from the repository root:

```powershell
$env:DICTATE_SMOKE_DIR = Join-Path $env:TEMP 'dictate-smoke'
node Scripts/prepare-desktop-runtime.mjs
python Scripts/prepare-portable-smoke.py
$env:CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_RUNNER = 'powershell -NoProfile -File Scripts/run-windows-test.ps1'
cargo test --release --locked --manifest-path Desktop/src-tauri/Cargo.toml --test recognition_smoke -- --ignored --nocapture
```

This downloads checksum-verified Tiny and Parakeet models and recognizes a
synthetic fixture. It does not open a microphone. Real microphone, shortcut,
editor insertion, and Windows security-policy behavior still need device testing.

## Releases and website

[Release checks](../.github/workflows/release.yml) build both installers on
standard public GitHub runners and publish checksums only after validation.
[Windows Store signing preparation](../Release/windows-store/submission.md)
requires a Partner Center identity and certification.

See [Website/README.md](../Website/README.md) for website development and deployment.
