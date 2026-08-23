import Foundation

public enum FocusCaptureSource: String, Sendable {
    case globalShortcut
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
/// becoming an implicit, stale-target fallback.
public enum FocusTargetResolver {
    public static func select(
        source: FocusCaptureSource,
        currentIsUsable: Bool,
        preservedIsUsable: Bool
    ) -> FocusTargetSelection {
        if currentIsUsable { return .current }
        if source != .globalShortcut, preservedIsUsable { return .preserved }
        return .missing
    }
}
