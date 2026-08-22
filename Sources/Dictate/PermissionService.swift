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

@MainActor
final class PermissionService: ObservableObject {
    @Published private(set) var snapshot = PermissionSnapshot()

    func refresh() {
        snapshot.microphone = AVAudioApplication.shared.recordPermission == .granted
        snapshot.speech = SFSpeechRecognizer.authorizationStatus() == .authorized
        snapshot.accessibility = AXIsProcessTrusted()
    }

    func requestMicrophone() {
        AVAudioApplication.requestRecordPermission { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func requestSpeech() {
        SFSpeechRecognizer.requestAuthorization { [weak self] _ in
            Task { @MainActor in self?.refresh() }
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
