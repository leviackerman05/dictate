// This file intentionally fails a shipping build when the real FluidAudio
// product is not available. There is no compile-time speech-provider stub.
#if canImport(FluidAudio)
import FluidAudio

let shippingParakeetIsLinked = true
#else
#error("Dictate shipping builds require the pinned FluidAudio product")
#endif
