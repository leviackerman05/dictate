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
    var modelStatus: RecognitionModelStatus { get }
    func prepare() async throws
    func transcribe(
        stream: AsyncStream<AudioChunk>,
        contextualVocabulary: [String],
        onPartial: @escaping (String) -> Void,
        onLevel: @escaping (Double) -> Void
    ) async throws -> String
    func cancel()
}

enum RecognitionModelStatus: Equatable, Sendable {
    case notInstalled
    case downloading(progress: Double?)
    case validating
    case loading
    case ready
    case failed
}

@MainActor
protocol FocusDelivering: AnyObject {
    func captureFocus(source: FocusCaptureSource) -> FocusSnapshot
    func rememberExternalFocus()
    func insert(_ text: String, into focus: FocusSnapshot?) async -> DeliveryResult
}

extension AudioCaptureService: AudioCapturing {}
extension SpeechRecognitionService: SpeechRecognizing {}
extension FocusSnapshotService: FocusDelivering {}
