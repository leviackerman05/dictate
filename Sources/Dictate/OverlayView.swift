import SwiftUI

struct RecordingOverlayView: View {
    @ObservedObject var controller: DictationController

    var body: some View {
        HStack(spacing: DesignSystem.Layout.space3) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignSystem.Layout.space1) {
                Text(statusText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                Text(controller.liveText.isEmpty ? String(localized: "recording.speakPrompt") : controller.liveText)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(DesignSystem.ColorToken.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: DesignSystem.Layout.space2)
        }
        .padding(.horizontal, DesignSystem.Layout.space4)
        .padding(.vertical, 10)
        .background(DesignSystem.ColorToken.canvas)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusOverlay))
        .overlay(alignment: .bottom) {
                BreathLine(level: controller.inputLevel, active: controller.state != .idle)
                .padding(.horizontal, DesignSystem.Layout.space4)
        }
        .shadow(color: .black.opacity(DesignSystem.Shadow.overlayOpacity), radius: DesignSystem.Shadow.overlayRadius, y: DesignSystem.Shadow.overlayY)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AccessibilitySupport.status(for: controller.state))
        .accessibilityValue(controller.liveText)
    }

    private var statusText: String {
        switch controller.state {
        case .idle: return Copy.cancelled
        case .preparing: return Copy.preparing
        case .listening: return Copy.listening
        case .transcribing: return Copy.transcribing
        case .inserting: return Copy.inserting
        case .failed: return Copy.recordingFailed
        }
    }

    private var dotColor: Color {
        switch controller.state {
        case .failed: return DesignSystem.ColorToken.recording
        case .idle: return DesignSystem.ColorToken.hairline
        default: return DesignSystem.ColorToken.recording
        }
    }
}
