import SwiftUI

struct BreathLine: View {
    let level: Double
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                Rectangle()
                    .fill(DesignSystem.ColorToken.action.opacity(active ? 0.9 : 0.45))
                    .frame(height: active ? DesignSystem.Layout.breathLineActiveHeight : DesignSystem.Layout.hairline)
            } else if active {
                TimelineView(.animation(minimumInterval: DesignSystem.Motion.breathLineSampleInterval)) { context in
                    Canvas { drawingContext, size in
                        var path = Path()
                        let phase = context.date.timeIntervalSinceReferenceDate
                        let amplitude = DesignSystem.Motion.breathBaseAmplitude + (level * DesignSystem.Motion.breathLevelAmplitude)
                        path.move(to: CGPoint(x: 0, y: size.height / 2))
                        for step in stride(from: 0.0, through: size.width, by: DesignSystem.Motion.breathSampleStep) {
                            let y = size.height / 2 + sin((step / DesignSystem.Motion.breathWaveLength) + phase * DesignSystem.Motion.breathPhaseSpeed) * amplitude
                            path.addLine(to: CGPoint(x: step, y: y))
                        }
                        drawingContext.stroke(path, with: .color(DesignSystem.ColorToken.recording), lineWidth: DesignSystem.Layout.breathLineWidth)
                    }
                }
                .frame(height: DesignSystem.Layout.breathLineHeight)
            } else {
                Rectangle()
                    .fill(DesignSystem.ColorToken.hairline)
                    .frame(height: DesignSystem.Layout.hairline)
            }
        }
        .accessibilityHidden(true)
    }
}
