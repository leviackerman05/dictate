# Dictate for Windows
<!-- impeccable:product-schema 1 -->

## Platform
web

## Stack
Existing TypeScript renderer inside a Tauri 2 Windows desktop application; Rust
microphone capture, local recognition and native input integration. The native
SwiftUI Mac app is the product and visual reference for this renderer.

## Users and purpose
People who want to dictate into their everyday applications without coding,
subscriptions, accounts or cloud transcription. The owner is testing the Windows
installer in Windows Sandbox before seeking signing approval.

## Capabilities and constraints
Recording, local model setup, history, dictionary corrections, statistics,
appearance preferences and recoverable text insertion must remain available.
User explicitly requests a complete Windows UI redesign and customizable
single-key or mouse-button shortcuts. Right Ctrl is the proposed default.
Parakeet support needs a Windows-compatible local runtime; do not label a model
available until its download, load and recognition path have been verified.
Mac and Windows are the only supported targets. All services and tools must be
free; no paid signing, APIs or hosting. Commit, push and publish a new installer
and update the website download after validation. The current installer is
unsigned and Smart App Control may block it outside a suitable test environment.

## Brand commitments
Keep the Dictate name, waveform mark and existing features. The user requires the
Windows app to match the Mac app closely in structure, features, palette,
typography, onboarding, and overall finish. Platform facts stay native: Windows
shortcut names, Windows permissions, and Windows-supported local models replace
Apple-only behavior.

## Evidence
The owner's eight current Windows screenshots are the redesign's anti-reference.
Repository code and README define product facts. UI previews use labeled synthetic
fixtures; CI recognition tests do not replace real microphone and editor tests.
