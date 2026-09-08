import Foundation

/// Selection must never turn a missing OS API into a launch failure or an
/// unsolicited download. Keep this policy independent of speech frameworks.
public enum ModelSelectionPolicy {
    public static func select(saved: String?, supported: [String], installed: Set<String>, recommended: String) -> String? {
        if let saved, supported.contains(saved) { return saved }
        if let cached = supported.first(where: installed.contains) { return cached }
        if supported.contains(recommended) { return recommended }
        return supported.first
    }
}
