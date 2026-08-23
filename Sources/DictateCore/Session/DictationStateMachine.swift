import Foundation

public enum DictationFailure: String, Codable, Equatable, Error, Sendable {
    case microphonePermissionDenied
    case speechPermissionDenied
    case accessibilityUnavailable
    case speechModelUnavailable
    case captureUnavailable
    case recognitionUnavailable
    case insertionFailed
    case sessionTimedOut
    case persistenceFailed
    case unknown
}

public enum DictationState: Equatable, Sendable {
    case idle
    case preparing
    case listening
    case transcribing(partialText: String, level: Double)
    case finalizing
    case delivering
    case failed(DictationFailure)
}

public enum DictationEvent: Equatable, Sendable {
    case startRequested
    case resourcesReady
    case audioStarted
    case partialText(String, level: Double)
    case stopRequested
    case finalText(String)
    case insertionSucceeded
    case insertionFailed
    case failure(DictationFailure)
    case cancel
    case reset
}

public enum TransitionDisposition: Equatable, Sendable {
    case accepted
    case ignoredWhileFinalizing
    case ignored
}

public struct TransitionResult: Equatable, Sendable {
    public let disposition: TransitionDisposition
    public let state: DictationState

    public init(disposition: TransitionDisposition, state: DictationState) {
        self.disposition = disposition
        self.state = state
    }
}

public struct DictationStateMachine: Sendable {
    public private(set) var state: DictationState = .idle

    public init() {}

    @discardableResult
    public mutating func send(_ event: DictationEvent) -> TransitionResult {
        let oldState = state
        switch (state, event) {
        case (.idle, .startRequested): state = .preparing
        case (.preparing, .resourcesReady): break
        case (.preparing, .audioStarted): state = .listening
        case (.listening, .partialText(let text, let level)):
            state = .transcribing(partialText: text, level: min(max(level, 0), 1))
        case (.transcribing, .partialText(let text, let level)):
            state = .transcribing(partialText: text, level: min(max(level, 0), 1))
        case (.preparing, .stopRequested), (.listening, .stopRequested), (.transcribing, .stopRequested):
            state = .finalizing
        case (.finalizing, .stopRequested), (.delivering, .stopRequested):
            return TransitionResult(disposition: .ignoredWhileFinalizing, state: state)
        case (.finalizing, .finalText): state = .delivering
        case (.delivering, .insertionSucceeded), (.delivering, .reset): state = .idle
        case (.delivering, .insertionFailed): state = .failed(.insertionFailed)
        case (_, .failure(let failure)): state = .failed(failure)
        case (.failed, .reset): state = .idle
        case (.preparing, .cancel), (.listening, .cancel), (.transcribing, .cancel), (.finalizing, .cancel), (.delivering, .cancel), (.failed, .cancel):
            state = .idle
        case (.preparing, .startRequested), (.listening, .startRequested), (.transcribing, .startRequested), (.finalizing, .startRequested), (.delivering, .startRequested):
            return TransitionResult(disposition: .ignoredWhileFinalizing, state: state)
        default:
            return TransitionResult(disposition: .ignored, state: state)
        }
        return TransitionResult(disposition: oldState == state ? .ignored : .accepted, state: state)
    }
}
