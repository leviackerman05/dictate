import Foundation

/// Chooses the first insertion mechanism without depending on AppKit or a live
/// accessibility tree. Web-backed and Electron editors need their native paste
/// event so their DOM/editor selection and input handlers stay authoritative.
public enum TextDeliveryStrategy: String, Equatable, Sendable {
    case accessibilityFirst
    case pasteFirst
}

public enum TextDeliveryStrategyPolicy {
    public static func strategy(isWebBacked: Bool, isElectronApplication: Bool) -> TextDeliveryStrategy {
        isWebBacked || isElectronApplication ? .pasteFirst : .accessibilityFirst
    }
}

/// A completion-time snapshot is taken immediately before delivery. Web and
/// Electron accessibility bridges are allowed to recreate or briefly hide the
/// focused AX object during that tiny hand-off; the native paste command still
/// goes to the active app's real first responder. Native controls keep exact AX
/// revalidation because their identity is stable and more precise.
public enum CompletionPastePolicy {
    public static func mayUseFreshSnapshot(
        strategy: TextDeliveryStrategy,
        snapshotAge: TimeInterval,
        applicationStillActive: Bool,
        targetWasAbandoned: Bool,
        freshnessWindow: TimeInterval = 1
    ) -> Bool {
        strategy == .pasteFirst &&
            snapshotAge >= 0 &&
            snapshotAge <= freshnessWindow &&
            applicationStillActive &&
            !targetWasAbandoned
    }
}

/// Last-resort authorization for applications that expose no system-wide AX
/// focus at all. A current active app plus a recent pointer intent are both
/// mandatory; missing either one keeps the transcript in recovery instead.
public enum AXBlindApplicationPastePolicy {
    public static func mayUse(
        systemFocusAvailable: Bool,
        recentPointerIntentAvailable: Bool,
        activeExternalApplicationAvailable: Bool
    ) -> Bool {
        !systemFocusAvailable &&
            recentPointerIntentAvailable &&
            activeExternalApplicationAvailable
    }
}

/// Dictate temporarily owns the pasteboard only while its change count remains
/// unchanged. A user or another application changing it during delivery always
/// wins, preventing restoration from overwriting newer clipboard content.
public enum PasteboardRestorationPolicy {
    public static func shouldRestore(temporaryChangeCount: Int, currentChangeCount: Int) -> Bool {
        temporaryChangeCount == currentChangeCount
    }
}
