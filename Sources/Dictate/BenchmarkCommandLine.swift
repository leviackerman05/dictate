@preconcurrency import AVFAudio
import AppKit
import Darwin
import DictateCore
import FluidAudio
import Foundation

/// Headless benchmark mode hosted by the production executable so it exercises
/// the same recognition implementations as the app. It never downloads model
/// assets: an engine without an existing local model is reported unavailable.
@MainActor
enum BenchmarkCommandLine {
    static var isRequested: Bool {
        CommandLine.arguments.dropFirst().first == "benchmark"
    }

    static func run() async -> Int {
        do {
            let invocation = try Invocation(arguments: Array(CommandLine.arguments.dropFirst(2)))
            if invocation.showHelp {
                print(usage)
                return 0
            }

            let report = await BenchmarkRunner.run(invocation)
            try report.writeJSON(to: invocation.jsonURL)
            try report.writeMarkdown(to: invocation.markdownURL)
            print("Benchmark complete")
            print("JSON: \(invocation.jsonURL.path)")
            print("Markdown: \(invocation.markdownURL.path)")
            return report.results.contains(where: { $0.status == .completed }) ? 0 : 3
        } catch {
            writeStandardError("benchmark: \(error.localizedDescription)\n\n\(usage)\n")
            return 2
        }
    }

    private static func writeStandardError(_ value: String) {
        FileHandle.standardError.write(Data(value.utf8))
    }

    static let usage = """
    Usage:
      Dictate benchmark --audio FILE --engine ENGINE [--engine ENGINE ...]
                         [--reference FILE] [--json FILE] [--markdown FILE]

    Engines:
      apple, parakeet, parakeetV2, parakeet110m, whisperTiny,
      whisperBase, whisperSmall, whisperMedium, whisperLargeV3Turbo, all

    Notes:
      - Audio and reference files remain local.
      - The benchmark never downloads a model. Install models in Dictate first.
      - Output is raw recognition text; dictionary correction and insertion are excluded.
    """
}

private struct Invocation {
    let audioURL: URL
    let referenceURL: URL?
    let providers: [TranscriptionProvider]
    let jsonURL: URL
    let markdownURL: URL
    let showHelp: Bool

    init(arguments: [String]) throws {
        if arguments == ["--help"] || arguments == ["-h"] {
            audioURL = URL(fileURLWithPath: "/dev/null")
            referenceURL = nil
            providers = []
            jsonURL = URL(fileURLWithPath: "benchmark-results.json")
            markdownURL = URL(fileURLWithPath: "benchmark-results.md")
            showHelp = true
            return
        }

        var audioPath: String?
        var referencePath: String?
        var engineValues: [String] = []
        var jsonPath = "benchmark-results.json"
        var markdownPath = "benchmark-results.md"
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            func nextValue() throws -> String {
                guard index + 1 < arguments.count else {
                    throw BenchmarkArgumentError.missingValue(argument)
                }
                index += 1
                return arguments[index]
            }
            switch argument {
            case "--audio": audioPath = try nextValue()
            case "--reference": referencePath = try nextValue()
            case "--engine": engineValues.append(contentsOf: try nextValue().split(separator: ",").map(String.init))
            case "--json": jsonPath = try nextValue()
            case "--markdown": markdownPath = try nextValue()
            default: throw BenchmarkArgumentError.unknownArgument(argument)
            }
            index += 1
        }

        guard let audioPath else { throw BenchmarkArgumentError.missingRequired("--audio") }
        guard !engineValues.isEmpty else { throw BenchmarkArgumentError.missingRequired("--engine") }

        let parsedProviders: [TranscriptionProvider]
        if engineValues.contains("all") {
            parsedProviders = TranscriptionProvider.allCases
        } else {
            parsedProviders = try engineValues.map { value in
                guard let provider = TranscriptionProvider(rawValue: value) else {
                    throw BenchmarkArgumentError.unknownEngine(value)
                }
                return provider
            }
        }

        audioURL = URL(fileURLWithPath: audioPath).standardizedFileURL
        referenceURL = referencePath.map { URL(fileURLWithPath: $0).standardizedFileURL }
        providers = parsedProviders.reduce(into: []) { result, provider in
            if !result.contains(provider) { result.append(provider) }
        }
        jsonURL = URL(fileURLWithPath: jsonPath).standardizedFileURL
        markdownURL = URL(fileURLWithPath: markdownPath).standardizedFileURL
        showHelp = false
    }
}

private enum BenchmarkArgumentError: LocalizedError {
    case missingRequired(String)
    case missingValue(String)
    case unknownArgument(String)
    case unknownEngine(String)

    var errorDescription: String? {
        switch self {
        case .missingRequired(let argument): return "Missing required argument \(argument)."
        case .missingValue(let argument): return "Missing value after \(argument)."
        case .unknownArgument(let argument): return "Unknown argument \(argument)."
        case .unknownEngine(let engine): return "Unknown engine \(engine)."
        }
    }
}

