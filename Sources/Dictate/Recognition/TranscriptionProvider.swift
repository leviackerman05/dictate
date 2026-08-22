import Foundation

enum TranscriptionProvider: String, CaseIterable, Codable, Identifiable {
    case apple
    case parakeet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: return String(localized: "model.apple")
        case .parakeet: return String(localized: "model.parakeet")
        }
    }

    var detail: String {
        switch self {
        case .apple: return String(localized: "model.appleDetail")
        case .parakeet: return String(localized: "model.parakeetDetail")
        }
    }
}
