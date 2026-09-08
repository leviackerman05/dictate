import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var permissions: PermissionService
    @ObservedObject private var dictation: DictationController

    init(model: AppModel) {
        self.model = model
        _permissions = ObservedObject(wrappedValue: model.permissions)
        _dictation = ObservedObject(wrappedValue: model.dictation)
    }

    private var busy: Bool { dictation.readiness == .settingUp || dictation.readiness == .modelLoaded }
    private var ready: Bool { permissions.snapshot.microphone && dictation.readiness == .ready }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                BrandTitle()
                Spacer()
                Text("Local · private · free")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(ready ? "Ready for your first words" : "Make room for your voice")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                Text("Allow your microphone and set up a local speech model. No account or developer tools needed.")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Image(systemName: permissions.snapshot.microphone ? "checkmark.circle.fill" : "mic")
                            .foregroundStyle(DesignSystem.ColorToken.action)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Microphone").font(.headline)
                            Text("Audio stays in memory during recording.")
                                .font(.caption).foregroundStyle(DesignSystem.ColorToken.secondaryText)
                        }
                        Spacer()
                        if !permissions.snapshot.microphone {
                            Button("Allow microphone") { permissions.requestMicrophone() }
                        }
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Speech model").font(.headline)
                            Spacer()
                            if dictation.readiness == .ready {
                                Label("Ready", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(DesignSystem.ColorToken.success)
                            }
                        }
                        Text(model.transcriptionProvider.title)
                            .font(.system(size: 15, weight: .semibold))
                        Text(model.transcriptionProvider == .apple
                             ? "macOS manages this model. Setup may download a speech asset for your language."
                             : "Download once, then dictate offline. First setup also prepares the model for your Mac and may take a few minutes.")
                            .font(.caption).foregroundStyle(DesignSystem.ColorToken.secondaryText)
                        if busy {
                            if case .downloading(let progress) = dictation.activeModelStatus, let progress {
                                ProgressView(value: progress)
                                Text("Downloading: \(Int(progress * 100))%")
                                    .font(.caption).monospacedDigit()
                            } else {
                                HStack {
                                    ProgressView().controlSize(.small)
                                    Text("Preparing your local model…").font(.caption)
                                }
                            }
                            Button("Cancel setup") { dictation.cancelModelSetup() }
                                .buttonStyle(.link)
                        } else if dictation.readiness != .ready {
                            Button(dictation.setupError == nil ? "Set up recommended model" : "Retry model setup") {
                                dictation.prepareModel(for: model.transcriptionProvider)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(DesignSystem.ColorToken.action)
                        }
                        if let error = dictation.setupError {
                            Text("Setup could not finish. Check your connection and available storage, then retry. \(error)")
                                .font(.caption).foregroundStyle(DesignSystem.ColorToken.failure)
                                .textSelection(.enabled)
                        }
                        DisclosureGroup("Choose another model or shortcut") {
                            VStack(alignment: .leading, spacing: 12) {
                                ModelSelectorMenu(selection: $model.transcriptionProvider)
                                    .disabled(busy)
                                OnboardingRecordingSetup(model: model)
                            }.padding(.top, 8)
                        }
                        .font(.caption)
                    }
                    Divider()
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "cursorarrow").foregroundStyle(DesignSystem.ColorToken.action)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Insert into other apps").font(.headline)
                            Text(permissions.snapshot.accessibility ? "Accessibility is enabled." : "Optional: enable Accessibility to insert at the cursor. You can copy completed text without it.")
                                .font(.caption).foregroundStyle(DesignSystem.ColorToken.secondaryText)
                            if !permissions.snapshot.accessibility {
                                Button("Enable automatic insertion") { permissions.requestAccessibility() }
                                    .buttonStyle(.link)
                            }
                        }
                    }
                }.padding(.trailing, 4)
            }
            HStack {
                Link("Privacy", destination: TrustLinks.privacyPolicy).font(.caption)
                Spacer()
                Button("Explore first") { model.onboardingDismissed = true }
                    .buttonStyle(.borderless)
                Button("Start using Dictate") { model.onboardingDismissed = true }
                    .buttonStyle(.borderedProminent).tint(DesignSystem.ColorToken.action)
                    .disabled(!ready)
            }
        }
        .padding(32)
        .foregroundStyle(DesignSystem.ColorToken.primaryText)
        .background(DesignSystem.ColorToken.surface)
        .onAppear { permissions.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .dictatePermissionsDidChange)) { _ in permissions.refresh() }
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
