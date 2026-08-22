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

private final class AudioStreamSink: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<AudioChunk>.Continuation?

    func setContinuation(_ continuation: AsyncStream<AudioChunk>.Continuation) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func yield(_ chunk: AudioChunk) {
        lock.lock()
        let continuation = self.continuation
        lock.unlock()
        continuation?.yield(chunk)
    }

    func finish() {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.finish()
    }
}

@MainActor
final class AudioCaptureService {
    private let engine = AVAudioEngine()
    private var sink: AudioStreamSink?
    private var isRunning = false

    func start() throws -> AsyncStream<AudioChunk> {
        guard !isRunning else { throw CaptureError.unableToStart }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw CaptureError.noInput }
        DictateLog.capture.debug("input format sampleRate=\(format.sampleRate) channels=\(format.channelCount)")

        let sink = AudioStreamSink()
        let stream = AsyncStream<AudioChunk> { continuation in
            sink.setContinuation(continuation)
        }
        self.sink = sink
        let sampleRate = format.sampleRate
        let tap: AVAudioNodeTapBlock = { buffer, _ in
            AudioCaptureService.forward(buffer: buffer, sampleRate: sampleRate, to: sink)
        }
        input.installTap(onBus: 0, bufferSize: 1_024, format: format, block: tap)
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            sink.finish()
            self.sink = nil
            DictateLog.capture.error("audio engine start error: \(String(describing: error), privacy: .public)")
            throw CaptureError.unableToStart
        }
        DictateLog.capture.debug("audio engine started")
        isRunning = true
        return stream
    }

    private nonisolated static func forward(buffer: AVAudioPCMBuffer, sampleRate: Double, to sink: AudioStreamSink) {
        guard let channel = buffer.floatChannelData?.pointee else { return }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }
        let samples = Array(UnsafeBufferPointer(start: channel, count: count))
        // Keep the realtime callback free of actor hops and unstructured tasks.
        sink.yield(AudioChunk(samples: samples, sampleRate: sampleRate))
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        sink?.finish()
        sink = nil
        isRunning = false
    }
}
