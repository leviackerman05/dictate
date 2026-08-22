@preconcurrency import AVFAudio
import AppKit
import ApplicationServices

struct PermissionSnapshot: Equatable, Sendable {
    var microphone = false
    var accessibility = false

    // SpeechAnalyzer uses the Mac's on-device speech stack; microphone access
    // is the only recording permission Dictate needs to request.
    var canRecord: Bool { microphone }
}

extension Notification.Name {
    static let dictatePermissionsDidChange = Notification.Name("DictatePermissionsDidChange")
}

private func requestMicrophoneAuthorization() {
    AVAudioApplication.requestRecordPermission { _ in
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .dictatePermissionsDidChange, object: nil)
        }
    }
}

@MainActor
final class PermissionService: ObservableObject {
    @Published private(set) var snapshot = PermissionSnapshot()

    func refresh() {
        snapshot = PermissionSnapshot(
            microphone: AVAudioApplication.shared.recordPermission == .granted,
            accessibility: AXIsProcessTrusted()
        )
    }

    func requestMicrophone() {
        guard AVAudioApplication.shared.recordPermission == .undetermined else {
            openMicrophoneSettings()
            refresh()
            return
        }
        requestMicrophoneAuthorization()
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }
}
