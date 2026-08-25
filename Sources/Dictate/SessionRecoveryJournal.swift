import DictateCore
import Foundation

/// Keeps the latest recoverable transcript outside the controller's lifetime.
///
/// This stores text only, never microphone samples. The journal is cleared only
/// after successful insertion or an explicit copy/discard action, so a crash or
/// recognizer failure cannot silently erase the last settled transcript.
enum SessionRecoveryJournal {
    private static let key = "dictation.sessionRecoveryText"

    static var text: String? {
        guard let value = UserDefaults.standard.string(forKey: key) else { return nil }
        let normalized = TranscriptText.normalize(value)
        return normalized.isEmpty ? nil : normalized
    }

    static func save(_ value: String) {
        let normalized = TranscriptText.normalize(value)
        guard !normalized.isEmpty else { return }
        UserDefaults.standard.set(normalized, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
