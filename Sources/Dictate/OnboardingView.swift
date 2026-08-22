import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var permissions: PermissionService
    @State private var step = 0

    init(model: AppModel) {
        self.model = model
        _permissions = ObservedObject(wrappedValue: model.permissions)
    }

    private var steps: [(title: String, detail: String, granted: Bool)] {
        [
            (Copy.microphone, String(localized: "onboarding.microphoneDetail"), permissions.snapshot.microphone),
            (Copy.accessibility, String(localized: "onboarding.accessibilityDetail"), permissions.snapshot.accessibility)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Layout.space6) {
            Text(Copy.appName)
                .font(.system(.largeTitle, design: .serif))
                .foregroundStyle(DesignSystem.ColorToken.ink)
            Text(String(localized: "onboarding.title"))
                .font(.title2)
                .foregroundStyle(DesignSystem.ColorToken.ink)
            Text(String(localized: "onboarding.intro"))
                .foregroundStyle(DesignSystem.ColorToken.mutedInk)

            VStack(alignment: .leading, spacing: DesignSystem.Layout.space3) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: DesignSystem.Layout.space3) {
                        Image(systemName: item.granted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.granted ? DesignSystem.ColorToken.action : DesignSystem.ColorToken.mutedInk)
                        VStack(alignment: .leading, spacing: DesignSystem.Layout.space1) {
                            Text(item.title)
                                .font(.headline)
                                .foregroundStyle(DesignSystem.ColorToken.ink)
                            if index == step || item.granted { Text(item.detail).font(.caption).foregroundStyle(DesignSystem.ColorToken.mutedInk) }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Layout.space3)
                    .padding(.vertical, DesignSystem.Layout.space2)
                    .background(
                        index == step ? DesignSystem.ColorToken.surface : .clear,
                        in: RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusSurface)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { step = index }
                }
            }

            HStack {
                Button(Copy.checkAgain) { model.permissions.refresh() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(DesignSystem.ColorToken.mutedInk)
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
        .foregroundStyle(DesignSystem.ColorToken.ink)
        .background(DesignSystem.ColorToken.canvas)
        .onAppear { permissions.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .dictatePermissionsDidChange)) { _ in
            permissions.refresh()
        }
    }

    private var current: (title: String, detail: String, granted: Bool) { steps[min(step, steps.count - 1)] }

    private func requestCurrent() {
        switch step {
        case 0: permissions.requestMicrophone()
        default: permissions.openAccessibilitySettings()
        }
    }

    private func advance() {
        guard permissions.snapshot.canRecord else {
            if let firstMissing = steps.firstIndex(where: { !$0.granted }) {
                step = firstMissing
            }
            return
        }
        if step < steps.count - 1 { step += 1 } else { model.onboardingDismissed = true }
    }
}
