import Foundation
import WhisperKit

/// Owns a WhisperKit instance off the main actor.
///
/// `WhisperKit` is a non-Sendable reference type, so it cannot cross actor
/// isolation boundaries itself. All interaction with it happens inside this
/// wrapper's nonisolated methods; the wrapper is then handed to the
/// `@MainActor` service as `@unchecked Sendable`. Dictate drives recognition
/// strictly single-flight (one dictation session at a time), which makes the
/// unchecked conformance safe.
final class WhisperEngine: @unchecked Sendable {
    private let kit: WhisperKit

    /// Creates and loads the engine for a variant whose models are already on
    /// disk. Compilation/specialization of the Core ML models happens here and
    /// can take minutes the first time a variant is used.
    static func make(variant: String, modelFolder: URL) async throws -> WhisperEngine {
        let config = WhisperKitConfig(
            model: variant,
            modelFolder: modelFolder.path,
            verbose: false,
            load: true,
            download: false
        )
        let kit = try await WhisperKit(config)
        return WhisperEngine(kit: kit)
    }

    private init(kit: WhisperKit) {
        self.kit = kit
    }

    /// Transcribes 16 kHz mono float samples into concatenated text.
    func transcribe(samples: [Float]) async throws -> String {
        let results = try await kit.transcribe(audioArray: samples)
        guard !Task.isCancelled else { throw RecognitionError.cancelled }
        return results.map(\.text).joined(separator: " ")
    }
}
