@preconcurrency import AVFAudio
import Foundation

@MainActor
enum AudioFileStreamService {
    static func makeStream(from url: URL) throws -> AsyncStream<AudioChunk> {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let chunkFrames: AVAudioFrameCount = 4_096

        return AsyncStream { continuation in
            Task { @MainActor in
                defer { continuation.finish() }
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames),
                      let channel = buffer.floatChannelData?.pointee else {
                    return
                }

                while file.framePosition < file.length {
                    let remaining = AVAudioFrameCount(min(Int64(chunkFrames), file.length - file.framePosition))
                    do {
                        try file.read(into: buffer, frameCount: remaining)
                    } catch {
                        continuation.finish()
                        return
                    }
                    guard buffer.frameLength > 0 else { continue }
                    let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
                    continuation.yield(AudioChunk(samples: samples, sampleRate: format.sampleRate))
                }
            }
        }
    }
}
