import Foundation
import Combine
import FluidAudio

@MainActor
final class ParakeetRecognitionService: ObservableObject, SpeechRecognizing {
    @Published private(set) var modelStatus: RecognitionModelStatus = .notInstalled
    var modelStatusPublisher: Published<RecognitionModelStatus>.Publisher { $modelStatus }

    private let models: ParakeetModels

    init(modelVersion: AsrModelVersion = .v3) {
        models = ParakeetModels(version: modelVersion)
        Task { @MainActor [weak self] in
            await self?.refreshInstalledStatus()
        }
    }

    var modelIsAvailable: Bool { modelStatus == .ready }

    /// Re-checks the on-disk model and marks it ready when it is already
    /// valid — covering models downloaded by an earlier build or placed in
    /// the cache out of band. No-op while a download or load is in flight.
    func refreshStatus() {
        switch modelStatus {
        case .downloading, .validating, .loading:
            return
        default:
            break
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let installed = await self.models.isInstalled()
            self.modelStatus = installed ? .ready : .notInstalled
        }
    }

    private func refreshInstalledStatus() async {
        guard modelStatus == .notInstalled else { return }
        if await models.isInstalled() {
            modelStatus = .ready
        }
    }

    func prepare() async throws {
        // A valid model on disk is not the same as a model loaded into its
        // Core ML manager. Warm the manager here so the first recording never
        // pays the load cost after the user has already started speaking.
        if modelStatus == .notInstalled {
            modelStatus = .downloading(progress: nil)
        }
        do {
            _ = try await models.manager { [weak self] progress, phase in
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

    /// Loads an existing cache but never downloads model assets.
    func prepareForOfflineBenchmark() async throws {
        guard await models.isInstalled() else {
            throw RecognitionError.onDeviceModelUnavailable
        }
        try await prepare()
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
        let manager = try await models.manager { _, _ in }
        var decoderState = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        let result = try await manager.transcribe(samples, decoderState: &decoderState)
        guard !Task.isCancelled else { throw RecognitionError.cancelled }
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        onPartial(text)
        return text
    }

    func cancel() {
        // FluidAudio does not currently expose an inference cancellation API.
        // The owning session task is cancelled and the result is discarded;
        // explicit cancellation checks before and after inference keep it from
        // becoming a completed transcript.
    }

    func removeDownloadedModel() {
        Task { @MainActor in
            await models.remove()
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
    private let version: AsrModelVersion
    private var loaded: AsrManager?
    private var loadTask: Task<AsrManager, Error>?

    init(version: AsrModelVersion) {
        self.version = version
    }

    func manager(
        progress: @escaping @Sendable (Double?, ParakeetLoadPhase) -> Void
    ) async throws -> AsrManager {
        if let loaded { return loaded }
        if let loadTask { return try await loadTask.value }

        let task = Task<AsrManager, Error> {
            let directory: URL
            if await isInstalled() {
                directory = AsrModels.defaultCacheDirectory(for: version)
            } else {
                progress(nil, .downloading)
                directory = try await AsrModels.download(
                    version: version,
                    encoderPrecision: .int8,
                    progressHandler: { update in
                        progress(update.fractionCompleted, .downloading)
                    }
                )
            }
            try Task.checkCancellation()
            progress(nil, .validating)
            guard try await AsrModels.isModelValid(version: version, encoderPrecision: .int8) else {
                throw RecognitionError.onDeviceModelUnavailable
            }
            progress(nil, .loading)
            let models = try await AsrModels.load(
                from: directory,
                version: version,
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

    func isInstalled() async -> Bool {
        (try? await AsrModels.isModelValid(version: version, encoderPrecision: .int8)) == true
    }

    func remove() {
        loadTask?.cancel()
        loadTask = nil
        loaded = nil
        let directory = AsrModels.defaultCacheDirectory(for: version)
        try? FileManager.default.removeItem(at: directory)
    }
}
