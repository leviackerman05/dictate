import Combine
import FluidAudio
import Foundation
import WhisperKit

/// Speech recognition backed by a locally downloaded WhisperKit Core ML model.
///
/// Loading is performed by `prepare()`. The controller calls it during its
/// explicit startup warm-up so Core ML specialization completes before the
/// first recording begins.
@MainActor
final class WhisperRecognitionService: ObservableObject, SpeechRecognizing {
    @Published private(set) var modelStatus: RecognitionModelStatus = .notInstalled
    var modelStatusPublisher: Published<RecognitionModelStatus>.Publisher { $modelStatus }

    private let variant: String
    private var engine: WhisperEngine?
    private var prepareTask: Task<Void, Error>?

    init(variant: String) {
        self.variant = variant
        // Cheap disk-only check; never loads the model at launch.
        refreshStatus()
    }

    var modelIsAvailable: Bool { modelStatus == .ready }

    /// Fast disk-presence check; safe to call on demand whenever status is shown.
    func refreshStatus() {
        switch modelStatus {
        case .downloading, .validating, .loading:
            return
        default:
            break
        }
        modelStatus = Self.isModelDownloaded(variant) ? .ready : .notInstalled
    }

    func prepare() async throws {
        // The engine is the real readiness signal: a model can be on disk
        // (status .ready from refreshStatus) without being loaded yet.
        guard engine == nil else {
            modelStatus = .ready
            return
        }
        if let inFlight = prepareTask {
            try await inFlight.value
            return
        }
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            try await self.performPrepare()
        }
        prepareTask = task
        defer { prepareTask = nil }
        try await task.value
    }

    private func performPrepare() async throws {
        guard engine == nil else {
            modelStatus = .ready
            return
        }
        do {
            let folder = try await ensureDownloaded()
            try Task.checkCancellation()
            // Loading specializes the Core ML models; the first run can take
            // minutes, which is why the .loading status is surfaced here.
            modelStatus = .loading
            engine = try await WhisperEngine.make(variant: variant, modelFolder: folder)
            try Task.checkCancellation()
            modelStatus = .ready
        } catch is CancellationError {
            modelStatus = .notInstalled
            throw RecognitionError.cancelled
        } catch {
            modelStatus = .failed
            throw error
        }
    }

    private func ensureDownloaded() async throws -> URL {
        let folder = Self.modelFolder(for: variant)
        guard !Self.isModelDownloaded(variant) else { return folder }
        modelStatus = .downloading(progress: nil)
        return try await WhisperKit.download(variant: variant) { [weak self] progress in
            Task { @MainActor in
                guard let self else { return }
                self.modelStatus = .downloading(progress: progress.fractionCompleted)
            }
        }
    }

    func transcribe(
        stream: AsyncStream<AudioChunk>,
        contextualVocabulary: [String],
        onPartial: @escaping (String) -> Void,
        onLevel: @escaping (Double) -> Void
    ) async throws -> String {
        try await prepare()
        // WhisperKit offers no contextual-vocabulary hook; the phrase list is
        // ignored for whisper models.
        var source: [Float] = []
        var sourceRate = 16_000.0
        for await chunk in stream {
            guard !Task.isCancelled else { throw RecognitionError.cancelled }
            sourceRate = chunk.sampleRate
            source.append(contentsOf: chunk.samples)
            let sum = chunk.samples.reduce(into: 0.0) { partial, sample in partial += Double(sample * sample) }
            let rms = chunk.samples.isEmpty ? 0 : sqrt(sum / Double(chunk.samples.count))
            onLevel(min(max(rms * 8, 0), 1))
        }

        guard source.count >= 1_600 else { return "" }
        let samples = try AudioConverter().resample(source, from: sourceRate)
        guard let engine else { throw RecognitionError.onDeviceModelUnavailable }
        let text = try await engine.transcribe(samples: samples)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        onPartial(trimmed)
        return trimmed
    }

    func cancel() {
        // WhisperKit exposes no API to interrupt an in-flight transcription;
        // Core ML inference runs to completion and its result is discarded via
        // the cancellation checks around the WhisperKit calls. A pending
        // prepare/download can be cancelled, though.
        prepareTask?.cancel()
    }

    func removeDownloadedModel() {
        prepareTask?.cancel()
        prepareTask = nil
        engine = nil
        let folder = Self.modelFolder(for: variant)
        try? FileManager.default.removeItem(at: folder)
        refreshStatus()
    }

    // MARK: - On-disk layout

    /// WhisperKit's default download base is `~/Documents/huggingface`; the
    /// model for a variant lives under `models/argmaxinc/whisperkit-coreml/<variant>`.
    private static func modelFolder(for variant: String) -> URL {
        HubApiWrapper().localRepoLocation(
            HubApiWrapper.Repo(id: "argmaxinc/whisperkit-coreml", type: .models)
        ).appending(path: variant)
    }

    private static func isModelDownloaded(_ variant: String) -> Bool {
        let folder = modelFolder(for: variant)
        let fileManager = FileManager.default
        for name in ["MelSpectrogram", "AudioEncoder", "TextDecoder"] {
            let url = ModelUtilities.detectModelURL(inFolder: folder, named: name)
            guard fileManager.fileExists(atPath: url.path) else { return false }
        }
        return true
    }
}
