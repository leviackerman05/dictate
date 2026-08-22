import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @State private var step = 0

    private var steps: [(title: String, detail: String, granted: Bool)] {
        [
            (Copy.microphone, String(localized: "onboarding.microphoneDetail"), model.permissions.snapshot.microphone),
            (Copy.speechRecognition, String(localized: "onboarding.speechDetail"), model.permissions.snapshot.speech),
            (Copy.accessibility, String(localized: "onboarding.accessibilityDetail"), model.permissions.snapshot.accessibility)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Layout.space6) {
            Text(Copy.appName)
                .font(.system(.largeTitle, design: .serif))
                .foregroundStyle(DesignSystem.ColorToken.ink)
            Text(String(localized: "onboarding.title"))
                .font(.title2)
            Text(String(localized: "onboarding.intro"))
                .foregroundStyle(DesignSystem.ColorToken.mutedInk)

            VStack(alignment: .leading, spacing: DesignSystem.Layout.space3) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: DesignSystem.Layout.space3) {
                        Image(systemName: item.granted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.granted ? DesignSystem.ColorToken.action : DesignSystem.ColorToken.mutedInk)
                        VStack(alignment: .leading, spacing: DesignSystem.Layout.space1) {
                            Text(item.title).font(.headline)
                            if index == step || item.granted { Text(item.detail).font(.caption).foregroundStyle(DesignSystem.ColorToken.mutedInk) }
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { step = index }
                }
            }

            HStack {
                Button(Copy.checkAgain) { model.permissions.refresh() }
                Spacer()
                if current.granted || step == steps.count - 1 {
                    Button(String(localized: "onboarding.continue")) { advance() }
                        .buttonStyle(.borderedProminent)
                        .tint(DesignSystem.ColorToken.action)
                } else {
                    Button(String(localized: "onboarding.allow")) { requestCurrent() }
                        .buttonStyle(.borderedProminent)
                        .tint(DesignSystem.ColorToken.action)
                }
            }
        }
        .padding(DesignSystem.Layout.space8)
        .background(DesignSystem.ColorToken.canvas)
        .onAppear { model.permissions.refresh() }
    }

    private var current: (title: String, detail: String, granted: Bool) { steps[min(step, steps.count - 1)] }

    private func requestCurrent() {
        switch step {
        case 0: model.permissions.requestMicrophone()
        case 1: model.permissions.requestSpeech()
        default: model.permissions.openAccessibilitySettings()
        }
    }

    private func advance() {
        if step < steps.count - 1 { step += 1 } else { model.onboardingDismissed = true }
    }
}
