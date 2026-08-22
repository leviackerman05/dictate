import DictateCore
import Foundation

@MainActor
protocol AudioCapturing: AnyObject {
    func start() throws -> AsyncStream<AudioChunk>
    func stop()
}

@MainActor
protocol SpeechRecognizing: AnyObject {
    var modelIsAvailable: Bool { get }
    func transcribe(
        stream: AsyncStream<AudioChunk>,
        contextualVocabulary: [String],
        onPartial: @escaping (String) -> Void,
        onLevel: @escaping (Double) -> Void
    ) async throws -> String
    func cancel()
}

@MainActor
protocol FocusDelivering: AnyObject {
    func captureFocus() -> FocusSnapshot
    func insert(_ text: String, into focus: FocusSnapshot?, allowAutomaticInsertion: Bool) -> DeliveryResult
}

extension AudioCaptureService: AudioCapturing {}
extension SpeechRecognitionService: SpeechRecognizing {}
extension FocusSnapshotService: FocusDelivering {}
