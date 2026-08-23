import Foundation

/// The physical gesture state is deliberately independent from AppKit and
/// Quartz.  Shortcut monitors translate platform events into these inputs,
/// while this reducer owns the duplicate/repeat/latch rules.
public enum ShortcutGestureMode: String, Codable, Sendable {
    case holdToTalk
    case clickToToggle
}

public enum ShortcutSessionPhase: Sendable {
    case idle
    case preparing
    case recording
    case finalizing
}

public enum ShortcutGestureInput: Sendable {
    case physicalDown
    case physicalUp
    case keyRepeat
}

public enum ShortcutGestureAction: Equatable, Sendable {
    case none
    case start
    case requestStop
}

public struct ShortcutGestureReducer: Sendable {
    public private(set) var physicalPressed = false

    public init() {}

    public mutating func reduce(
        _ input: ShortcutGestureInput,
        mode: ShortcutGestureMode,
        session: ShortcutSessionPhase
    ) -> ShortcutGestureAction {
        switch input {
        case .keyRepeat:
            return .none
        case .physicalUp:
            // A toggle session survives key-up, but the physical latch must
            // always clear so a later press is a distinct gesture.
            physicalPressed = false
            guard mode == .holdToTalk else { return .none }
            return session == .preparing || session == .recording ? .requestStop : .none
        case .physicalDown:
            guard !physicalPressed else { return .none }
            physicalPressed = true
            switch mode {
            case .holdToTalk:
                return session == .idle ? .start : .none
            case .clickToToggle:
                switch session {
                case .idle: return .start
                case .preparing, .recording: return .requestStop
                case .finalizing: return .none
                }
            }
        }
    }
}
