import SwiftUI

struct RecordingOverlayView: View {
    @ObservedObject var controller: DictationController

    var body: some View {
        HStack(spacing: DesignSystem.Layout.space2) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)

            if let notice = controller.deliveryNotice {
                noticeView(notice)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(statusText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(DesignSystem.ColorToken.ink)
                    .lineLimit(1)
                Spacer(minLength: DesignSystem.Layout.space1)
                if isRecording {
                    BreathLine(level: controller.inputLevel, active: true)
                        .frame(width: 32, height: 12)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Layout.space3)
        .frame(width: DesignSystem.Layout.overlayWidth, height: DesignSystem.Layout.overlayHeight)
        .background(DesignSystem.ColorToken.canvas)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusOverlay))
        .shadow(color: .black.opacity(DesignSystem.Shadow.overlayOpacity), radius: 12, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func noticeView(_ notice: DeliveryNotice) -> some View {
        switch notice {
        case .inserted:
            Label(String(localized: "recording.inserted"), systemImage: "checkmark")
        case .copied:
            Label(String(localized: "recording.copied"), systemImage: "checkmark")
        case .textReady(_):
            HStack(spacing: DesignSystem.Layout.space2) {
                Text(String(localized: "recording.textReady"))
                    .foregroundStyle(DesignSystem.ColorToken.ink)
                Spacer(minLength: DesignSystem.Layout.space1)
                Button { controller.copyPendingText() } label: {
                    Text(Copy.copyText)
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, DesignSystem.Layout.space2)
                        .padding(.vertical, DesignSystem.Layout.space1)
                        .background(DesignSystem.ColorToken.action, in: Capsule())
                }
                .buttonStyle(.plain)
                .fixedSize()
                .accessibilityLabel(Copy.copyText)
                Button { controller.discardPendingText() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                        .frame(width: 18, height: 18)
                        .background(DesignSystem.ColorToken.hairline.opacity(0.55), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help(Copy.discard)
                .accessibilityLabel(Copy.discard)
            }
        }
    }

    private var isRecording: Bool {
        switch controller.state {
        case .listening, .transcribing: return true
        default: return false
        }
    }

    private var statusText: String {
        switch controller.state {
        case .idle: return Copy.cancelled
        case .preparing: return Copy.preparing
        case .listening, .transcribing: return Copy.listening
        case .finalizing: return String(localized: "recording.finishing")
        case .delivering: return Copy.inserting
        case .failed: return Copy.recordingFailed
        }
    }

    private var dotColor: Color {
        switch controller.state {
        case .failed: return DesignSystem.ColorToken.recording
        case .finalizing, .delivering: return DesignSystem.ColorToken.action
        default: return DesignSystem.ColorToken.recording
        }
    }

    private var accessibilityLabel: String {
        if controller.deliveryNotice != nil { return String(localized: "recording.deliveryStatus") }
        return AccessibilitySupport.status(for: controller.state)
    }
}
