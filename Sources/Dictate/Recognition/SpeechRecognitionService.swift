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
    private var task: SFSpeechRecognitionTask?
    private var consumer: Task<Void, Never>?
    private var continuation: CheckedContinuation<String, Error>?
    private var didFinish = false

    var modelIsAvailable: Bool {
        SFSpeechRecognizer(locale: Locale.current)?.supportsOnDeviceRecognition == true
    }

    func transcribe(
        stream: AsyncStream<AudioChunk>,
        contextualVocabulary: [String],
        onPartial: @escaping (String) -> Void,
        onLevel: @escaping (Double) -> Void
    ) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current), recognizer.isAvailable else {
            throw RecognitionError.recognizerUnavailable
        }
        guard recognizer.supportsOnDeviceRecognition else { throw RecognitionError.onDeviceModelUnavailable }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.contextualStrings = contextualVocabulary
        didFinish = false

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self, !self.didFinish else { return }
                    if let result {
                        onPartial(result.bestTranscription.formattedString)
                        if result.isFinal { self.finish(.success(result.bestTranscription.formattedString)) }
                    }
                    if error != nil { self.finish(.failure(RecognitionError.requestFailed)) }
                }
            }
            consumer = Task { @MainActor [weak self] in
                guard let self else { return }
                for await chunk in stream {
                    guard !Task.isCancelled else { break }
                    let sum = chunk.samples.reduce(into: 0.0) { partial, sample in partial += Double(sample * sample) }
                    let rms = chunk.samples.isEmpty ? 0 : sqrt(sum / Double(chunk.samples.count))
                    onLevel(min(max(rms * 8, 0), 1))
                    if let buffer = self.makeBuffer(chunk) { request.append(buffer) }
                }
                request.endAudio()
            }
        }
    }

    func cancel() {
        consumer?.cancel()
        consumer = nil
        task?.cancel()
        task = nil
        finish(.failure(RecognitionError.cancelled))
    }

    private func makeBuffer(_ chunk: AudioChunk) -> AVAudioPCMBuffer? {
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

    private func finish(_ result: Result<String, Error>) {
        guard !didFinish else { return }
        didFinish = true
        task = nil
        consumer?.cancel()
        consumer = nil
        switch result {
        case .success(let value): continuation?.resume(returning: value)
        case .failure(let error): continuation?.resume(throwing: error)
        }
        continuation = nil
    }
}
