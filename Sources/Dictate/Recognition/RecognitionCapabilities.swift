import Foundation
import Speech

@MainActor
enum RecognitionCapabilities {
    static var supportsApple: Bool {
        if #available(macOS 26, *) { return SpeechTranscriber.isAvailable }
        return false
    }

    static func supportsAppleLocale() async -> Bool {
        if #available(macOS 26, *), SpeechTranscriber.isAvailable {
            return await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) != nil
        }
        return false
    }

    static func makeAppleService() -> any SpeechRecognizing {
        if #available(macOS 26, *), supportsApple { return SpeechRecognitionService() }
        return UnavailableRecognitionService()
    }
}

@MainActor
private final class UnavailableRecognitionService: SpeechRecognizing {
    var modelIsAvailable: Bool { false }
    var modelStatus: RecognitionModelStatus { .notInstalled }
    func prepare() async throws { throw RecognitionError.onDeviceModelUnavailable }
    func prepareForOfflineBenchmark() async throws { throw RecognitionError.onDeviceModelUnavailable }
    func transcribe(stream: AsyncStream<AudioChunk>, contextualVocabulary: [String], onPartial: @escaping (String) -> Void, onLevel: @escaping (Double) -> Void) async throws -> String {
        throw RecognitionError.onDeviceModelUnavailable
    }
    func cancel() {}
}
