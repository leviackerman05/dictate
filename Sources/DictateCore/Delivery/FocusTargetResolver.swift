import Foundation

public enum FocusCaptureSource: String, Sendable {
    case globalShortcut
    case completion
    case mainWindow
    case menuBar
    case retry
}

public enum FocusTargetSelection: Equatable, Sendable {
    case current
    case preserved
    case missing
}

/// Pure selection rules keep UI activation and global-shortcut capture from
/// becoming an implicit, stale-target fallback. A retry is also a new delivery
/// intent: it must resolve the editor that is focused now, never a remembered
/// field from an earlier session.
public enum FocusTargetResolver {
    public static func select(
        source: FocusCaptureSource,
        currentIsUsable: Bool,
        preservedIsUsable: Bool
    ) -> FocusTargetSelection {
        if currentIsUsable { return .current }
        switch source {
        case .retry, .globalShortcut, .completion, .mainWindow, .menuBar:
            return .missing
        }
    }
}
