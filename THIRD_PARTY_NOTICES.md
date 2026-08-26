# Third-party notices

Dictate uses Swift Package Manager with Apple system frameworks including
SwiftUI, AppKit, AVFAudio, Speech, ApplicationServices, CoreGraphics, Combine,
Foundation, and UniformTypeIdentifiers. No reference-repository source, asset,
font, analytics SDK, or cloud service is included.

## FluidAudio 0.15.5

Dictate links the `FluidAudio` Swift package at version 0.15.5 from
https://github.com/FluidInference/FluidAudio. FluidAudio is distributed under
the Apache License 2.0. The complete license text is distributed by the
upstream package in `LICENSE`.

## WhisperKit

Dictate links WhisperKit from https://github.com/argmaxinc/WhisperKit.
WhisperKit is distributed under the MIT License. Its checkout also includes a
`NOTICES` file for Apache-2.0-licensed code derived from Hugging Face's
`swift-transformers`; both files remain authoritative for the resolved package
version.

## NVIDIA Parakeet TDT 0.6B v3 Core ML model

Dictate downloads the on-device model from
https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml. The model
repository identifies its license as Creative Commons Attribution 4.0
International (CC BY 4.0). Model attribution: NVIDIA NeMo Parakeet TDT v3,
converted for Core ML by Fluid Inference. See the model card and the linked
license before redistributing downloaded model artifacts.

## Other downloadable speech models

Dictate can also request these model repositories when the user selects and
downloads the corresponding model:

- `FluidInference/parakeet-tdt-0.6b-v2-coreml`
- `FluidInference/parakeet-tdt-ctc-110m-coreml`
- `argmaxinc/whisperkit-coreml` (the selected Whisper variant)

These model files are not bundled in `Dictate.app` or the DMG. Their model cards
and license files govern downloaded artifacts and should be reviewed before
redistribution.
