# Third-party notices

Dictate uses Swift Package Manager with Apple system frameworks and the optional
FluidAudio package for the local Parakeet v3 provider. Apple frameworks include
SwiftUI, AppKit, AVFAudio, Speech, ApplicationServices, CoreGraphics, Combine,
Foundation, and UniformTypeIdentifiers.

FluidAudio is fetched from `https://github.com/FluidInference/FluidAudio.git`
(`from: 0.12.4`) and downloads its Parakeet model assets on first use. Review
that project's Apache 2.0 license and model notices when distributing a build.
No reference-repository source, asset, font, analytics SDK, cloud service, or
copied product implementation is included.
