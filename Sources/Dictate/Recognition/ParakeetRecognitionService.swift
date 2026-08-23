import Foundation
import Combine
import FluidAudio

@MainActor
final class ParakeetRecognitionService: ObservableObject, SpeechRecognizing {
    @Published private(set) var modelStatus: RecognitionModelStatus = .notInstalled
    var modelStatusPublisher: Published<RecognitionModelStatus>.Publisher { $modelStatus }

    var modelIsAvailable: Bool { modelStatus == .ready }

    func prepare() async throws {
        guard !modelIsAvailable else { return }
        modelStatus = .downloading(progress: nil)
        do {
            _ = try await ParakeetModels.shared.manager { [weak self] progress, phase in
                Task { @MainActor in
                    guard let self else { return }
                    switch phase {
                    case .downloading: self.modelStatus = .downloading(progress: progress)
                    case .validating: self.modelStatus = .validating
                    case .loading: self.modelStatus = .loading
                    }
                }
            }
            modelStatus = .ready
        } catch is CancellationError {
            modelStatus = .notInstalled
            throw RecognitionError.cancelled
        } catch {
            modelStatus = .failed
            throw error
        }
    }

    func transcribe(
        stream: AsyncStream<AudioChunk>,
        contextualVocabulary: [String],
        onPartial: @escaping (String) -> Void,
        onLevel: @escaping (Double) -> Void
    ) async throws -> String {
        try await prepare()
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
        let manager = try await ParakeetModels.shared.manager { _, _ in }
        var decoderState = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        let result = try await manager.transcribe(samples, decoderState: &decoderState)
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        onPartial(text)
        return text
    }

    func cancel() {}

    func removeDownloadedModel() {
        Task { @MainActor in
            await ParakeetModels.shared.remove()
            modelStatus = .notInstalled
        }
    }
}

private enum ParakeetLoadPhase: Sendable {
    case downloading
    case validating
    case loading
}

private actor ParakeetModels {
    static let shared = ParakeetModels()
    private var loaded: AsrManager?
    private var loadTask: Task<AsrManager, Error>?

    func manager(
        progress: @escaping @Sendable (Double?, ParakeetLoadPhase) -> Void
    ) async throws -> AsrManager {
        if let loaded { return loaded }
        if let loadTask { return try await loadTask.value }

        let task = Task<AsrManager, Error> {
            progress(nil, .downloading)
            let directory = try await AsrModels.download(
                version: .v3,
                encoderPrecision: .int8,
                progressHandler: { update in
                    progress(update.fractionCompleted, .downloading)
                }
            )
            try Task.checkCancellation()
            progress(nil, .validating)
            guard try await AsrModels.isModelValid(version: .v3, encoderPrecision: .int8) else {
                throw RecognitionError.onDeviceModelUnavailable
            }
            progress(nil, .loading)
            let models = try await AsrModels.load(
                from: directory,
                version: .v3,
                encoderPrecision: .int8
            )
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            return manager
        }
        loadTask = task
        do {
            let manager = try await task.value
            loaded = manager
            loadTask = nil
            return manager
        } catch {
            loadTask = nil
            throw error
        }
    }

    func remove() {
        loadTask?.cancel()
        loadTask = nil
        loaded = nil
        let directory = AsrModels.defaultCacheDirectory(for: .v3)
        try? FileManager.default.removeItem(at: directory)
    }
}
