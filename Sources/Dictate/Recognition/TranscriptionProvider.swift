import Foundation

/// The speech models Dictate can transcribe with.
///
/// Raw values are persisted in `UserDefaults`, so `apple` and `parakeet`
/// (Parakeet v3) keep their original values; newer cases append new values.
enum TranscriptionProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case apple
    case parakeet
    case parakeetV2
    case parakeet110m
    case whisperTiny
    case whisperBase
    case whisperSmall
    case whisperMedium
    case whisperLargeV3Turbo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: return String(localized: "model.apple")
        case .parakeet: return String(localized: "model.parakeet")
        case .parakeetV2: return String(localized: "model.parakeetV2")
        case .parakeet110m: return String(localized: "model.parakeet110m")
        case .whisperTiny: return String(localized: "model.whisperTiny")
        case .whisperBase: return String(localized: "model.whisperBase")
        case .whisperSmall: return String(localized: "model.whisperSmall")
        case .whisperMedium: return String(localized: "model.whisperMedium")
        case .whisperLargeV3Turbo: return String(localized: "model.whisperLargeV3Turbo")
        }
    }

    var detail: String {
        switch self {
        case .apple: return String(localized: "model.appleDetail")
        case .parakeet: return String(localized: "model.parakeetDetail")
        case .parakeetV2: return String(localized: "model.parakeetV2Detail")
        case .parakeet110m: return String(localized: "model.parakeet110mDetail")
        case .whisperTiny: return String(localized: "model.whisperTinyDetail")
        case .whisperBase: return String(localized: "model.whisperBaseDetail")
        case .whisperSmall: return String(localized: "model.whisperSmallDetail")
        case .whisperMedium: return String(localized: "model.whisperMediumDetail")
        case .whisperLargeV3Turbo: return String(localized: "model.whisperLargeV3TurboDetail")
        }
    }

    /// Approximate on-disk footprint of the downloaded model.
    var sizeDescription: String {
        switch self {
        case .apple: return "Built-in"
        case .parakeet: return "~460 MB"
        case .parakeetV2: return "~800 MB"
        case .parakeet110m: return "~250 MB"
        case .whisperTiny: return "39 MB"
        case .whisperBase: return "74 MB"
        case .whisperSmall: return "244 MB"
        case .whisperMedium: return "769 MB"
        case .whisperLargeV3Turbo: return "1.6 GB"
        }
    }

    /// Relative speed of recognition, 1 (slowest) to 10 (fastest).
    var speedScore: Double {
        switch self {
        case .apple: return 9
        case .parakeet: return 6
        case .parakeetV2: return 6
        case .parakeet110m: return 9
        case .whisperTiny: return 10
        case .whisperBase: return 9
        case .whisperSmall: return 7
        case .whisperMedium: return 5
        case .whisperLargeV3Turbo: return 3
        }
    }

    /// Relative accuracy of recognition, 1 (least) to 10 (most).
    var accuracyScore: Double {
        switch self {
        case .apple: return 7
        case .parakeet: return 9
        case .parakeetV2: return 8
        case .parakeet110m: return 7
        case .whisperTiny: return 5
        case .whisperBase: return 6
        case .whisperSmall: return 7
        case .whisperMedium: return 9
        case .whisperLargeV3Turbo: return 10
        }
    }

    var isEnglishOnly: Bool {
        switch self {
        case .apple: return false
        case .parakeet: return false
        case .parakeetV2: return true
        case .parakeet110m: return true
        case .whisperTiny: return false
        case .whisperBase: return true
        case .whisperSmall: return true
        case .whisperMedium: return false
        case .whisperLargeV3Turbo: return false
        }
    }

    /// Suggested minimum installed RAM to run the model comfortably.
    var minimumRAMGB: Int {
        switch self {
        case .apple: return 8
        case .parakeet: return 8
        case .parakeetV2: return 8
        case .parakeet110m: return 4
        case .whisperTiny: return 4
        case .whisperBase: return 4
        case .whisperSmall: return 8
        case .whisperMedium: return 12
        case .whisperLargeV3Turbo: return 16
        }
    }

    var engineTitle: String {
        switch self {
        case .apple: return "Apple"
        case .parakeet, .parakeetV2, .parakeet110m: return "Parakeet"
        case .whisperTiny, .whisperBase, .whisperSmall, .whisperMedium, .whisperLargeV3Turbo: return "Whisper"
        }
    }

    /// WhisperKit model folder identifier, or nil for non-whisper engines.
    var whisperVariant: String? {
        switch self {
        case .apple, .parakeet, .parakeetV2, .parakeet110m: return nil
        case .whisperTiny: return "openai_whisper-tiny"
        case .whisperBase: return "openai_whisper-base.en"
        case .whisperSmall: return "openai_whisper-small.en"
        case .whisperMedium: return "openai_whisper-medium"
        case .whisperLargeV3Turbo: return "openai_whisper-large-v3_turbo"
        }
    }
}
