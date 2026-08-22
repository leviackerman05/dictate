@preconcurrency import AVFAudio
@preconcurrency import Speech
import AppKit
import ApplicationServices

struct PermissionSnapshot: Equatable, Sendable {
    var microphone = false
    var speech = false
    var accessibility = false

    var canRecord: Bool { microphone && speech }
}

extension Notification.Name {
    static let dictatePermissionsDidChange = Notification.Name("DictatePermissionsDidChange")
}

@MainActor
final class PermissionService: ObservableObject {
    @Published private(set) var snapshot = PermissionSnapshot()

    func refresh() {
        snapshot = PermissionSnapshot(
            microphone: AVAudioApplication.shared.recordPermission == .granted,
            speech: SFSpeechRecognizer.authorizationStatus() == .authorized,
            accessibility: AXIsProcessTrusted()
        )
    }

    func requestMicrophone() {
        guard AVAudioApplication.shared.recordPermission == .undetermined else {
            openMicrophoneSettings()
            refresh()
            return
        }
        Self.requestMicrophoneAuthorization()
    }

    func requestSpeech() {
        guard SFSpeechRecognizer.authorizationStatus() == .notDetermined else {
            openSpeechSettings()
            refresh()
            return
        }
        Self.requestSpeechAuthorization()
    }

    private nonisolated static func requestMicrophoneAuthorization() {
        AVAudioApplication.requestRecordPermission { _ in
            notifyPermissionChanged()
        }
    }

    private nonisolated static func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { _ in
            notifyPermissionChanged()
        }
    }

    private nonisolated static func notifyPermissionChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .dictatePermissionsDidChange, object: nil)
        }
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    func openSpeechSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")!
        NSWorkspace.shared.open(url)
    }
}
