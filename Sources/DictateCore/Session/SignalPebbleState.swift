import Foundation

public enum SignalPebbleNotice: String, Equatable, Sendable {
    case inserted
    case copied
    case recovery
}

public enum SignalPebblePhase: String, Equatable, Sendable {
    case ready
    case listening
    case processing
    case inserted
    case recovery
    case failed
}

public enum SignalPebbleStateMapper {
    public static func phase(state: DictationState, notice: SignalPebbleNotice?) -> SignalPebblePhase {
        if let notice {
            switch notice {
            case .inserted: return .inserted
            case .copied: return .ready
            case .recovery: return .recovery
            }
        }

        switch state {
        case .idle: return .ready
        case .preparing, .listening, .transcribing: return .listening
        case .finalizing, .delivering: return .processing
        case .failed: return .failed
        }
    }
}
