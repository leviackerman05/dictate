import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var permissions: PermissionService
    @ObservedObject private var dictation: DictationController

    @State private var showOptions = false
    @State private var showError = false

    init(model: AppModel) {
        self.model = model
        _permissions = ObservedObject(wrappedValue: model.permissions)
        _dictation = ObservedObject(wrappedValue: model.dictation)
    }

    private var busy: Bool { dictation.readiness == .settingUp || dictation.readiness == .modelLoaded }
    private var ready: Bool { permissions.snapshot.microphone && dictation.readiness == .ready }

    private var setupStatus: String {
        switch dictation.activeModelStatus {
        case .downloading: return "Downloading your speech model…"
        case .validating: return "Checking model files…"
        case .downloaded, .loading: return "Loading the model on your Mac…"
        case .ready: return "Finishing setup…"
        case .notInstalled: return "Checking speech model availability…"
        case .failed: return "Preparing to retry…"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                BrandTitle()
                Spacer()
                Text("Private on your Mac · Free")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(ready ? "Ready for your first words" : "Make room for your voice")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                Text("A microphone, a speech model, and you. No account needed.")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Image(systemName: permissions.snapshot.microphone ? "checkmark.circle.fill" : "mic")
                            .foregroundStyle(DesignSystem.ColorToken.action)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Allow your microphone").font(.headline)
                            Text("Your recording is processed on this Mac.")
                                .font(.caption).foregroundStyle(DesignSystem.ColorToken.secondaryText)
                        }
                        Spacer()
                        if !permissions.snapshot.microphone {
                            Button("Allow microphone") { permissions.requestMicrophone() }
                                .buttonStyle(.bordered).controlSize(.large)
                        } else {
                            Label("Ready", systemImage: "checkmark").foregroundStyle(DesignSystem.ColorToken.success)
                        }
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(model.transcriptionProvider.title).font(.headline)
                            Spacer()
                            if dictation.readiness == .ready {
                                Label("Ready", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(DesignSystem.ColorToken.success)
                            }
                        }
                        Text(model.transcriptionProvider == .apple
                             ? "Built into macOS. Apple may download speech files for your language."
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
                                    Text(setupStatus).font(.caption)
                                }
                            }
                            Button("Cancel setup") { dictation.cancelModelSetup() }
                                .buttonStyle(.link)
                        } else if dictation.readiness != .ready {
                            Button(dictation.setupError == nil ? (model.transcriptionProvider == .apple ? "Use model" : "Download and use model") : "Retry model setup") {
                                dictation.prepareModel(for: model.transcriptionProvider)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(DesignSystem.ColorToken.action).controlSize(.large)
                        }
                        if dictation.setupError != nil {
                            Button("Setup could not finish — show details") { showError = true }
                                .foregroundStyle(DesignSystem.ColorToken.failure)
                                .popover(isPresented: $showError) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Setup could not finish").font(.headline)
                                        Text("Check your connection and free storage, then retry. You can also choose another model in setup options.")
                                        ScrollView { Text(dictation.setupError ?? "").textSelection(.enabled) }
                                            .frame(maxHeight: 140)
                                    }.padding(24).frame(width: 380)
                                }
                        }
                    }
                    if model.transcriptionProvider == .apple {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Try NVIDIA Parakeet").font(.headline)
                                Text("If Apple misses your words, Parakeet may work better for your voice. Download once and keep dictating locally.")
                                    .font(.caption).foregroundStyle(DesignSystem.ColorToken.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            Button([.downloaded, .ready].contains(dictation.modelStatus(for: .parakeet)) ? "Use model" : "Download") {
                                model.transcriptionProvider = .parakeet
                                dictation.prepareModel(for: .parakeet)
                            }
                            .buttonStyle(.bordered).controlSize(.large).disabled(busy)
                        }
                    }
                    Divider()
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "cursorarrow").foregroundStyle(DesignSystem.ColorToken.action)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Insert words at your cursor").font(.headline)
                            Text(permissions.snapshot.accessibility ? "Accessibility is enabled. You’re ready to write in other apps." : "Optional. Allow Accessibility, or copy your words yourself.")
                                .font(.caption).foregroundStyle(DesignSystem.ColorToken.secondaryText)
                        }
                        Spacer(minLength: 16)
                        if !permissions.snapshot.accessibility {
                            Button("Enable insertion") { permissions.requestAccessibility() }
                                .buttonStyle(.bordered).controlSize(.large)
                                .help("Open Accessibility settings to allow Dictate to insert text into other apps")
                        } else {
                            Label("Ready", systemImage: "checkmark").foregroundStyle(DesignSystem.ColorToken.success)
                        }
                    }
                }.padding(.trailing, 4)
            }
            Spacer(minLength: 0)
            HStack {
                Button("Setup options") { showOptions = true }.buttonStyle(.borderless)
                Link("Privacy", destination: TrustLinks.privacyPolicy).font(.caption)
                Spacer()
                Button("Explore first") { model.onboardingDismissed = true }
                    .buttonStyle(.borderless)
                Button("Start using Dictate") { model.onboardingDismissed = true }
                    .buttonStyle(.borderedProminent).tint(DesignSystem.ColorToken.action)
                    .controlSize(.large).disabled(!ready)
            }
        }
        .padding(32)
        .foregroundStyle(DesignSystem.ColorToken.primaryText)
        .background(DesignSystem.ColorToken.surface)
        .sheet(isPresented: $showOptions) {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("Make Dictate yours").font(.title2.bold())
                    Spacer()
                    Button("Done") { showOptions = false }.keyboardShortcut(.defaultAction)
                }
                Text("Choose a different local model or change how you start recording.")
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                ModelSelectorMenu(selection: $model.transcriptionProvider).disabled(busy)
                if busy { Text("Wait for setup to finish, or cancel it to change models.").font(.caption) }
                OnboardingRecordingSetup(model: model)
            }.padding(28).frame(width: 560)
                .background(DesignSystem.ColorToken.surface)
        }
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
