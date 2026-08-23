import DictateCore
import SwiftUI

enum AccessibilitySupport {
    static func status(for state: DictationState) -> String {
        switch state {
        case .idle: return String(localized: "accessibility.state.idle")
        case .preparing: return String(localized: "accessibility.state.preparing")
        case .listening: return String(localized: "accessibility.state.listening")
        case .transcribing: return String(localized: "accessibility.state.transcribing")
        case .finalizing: return String(localized: "accessibility.state.finalizing")
        case .delivering: return String(localized: "accessibility.state.inserting")
        case .failed: return String(localized: "accessibility.state.failed")
        }
    }
}
