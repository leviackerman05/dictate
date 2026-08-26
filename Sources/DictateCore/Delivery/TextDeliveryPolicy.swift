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

/// Dictate temporarily owns the pasteboard only while its change count remains
/// unchanged. A user or another application changing it during delivery always
/// wins, preventing restoration from overwriting newer clipboard content.
public enum PasteboardRestorationPolicy {
    public static func shouldRestore(temporaryChangeCount: Int, currentChangeCount: Int) -> Bool {
        temporaryChangeCount == currentChangeCount
    }
}
