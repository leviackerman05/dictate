import Foundation

public enum DictationFailure: String, Codable, Equatable, Error, Sendable {
    case microphonePermissionDenied
    case speechPermissionDenied
    case accessibilityUnavailable
    case speechModelUnavailable
    case captureUnavailable
    case recognitionUnavailable
    case insertionFailed
    case persistenceFailed
    case unknown
}

public enum DictationState: Equatable, Sendable {
    case idle
    case preparing
    case listening
    case transcribing(partialText: String, level: Double)
    case inserting(text: String)
    case failed(DictationFailure)
}

public enum DictationEvent: Equatable, Sendable {
    case startRequested
    case resourcesReady
    case audioStarted
    case partialText(String, level: Double)
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
        case (.preparing, .resourcesReady): state = .listening
        case (.listening, .partialText(let text, let level)):
            state = .transcribing(partialText: text, level: min(max(level, 0), 1))
        case (.transcribing, .partialText(let text, let level)):
            state = .transcribing(partialText: text, level: min(max(level, 0), 1))
        case (.listening, .finalText(let text)), (.transcribing, .finalText(let text)):
            state = .inserting(text: text)
        case (.inserting, .insertionSucceeded), (.inserting, .reset): state = .idle
        case (.inserting, .insertionFailed): state = .failed(.insertionFailed)
        case (_, .failure(let failure)): state = .failed(failure)
        case (.failed, .reset): state = .idle
        case (.preparing, .cancel), (.listening, .cancel), (.transcribing, .cancel), (.inserting, .cancel), (.failed, .cancel):
            state = .idle
        case (.preparing, .startRequested), (.listening, .startRequested), (.transcribing, .startRequested), (.inserting, .startRequested):
            return TransitionResult(disposition: .ignoredWhileFinalizing, state: state)
        default:
            return TransitionResult(disposition: .ignored, state: state)
        }
        return TransitionResult(disposition: oldState == state ? .ignored : .accepted, state: state)
    }
}
