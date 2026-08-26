@preconcurrency import AVFoundation
import AppKit
@preconcurrency import ApplicationServices

enum TrustLinks {
    static let privacyPolicy = URL(string: "https://github.com/leviackerman05/dictate/blob/main/PRIVACY.md")!
}

struct PermissionSnapshot: Equatable, Sendable {
    var microphone = false
    var accessibility = false

    // SpeechAnalyzer uses the Mac's on-device speech stack. Microphone access
    // is needed to record; Accessibility is needed for automatic insertion.
    var canRecord: Bool { microphone }
}

extension Notification.Name {
    static let dictatePermissionsDidChange = Notification.Name("DictatePermissionsDidChange")
}

private func requestMicrophoneAuthorization() {
    AVCaptureDevice.requestAccess(for: .audio) { _ in
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .dictatePermissionsDidChange, object: nil)
        }
    }
}

@MainActor
final class PermissionService: ObservableObject {
    @Published private(set) var snapshot = PermissionSnapshot()
    private var accessibilityPollingTask: Task<Void, Never>?

    func refresh() {
        snapshot = PermissionSnapshot(
            microphone: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
            accessibility: AXIsProcessTrusted()
        )
    }

    func requestMicrophone() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else {
            openMicrophoneSettings()
            refresh()
            return
        }
        requestMicrophoneAuthorization()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openAccessibilitySettings()
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        accessibilityPollingTask?.cancel()
        accessibilityPollingTask = Task { @MainActor [weak self] in
            for _ in 0..<40 {
                do {
                    try await Task.sleep(nanoseconds: 500_000_000)
                } catch {
                    return
                }
                guard let self else { return }
                self.refresh()
                if self.snapshot.accessibility { return }
            }
        }
    }

    func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }
}
