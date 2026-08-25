import SwiftUI

struct RecordingOverlayView: View {
    @ObservedObject var controller: DictationController
    let shortcutTitle: String
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            if let notice = controller.deliveryNotice {
                noticeView(notice)
            } else {
                switch controller.state {
                case .idle:
                    readyView
                case .preparing, .listening, .transcribing:
                    listeningView
                case .finalizing, .delivering:
                    processingView
                case .failed:
                    failureView
                }
            }
        }
        .padding(.horizontal, 7)
        .frame(width: DesignSystem.Layout.overlayWidth, height: DesignSystem.Layout.overlayHeight)
        .background(
            DesignSystem.ColorToken.overlay.opacity(
                reduceTransparency ? 1 : (isQuietReady ? 0.58 : 0.94)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusOverlayCompact))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusOverlayCompact)
                .stroke(DesignSystem.ColorToken.border.opacity(isQuietReady ? 0.55 : 1), lineWidth: DesignSystem.Layout.hairline)
        }
        .shadow(color: .black.opacity(isQuietReady ? 0.06 : 0.12), radius: isQuietReady ? 8 : 14, y: isQuietReady ? 3 : 5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var readyView: some View {
        ReadyWaveform()
            .opacity(0.68)
            .help(controllerHelp)
    }

    private var isQuietReady: Bool {
        controller.state == .idle && controller.deliveryNotice == nil
    }

    private var listeningView: some View {
        PebbleLevelBars(level: controller.inputLevel)
    }

    private var processingView: some View {
        PebbleProcessingDots()
    }

    private var failureView: some View {
        Image(systemName: "exclamationmark.circle")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(DesignSystem.ColorToken.failure)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func noticeView(_ notice: DeliveryNotice) -> some View {
        switch notice {
        case .textReady:
            HStack(spacing: 6) {
                PebbleIconButton(systemImage: "doc.on.doc", color: DesignSystem.ColorToken.action, help: Copy.copyText) {
                    controller.copyPendingText()
                }
                PebbleIconButton(systemImage: "xmark", color: DesignSystem.ColorToken.secondaryText, help: Copy.discard) {
                    controller.discardPendingText()
                }
            }
        }
    }

    private var controllerHelp: String {
        String.localizedStringWithFormat(String(localized: "recording.readyHelp"), shortcutTitle)
    }

    private var accessibilityLabel: String {
        if let notice = controller.deliveryNotice {
            switch notice {
            case .textReady: return String(localized: "recording.textReady")
            }
        }
        return AccessibilitySupport.status(for: controller.state)
    }
}

/// Small icon-only button used inside the overlay pill: 22×18 hit area,
/// 12pt glyph, raised-surface hover feedback on a 6pt rounded background.
private struct PebbleIconButton: View {
    let systemImage: String
    let color: Color
    let help: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22, height: 18)
                .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusOverlayButton))
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusOverlayButton)
                        .fill(hovering ? DesignSystem.ColorToken.raisedSurface : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct PebbleLevelBars: View {
    let level: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.06)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate * 7.5
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<9, id: \.self) { index in
                    let motion = 0.35 + 0.65 * abs(sin(phase + Double(index) * 0.82))
                    // Lift quiet speech without amplifying loud input past the
                    // pill. The square-root-style response makes low levels
                    // visibly alive while the clamp keeps peaks composed.
                    let envelope = max(0.14, pow(min(1, level * 2.2), 0.55))
                    Capsule()
                        .fill(DesignSystem.ColorToken.listening.opacity(0.52 + envelope * 0.48))
                        .frame(width: 2.25, height: max(3, CGFloat(3 + 9 * envelope * motion)))
                }
            }
            .frame(height: 13)
        }
        .accessibilityHidden(true)
    }
}

private struct ReadyWaveform: View {
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach([5.0, 9.0, 6.0], id: \.self) { height in
                Capsule()
                    .fill(DesignSystem.ColorToken.secondaryText.opacity(0.72))
                    .frame(width: 3, height: height)
            }
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }
}

private struct PebbleProcessingDots: View {
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { _ in
                Circle().fill(DesignSystem.ColorToken.listening).frame(width: 4, height: 4)
            }
        }
        .accessibilityHidden(true)
    }
}
