@preconcurrency import AVFAudio
import Foundation

struct AudioChunk: Sendable {
    let samples: [Float]
    let sampleRate: Double
}

enum CaptureError: Error, Sendable {
    case noInput
    case unableToStart
}

@MainActor
final class AudioCaptureService {
    private let engine = AVAudioEngine()
    private var continuation: AsyncStream<AudioChunk>.Continuation?
    private var isRunning = false

    func start() throws -> AsyncStream<AudioChunk> {
        guard !isRunning else { throw CaptureError.unableToStart }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw CaptureError.noInput }

        let stream = AsyncStream<AudioChunk> { [weak self] continuation in
            self?.continuation = continuation
        }
        let sampleRate = format.sampleRate
        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
            guard let channel = buffer.floatChannelData?.pointee else { return }
            let count = Int(buffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channel, count: count))
            // Yielding into one ordered stream keeps audio work off the callback
            // without creating one unstructured task for every audio buffer.
            self.continuation?.yield(AudioChunk(samples: samples, sampleRate: sampleRate))
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw CaptureError.unableToStart
        }
        isRunning = true
        return stream
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        continuation?.finish()
        continuation = nil
        isRunning = false
    }
}
