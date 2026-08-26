import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var permissions: PermissionService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    init(model: AppModel) {
        self.model = model
        _permissions = ObservedObject(wrappedValue: model.permissions)
    }

    private var steps: [(title: String, detail: String, granted: Bool, icon: String)] {
        [
            (Copy.microphone, String(localized: "onboarding.microphoneDetail"), permissions.snapshot.microphone, "mic"),
            (Copy.accessibility, String(localized: "onboarding.accessibilityDetail"), permissions.snapshot.accessibility, "cursorarrow")
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                BrandTitle()
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(DesignSystem.ColorToken.success)
                        .frame(width: 7, height: 7)
                    Text(String(localized: "onboarding.privateBadge"))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "onboarding.eyebrow").uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(DesignSystem.ColorToken.action)
                Text(String(localized: "onboarding.title"))
                    .font(.system(size: 28, weight: .bold, design: .serif))
                Text(String(localized: "onboarding.intro"))
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 30)

            HStack(spacing: 6) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? DesignSystem.ColorToken.action : DesignSystem.ColorToken.border)
                        .frame(maxWidth: .infinity)
                        .frame(height: 4)
                }
            }
            .padding(.top, 22)

            OnboardingRecordingSetup(model: model)
                .padding(.top, 16)
                .zIndex(10)

            if model.shortcut == .fn {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "keyboard")
                        .foregroundStyle(DesignSystem.ColorToken.action)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "onboarding.fnHintTitle"))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        Text(String(localized: "onboarding.fnHintDetail"))
                            .font(.system(size: 10))
                            .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                    }
                    Spacer(minLength: 8)
                    Button(String(localized: "settings.openKeyboardSettings")) {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.keyboard")!)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignSystem.ColorToken.action)
                }
                .padding(12)
                .background(DesignSystem.ColorToken.action.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(DesignSystem.ColorToken.action.opacity(0.24)) }
                .padding(.top, 14)
            }

            Group {
                if allPermissionsGranted {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(DesignSystem.ColorToken.success)
                        Text(String(localized: "onboarding.readyTitle"))
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text(String(localized: "onboarding.readyDetail"))
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .transition(.opacity)
                } else {
                    let index = min(step, steps.count - 1)
                    let item = steps[index]
                    HStack(spacing: 13) {
                        Image(systemName: item.granted ? "checkmark.circle.fill" : item.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(item.granted ? DesignSystem.ColorToken.success : DesignSystem.ColorToken.action)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                if item.granted {
                                    Text(String(localized: "common.allowed"))
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(DesignSystem.ColorToken.success)
                                }
                            }
                            Text(item.detail)
                                .font(.system(size: 11))
                                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 4)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .background(DesignSystem.ColorToken.raisedSurface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(DesignSystem.ColorToken.action.opacity(0.52)) }
                    .id(item.title)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(y: 10)), removal: .opacity))
                }
            }
            .padding(.top, 18)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: step)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: allPermissionsGranted)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(localized: "onboarding.localStorageDetail"))
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Link(String(localized: "privacy.readPolicy"), destination: TrustLinks.privacyPolicy)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignSystem.ColorToken.action)
            }
            .padding(.top, 10)

            Spacer()

            HStack(alignment: .center) {
                if step == 1 && !permissions.snapshot.accessibility {
                    Button(String(localized: "onboarding.continueWithoutAccessibility")) {
                        model.onboardingDismissed = true
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                }
                Spacer()
                Button(primaryButtonTitle, action: primaryAction)
                    .buttonStyle(.borderedProminent)
                    .tint(DesignSystem.ColorToken.action)
            }
        }
        .padding(32)
        .foregroundStyle(DesignSystem.ColorToken.primaryText)
        .background(DesignSystem.ColorToken.surface)
        .onAppear {
            permissions.refresh()
            step = firstMissingStep
        }
        .onReceive(NotificationCenter.default.publisher(for: .dictatePermissionsDidChange)) { _ in
            permissions.refresh()
            step = firstMissingStep
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "onboarding.title"))
    }

    private var firstMissingStep: Int {
        steps.firstIndex(where: { !$0.granted }) ?? 0
    }

    private var allPermissionsGranted: Bool {
        steps.allSatisfy(\.granted)
    }

    private var primaryButtonTitle: String {
        if allPermissionsGranted { return String(localized: "onboarding.done") }
        let current = steps[min(step, steps.count - 1)]
        if current.granted {
            return step == steps.count - 1 ? String(localized: "onboarding.done") : String(localized: "onboarding.continue")
        }
        return step == 0 ? String(localized: "onboarding.allow") : Copy.openSettings
    }

    private func primaryAction() {
        if allPermissionsGranted {
            model.onboardingDismissed = true
            return
        }
        let current = steps[min(step, steps.count - 1)]
        if !current.granted {
            switch step {
            case 0: permissions.requestMicrophone()
            default: permissions.requestAccessibility()
            }
        } else if step < steps.count - 1 {
            step += 1
        } else {
            model.onboardingDismissed = true
        }
    }
}

private struct OnboardingRecordingSetup: View {
    @ObservedObject var model: AppModel

    private var modeDetail: String {
        model.recordingMode == .holdToTalk
            ? String(localized: "settings.holdModeDetail")
            : String(localized: "settings.toggleModeDetail")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "onboarding.triggerTitle"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Text(String(localized: "onboarding.triggerDetail"))
                        .font(.system(size: 10))
                        .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                }
                Spacer(minLength: 12)
                DictateDropdown(
                    selection: $model.shortcut,
                    items: ShortcutChoice.allCases.filter { $0 != .custom },
                    title: { $0.title },
                    width: 154,
                    accessibilityLabel: String(localized: "settings.pushToTalk")
                )
            }

            Divider().overlay(DesignSystem.ColorToken.border)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "onboarding.behaviorTitle"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Text(modeDetail)
                        .font(.system(size: 10))
                        .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                HStack(spacing: 3) {
                    ForEach(RecordingMode.allCases) { mode in
                        Button {
                            model.recordingMode = mode
                        } label: {
                            Text(mode.title)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(
                                    model.recordingMode == mode
                                        ? DesignSystem.ColorToken.primaryText
                                        : DesignSystem.ColorToken.secondaryText
                                )
                                .padding(.horizontal, 9)
                                .padding(.vertical, 7)
                                .background(
                                    model.recordingMode == mode
                                        ? DesignSystem.ColorToken.action.opacity(0.16)
                                        : .clear,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(model.recordingMode == mode ? .isSelected : [])
                    }
                }
                .padding(3)
                .background(DesignSystem.ColorToken.raisedSurface, in: Capsule())
                .overlay { Capsule().stroke(DesignSystem.ColorToken.border) }
            }
        }
        .padding(14)
        .background(DesignSystem.ColorToken.raisedSurface, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(DesignSystem.ColorToken.border) }
    }
}