private enum BenchmarkRunner {
    @MainActor
    static func run(_ invocation: Invocation) async -> BenchmarkReport {
        let reference: String?
        do {
            if let referenceURL = invocation.referenceURL {
                let value = try String(contentsOf: referenceURL, encoding: .utf8)
                reference = value.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                reference = nil
            }
        } catch {
            return BenchmarkReport(
                generatedAt: .now,
                hardware: .current,
                audio: BenchmarkAudio(fileName: invocation.audioURL.lastPathComponent, durationSeconds: nil),
                referenceProvided: invocation.referenceURL != nil,
                results: invocation.providers.map {
                    .failed(provider: $0, audioDuration: nil, reason: "Reference transcript could not be read: \(error.localizedDescription)")
                }
            )
        }

        let duration: Double
        do {
            let file = try AVAudioFile(forReading: invocation.audioURL)
            guard file.processingFormat.sampleRate > 0 else {
                throw RecognitionError.requestFailed
            }
            duration = Double(file.length) / file.processingFormat.sampleRate
        } catch {
            return BenchmarkReport(
                generatedAt: .now,
                hardware: .current,
                audio: BenchmarkAudio(fileName: invocation.audioURL.lastPathComponent, durationSeconds: nil),
                referenceProvided: reference != nil,
                results: invocation.providers.map {
                    .failed(provider: $0, audioDuration: nil, reason: "Audio file could not be opened: \(error.localizedDescription)")
                }
            )
        }

        var results: [BenchmarkEngineResult] = []
        for provider in invocation.providers {
            results.append(await run(provider: provider, audioURL: invocation.audioURL, duration: duration, reference: reference))
        }

        return BenchmarkReport(
            generatedAt: .now,
            hardware: .current,
            audio: BenchmarkAudio(fileName: invocation.audioURL.lastPathComponent, durationSeconds: duration),
            referenceProvided: reference != nil,
            results: results
        )
    }

    @MainActor
    private static func run(
        provider: TranscriptionProvider,
        audioURL: URL,
        duration: Double,
        reference: String?
    ) async -> BenchmarkEngineResult {
        do {
            let recognition = try await offlineRecognitionService(for: provider)
            let stream = try AudioFileStreamService.makeStream(from: audioURL)
            let clock = ContinuousClock()
            let started = clock.now
            let transcript = try await recognition.transcribe(
                stream: stream,
                contextualVocabulary: [],
                onPartial: { _ in },
                onLevel: { _ in }
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            let elapsed = started.duration(to: clock.now).seconds
            return BenchmarkEngineResult(
                engineIdentifier: provider.engineTitle.lowercased(),
                modelIdentifier: provider.rawValue,
                modelName: provider.benchmarkDisplayName,
                status: .completed,
                audioDurationSeconds: duration,
                transcriptionDurationSeconds: elapsed,
                realTimeFactor: duration > 0 ? elapsed / duration : nil,
                wordErrorRate: reference.flatMap { WordErrorRate.measure(reference: $0, hypothesis: transcript) },
                transcript: transcript,
                error: nil
            )
        } catch RecognitionError.onDeviceModelUnavailable {
            return .unavailable(
                provider: provider,
                audioDuration: duration,
                reason: "Model assets are not installed locally. Prepare this model in Dictate before benchmarking."
            )
        } catch RecognitionError.cancelled {
            return .failed(provider: provider, audioDuration: duration, reason: "Benchmark was cancelled.")
        } catch {
            return .failed(provider: provider, audioDuration: duration, reason: error.localizedDescription)
        }
    }

    @MainActor
    private static func offlineRecognitionService(for provider: TranscriptionProvider) async throws -> any SpeechRecognizing {
        switch provider {
        case .apple:
            let service = SpeechRecognitionService()
            try await service.prepareForOfflineBenchmark()
            return service
        case .parakeet, .parakeetV2, .parakeet110m:
            let version: AsrModelVersion
            switch provider {
            case .parakeet: version = .v3
            case .parakeetV2: version = .v2
            case .parakeet110m: version = .tdtCtc110m
            default: version = .v3
            }
            let service = ParakeetRecognitionService(modelVersion: version)
            try await service.prepareForOfflineBenchmark()
            return service
        case .whisperTiny, .whisperBase, .whisperSmall, .whisperMedium, .whisperLargeV3Turbo:
            guard let variant = provider.whisperVariant else {
                throw RecognitionError.onDeviceModelUnavailable
            }
            let service = WhisperRecognitionService(variant: variant)
            try await service.prepareForOfflineBenchmark()
            return service
        }
    }
}

private struct BenchmarkReport: Codable {
    var schemaVersion = 1
    let generatedAt: Date
    let hardware: BenchmarkHardware
    let audio: BenchmarkAudio
    let referenceProvided: Bool
    let results: [BenchmarkEngineResult]

