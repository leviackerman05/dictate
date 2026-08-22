import Foundation

@MainActor
final class ParakeetRecognitionService: SpeechRecognizing {
    #if canImport(FluidAudio)
    var modelIsAvailable: Bool { true }

    func transcribe(
        stream: AsyncStream<AudioChunk>,
        contextualVocabulary: [String],
        onPartial: @escaping (String) -> Void,
        onLevel: @escaping (Double) -> Void
    ) async throws -> String {
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

        let samples = Self.resample(source, from: sourceRate, to: 16_000)
        guard samples.count >= 1_600 else { return "" }
        let manager = try await ParakeetModels.shared.manager()
        var decoderState = try TdtDecoderState()
        let result = try await manager.transcribe(samples, decoderState: &decoderState)
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        onPartial(text)
        return text
    }

    func cancel() {}

    private static func resample(_ input: [Float], from sourceRate: Double, to targetRate: Double) -> [Float] {
        guard !input.isEmpty, sourceRate > 0, abs(sourceRate - targetRate) > 0.5 else { return input }
        let outputCount = max(1, Int((Double(input.count) * targetRate / sourceRate).rounded()))
        return (0..<outputCount).map { index in
            let position = Double(index) * sourceRate / targetRate
            let lower = min(Int(position), input.count - 1)
            let upper = min(lower + 1, input.count - 1)
            let fraction = Float(position - Double(lower))
            return input[lower] + (input[upper] - input[lower]) * fraction
        }
    }
    #else
    var modelIsAvailable: Bool { false }

    func transcribe(
        stream: AsyncStream<AudioChunk>,
        contextualVocabulary: [String],
        onPartial: @escaping (String) -> Void,
        onLevel: @escaping (Double) -> Void
    ) async throws -> String {
        throw RecognitionError.onDeviceModelUnavailable
    }

    func cancel() {}
    #endif
}

#if canImport(FluidAudio)
import FluidAudio

private actor ParakeetModels {
    static let shared = ParakeetModels()
    private var loaded: AsrManager?
    private var loadTask: Task<AsrManager, Error>?

    func manager() async throws -> AsrManager {
        if let loaded { return loaded }
        if let loadTask { return try await loadTask.value }
        let task = Task<AsrManager, Error> {
            let models = try await AsrModels.downloadAndLoad(version: .v3, encoderPrecision: .int8)
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            return manager
        }
        loadTask = task
        do {
            let manager = try await task.value
            loaded = manager
            return manager
        } catch {
            loadTask = nil
            throw error
        }
    }
}
#endif
