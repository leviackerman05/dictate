import Foundation

/// Mirrors SpeechTranscriber's result lifecycle: finalized phrases are
/// append-only, while the current volatile phrase is replaced by each newer
/// hypothesis until Apple emits its final version.
public struct TranscriptAssemblyState: Equatable, Sendable {
    public private(set) var finalizedText = ""
    public private(set) var volatileText = ""

    public init() {}

    public var visibleText: String {
        TranscriptText.join(finalizedText, volatileText)
    }

    @discardableResult
    public mutating func apply(_ update: String, isFinal: Bool) -> String {
        let normalized = TranscriptText.normalize(update)
        if isFinal {
            volatileText = ""
            if !normalized.isEmpty {
                finalizedText = TranscriptText.join(finalizedText, normalized)
            }
        } else {
            // An empty volatile update is meaningful: it revokes the current
            // tentative range rather than preserving an obsolete guess.
            volatileText = normalized
        }
        return visibleText
    }

    /// Finishing an analyzer should emit a final result for every volatile
    /// range. Promote any remaining range defensively so the returned text is
    /// never shorter than the last visible transcript if an implementation
    /// ends its result sequence without that final callback.
    @discardableResult
    public mutating func finish() -> String {
        if !volatileText.isEmpty {
            finalizedText = TranscriptText.join(finalizedText, volatileText)
            volatileText = ""
        }
        return finalizedText
    }
}

public enum TranscriptText {
    public static func normalize(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func join(_ lhs: String, _ rhs: String) -> String {
        let left = normalize(lhs)
        let right = normalize(rhs)
        guard !left.isEmpty else { return right }
        guard !right.isEmpty else { return left }

        if right.first.map({ ".,!?;:%)]}".contains($0) }) == true {
            return left + right
        }
        if left.last.map({ "([{\"".contains($0) }) == true {
            return left + right
        }
        return left + " " + right
    }
}

public enum DeliveryRecoveryOutcome: Equatable, Sendable {
    case inserted
    case noTarget
    case permissionMissing
    case deliveryFailed

    public var requiresRecovery: Bool {
        self != .inserted
    }
}

/// Pure state used by the controller to keep an unresolved delivery visible
/// until the user explicitly copies or discards it.
public struct DeliveryRecoveryState: Equatable, Sendable {
    public private(set) var text: String?

    public init(text: String? = nil) {
        self.text = text
    }

    public var canStartNewSession: Bool { text == nil }

    public mutating func resolve(_ value: String, outcome: DeliveryRecoveryOutcome) {
        switch outcome {
        case .inserted:
            clear()
        case .noTarget, .permissionMissing, .deliveryFailed:
            preserve(value)
        }
    }

    public mutating func preserve(_ value: String) {
        let normalized = TranscriptText.normalize(value)
        guard !normalized.isEmpty else { return }
        text = normalized
    }

    public mutating func clear() {
        text = nil
    }
}