    func writeJSON(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(self).write(to: url, options: [.atomic])
    }

    func writeMarkdown(to url: URL) throws {
        var lines = [
            "# Dictate benchmark",
            "",
            "Generated: \(generatedAt.formatted(.iso8601))",
            "",
            "- Hardware: \(hardware.model) (\(hardware.architecture))",
            "- Processor: \(hardware.processor)",
            "- Memory: \(hardware.memoryBytes) bytes",
            "- OS: \(hardware.operatingSystem)",
            "- Audio: `\(audio.fileName)`",
            "- Audio duration: \(format(audio.durationSeconds)) seconds",
            "- Reference supplied: \(referenceProvided ? "yes" : "no")",
            "",
            "| Engine | Model | Status | Transcription (s) | RTF | WER |",
            "| --- | --- | --- | ---: | ---: | ---: |"
        ]
        for result in results {
            lines.append(
                "| \(result.engineIdentifier) | \(result.modelIdentifier) | \(result.status.rawValue) | "
                    + "\(format(result.transcriptionDurationSeconds)) | \(format(result.realTimeFactor)) | \(format(result.wordErrorRate)) |"
            )
        }
        for result in results {
            lines.append(contentsOf: ["", "## \(result.modelName)", ""])
            if let error = result.error {
                lines.append("Error: \(error)")
            } else {
                lines.append("Insertion-independent transcription output:")
                lines.append("")
                lines.append("```text")
                lines.append(result.transcript ?? "")
                lines.append("```")
            }
        }
        lines.append("")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

private struct BenchmarkHardware: Codable {
    let model: String
    let architecture: String
    let processor: String
    let memoryBytes: UInt64
    let logicalProcessorCount: Int
    let operatingSystem: String

    static var current: BenchmarkHardware {
        let processInfo = ProcessInfo.processInfo
        return BenchmarkHardware(
            model: sysctlString("hw.model") ?? "unknown",
            architecture: sysctlString("hw.machine") ?? "unknown",
            processor: sysctlString("machdep.cpu.brand_string") ?? "unknown",
            memoryBytes: processInfo.physicalMemory,
            logicalProcessorCount: processInfo.processorCount,
            operatingSystem: processInfo.operatingSystemVersionString
        )
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 1 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}

private struct BenchmarkAudio: Codable {
    let fileName: String
    let durationSeconds: Double?
}

private enum BenchmarkStatus: String, Codable {
    case completed
    case unavailable
    case failed
}

private struct BenchmarkEngineResult: Codable {
    let engineIdentifier: String
    let modelIdentifier: String
    let modelName: String
    let status: BenchmarkStatus
    let audioDurationSeconds: Double?
    let transcriptionDurationSeconds: Double?
    let realTimeFactor: Double?
    let wordErrorRate: Double?
    let transcript: String?
    let error: String?

    static func unavailable(provider: TranscriptionProvider, audioDuration: Double?, reason: String) -> BenchmarkEngineResult {
        result(provider: provider, status: .unavailable, audioDuration: audioDuration, reason: reason)
    }

    static func failed(provider: TranscriptionProvider, audioDuration: Double?, reason: String) -> BenchmarkEngineResult {
        result(provider: provider, status: .failed, audioDuration: audioDuration, reason: reason)
    }

    private static func result(
        provider: TranscriptionProvider,
        status: BenchmarkStatus,
        audioDuration: Double?,
        reason: String
    ) -> BenchmarkEngineResult {
        BenchmarkEngineResult(
            engineIdentifier: provider.engineTitle.lowercased(),
            modelIdentifier: provider.rawValue,
            modelName: provider.benchmarkDisplayName,
            status: status,
            audioDurationSeconds: audioDuration,
            transcriptionDurationSeconds: nil,
            realTimeFactor: nil,
            wordErrorRate: nil,
            transcript: nil,
            error: reason
        )
    }
}

private extension Duration {
    var seconds: Double {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }
}

private extension TranscriptionProvider {
    var benchmarkDisplayName: String {
        switch self {
        case .apple: return "Apple SpeechAnalyzer"
        case .parakeet: return "NVIDIA Parakeet TDT 0.6B v3"
        case .parakeetV2: return "NVIDIA Parakeet TDT 0.6B v2"
        case .parakeet110m: return "NVIDIA Parakeet TDT-CTC 110M"
        case .whisperTiny: return "Whisper Tiny"
        case .whisperBase: return "Whisper Base English"
        case .whisperSmall: return "Whisper Small English"
        case .whisperMedium: return "Whisper Medium"
        case .whisperLargeV3Turbo: return "Whisper Large v3 Turbo"
        }
    }
}
