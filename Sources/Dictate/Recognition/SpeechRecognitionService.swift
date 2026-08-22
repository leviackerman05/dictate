@preconcurrency import AVFAudio
@preconcurrency import Speech
import Foundation

enum RecognitionError: Error, Sendable {
    case recognizerUnavailable
    case onDeviceModelUnavailable
    case requestFailed
    case cancelled
}

@MainActor
final class SpeechRecognitionService {
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var bufferConverter: AudioBufferConverter?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var feeder: Task<Void, Never>?
    private var resultsTask: Task<Void, Never>?
    private var resultContinuation: CheckedContinuation<String, Error>?
    private var didFinish = false

    var modelIsAvailable: Bool {
        SpeechTranscriber.isAvailable
    }

    func transcribe(
        stream: AsyncStream<AudioChunk>,
        contextualVocabulary: [String],
        onPartial: @escaping (String) -> Void,
        onLevel: @escaping (Double) -> Void
    ) async throws -> String {
        cancel()

        guard SpeechTranscriber.isAvailable,
              let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
            DictateLog.recognition.error("SpeechTranscriber is unavailable for the current Mac")
            throw RecognitionError.recognizerUnavailable
        }

        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        try await installAssets(for: transcriber)
        let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
            ?? AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
        let converter = AudioBufferConverter(outputFormat: analyzerFormat)
        let (inputStream, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        if !contextualVocabulary.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = contextualVocabulary
            try await analyzer.setContext(context)
        }

        try await analyzer.start(inputSequence: inputStream)

        self.analyzer = analyzer
        self.transcriber = transcriber
        self.bufferConverter = converter
        self.inputContinuation = inputContinuation
        self.didFinish = false

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                self.resultContinuation = continuation

                self.resultsTask = Task { @MainActor [weak self, transcriber] in
                    do {
                        var latestText = ""
                        for try await result in transcriber.results {
                            latestText = String(result.text.characters)
                            onPartial(latestText.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        self?.resolve(.success(latestText.trimmingCharacters(in: .whitespacesAndNewlines)))
                    } catch is CancellationError {
                        self?.resolve(.failure(RecognitionError.cancelled))
                    } catch {
                        DictateLog.recognition.error("SpeechAnalyzer result stream failed: \(String(describing: error), privacy: .public)")
                        self?.resolve(.failure(error))
                    }
                }

                self.feeder = Task { @MainActor [weak self, analyzer, converter, inputContinuation] in
                    do {
                        for await chunk in stream {
                            guard !Task.isCancelled else { throw RecognitionError.cancelled }
                            let sum = chunk.samples.reduce(into: 0.0) { partial, sample in partial += Double(sample * sample) }
                            let rms = chunk.samples.isEmpty ? 0 : sqrt(sum / Double(chunk.samples.count))
                            onLevel(min(max(rms * 8, 0), 1))

                            guard let buffer = Self.makeBuffer(chunk) else { continue }
                            for input in try converter.convert(buffer) {
                                inputContinuation.yield(input)
                            }
                        }

                        inputContinuation.finish()
                        try await analyzer.finalizeAndFinishThroughEndOfInput()
                    } catch is CancellationError {
                        inputContinuation.finish()
                        await analyzer.cancelAndFinishNow()
                    } catch {
                        inputContinuation.finish()
                        await analyzer.cancelAndFinishNow()
                        self?.resolve(.failure(error))
                    }
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel() }
        }
    }

    func cancel() {
        feeder?.cancel()
        feeder = nil
        resultsTask?.cancel()
        resultsTask = nil
        inputContinuation?.finish()
        inputContinuation = nil
        let analyzer = analyzer
        self.analyzer = nil
        transcriber = nil
        bufferConverter = nil
        didFinish = true
        resultContinuation?.resume(throwing: RecognitionError.cancelled)
        resultContinuation = nil
        if let analyzer {
            Task { await analyzer.cancelAndFinishNow() }
        }
    }

    private func resolve(_ result: Result<String, Error>) {
        guard !didFinish else { return }
        didFinish = true
        guard let continuation = resultContinuation else { return }
        resultContinuation = nil
        feeder = nil
        resultsTask = nil
        inputContinuation = nil
        analyzer = nil
        transcriber = nil
        bufferConverter = nil

        switch result {
        case .success(let text): continuation.resume(returning: text)
        case .failure(let error): continuation.resume(throwing: error)
        }
    }

    private func installAssets(for transcriber: SpeechTranscriber) async throws {
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else { return }
        DictateLog.recognition.info("installing the macOS speech model")
        try await request.downloadAndInstall()
        DictateLog.recognition.info("macOS speech model ready")
    }

    private static func makeBuffer(_ chunk: AudioChunk) -> AVAudioPCMBuffer? {
        guard !chunk.samples.isEmpty,
              let format = AVAudioFormat(standardFormatWithSampleRate: chunk.sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(chunk.samples.count)),
              let destination = buffer.floatChannelData?.pointee else { return nil }
        buffer.frameLength = AVAudioFrameCount(chunk.samples.count)
        chunk.samples.withUnsafeBufferPointer { source in
            destination.update(from: source.baseAddress!, count: source.count)
        }
        return buffer
    }
}

private final class AudioBufferConverter: @unchecked Sendable {
    private let outputFormat: AVAudioFormat

    init(outputFormat: AVAudioFormat) {
        self.outputFormat = outputFormat
    }

    func convert(_ input: AVAudioPCMBuffer) throws -> [AnalyzerInput] {
        guard input.frameLength > 0 else { return [] }
        guard let converter = AVAudioConverter(from: input.format, to: outputFormat) else {
            throw RecognitionError.requestFailed
        }
        let ratio = outputFormat.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * ratio)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            throw RecognitionError.requestFailed
        }

        let provider = ConverterInputProvider(input)
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, status in
            guard !provider.supplied else {
                status.pointee = .noDataNow
                return nil
            }
            provider.supplied = true
            status.pointee = .haveData
            return provider.input
        }
        if let conversionError { throw conversionError }
        guard output.frameLength > 0 else { return [] }
        return [AnalyzerInput(buffer: output)]
    }
}

private final class ConverterInputProvider: @unchecked Sendable {
    let input: AVAudioPCMBuffer
    var supplied = false

    init(_ input: AVAudioPCMBuffer) {
        self.input = input
    }
}
