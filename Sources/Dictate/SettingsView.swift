import DictateCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var permissions: PermissionService
    @State private var showDeleteConfirmation = false

    init(model: AppModel) {
        self.model = model
        _permissions = ObservedObject(wrappedValue: model.permissions)
    }

    var body: some View {
        Form {
            Section(Copy.shortcut) {
                Picker(String(localized: "settings.pushToTalk"), selection: $model.shortcut) {
                    ForEach(ShortcutChoice.allCases) { choice in Text(choice.title).tag(choice) }
                }
                if model.shortcut == .custom {
                    ShortcutRecorder(shortcut: $model.customShortcut)
                        .frame(height: DesignSystem.Layout.shortcutRecorderHeight)
                        .accessibilityLabel(String(localized: "shortcut.recordPrompt"))
                    Text(String(localized: "shortcut.recordDetail"))
                        .font(.caption)
                        .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                }
                Text(String(localized: "settings.shortcutDetail"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                Picker(String(localized: "settings.recordingMode"), selection: $model.recordingMode) {
                    ForEach(RecordingMode.allCases) { mode in Text(mode.title).tag(mode) }
                }
                Text(model.recordingMode == .holdToTalk ? String(localized: "settings.holdModeDetail") : String(localized: "settings.toggleModeDetail"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.ColorToken.mutedInk)
            }

            Section(Copy.speech) {
                Toggle(String(localized: "settings.useMicrophone"), isOn: $model.microphoneEnabled)
                Picker(String(localized: "settings.transcriptionModel"), selection: $model.transcriptionProvider) {
                    ForEach(TranscriptionProvider.allCases) { provider in Text(provider.title).tag(provider) }
                }
                Text(model.transcriptionProvider.detail)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                LabeledContent(Copy.microphone, value: permissions.snapshot.microphone ? String(localized: "common.allowed") : String(localized: "common.blocked"))
                if !permissions.snapshot.microphone {
                    Button(Copy.openSettings) { permissions.openMicrophoneSettings() }
                }
                LabeledContent(String(localized: "settings.speechModel"), value: model.dictation.speechModelAvailable ? String(localized: "common.ready") : String(localized: "common.unavailable"))
                if !model.dictation.speechModelAvailable && model.transcriptionProvider == .apple {
                    Text(String(localized: "settings.speechModelDetail"))
                        .font(.caption)
                        .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                }
                HStack {
                    LabeledContent(String(localized: "settings.parakeetModel"), value: parakeetStatusTitle)
                    if parakeetIsBusy {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                            .accessibilityLabel(String(localized: "common.downloading"))
                    }
                }
                Text(String(localized: "settings.parakeetModelDetail"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                HStack {
                    Button(parakeetActionTitle) { model.dictation.prepareParakeetModel() }
                        .disabled(parakeetIsBusy || parakeetIsReady)
                    if parakeetIsReady {
                        Button(String(localized: "settings.parakeetRemove"), role: .destructive) {
                            model.dictation.removeParakeetModel()
                        }
                    }
                }
            }

            Section(Copy.insertion) {
                LabeledContent(Copy.accessibility, value: permissions.snapshot.accessibility ? String(localized: "common.allowed") : String(localized: "common.required"))
                Text(String(localized: "settings.insertionDetail"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                if !permissions.snapshot.accessibility {
                    Button(Copy.openSettings) { permissions.requestAccessibility() }
                }
            }

            Section(Copy.privacy) {
                Toggle(Copy.keepHistory, isOn: $model.keepHistory)
                Picker(Copy.retention, selection: $model.retention) {
                    Text(String(localized: "settings.oneDay")).tag(HistoryRetention.oneDay)
                    Text(String(localized: "settings.oneWeek")).tag(HistoryRetention.oneWeek)
                    Text(String(localized: "settings.oneMonth")).tag(HistoryRetention.oneMonth)
                    Text(String(localized: "settings.forever")).tag(HistoryRetention.forever)
                }
                .onChange(of: model.retention) { _, _ in model.applyRetention() }
                Button(Copy.deleteAllHistory, role: .destructive) { showDeleteConfirmation = true }
                Text(String(localized: "settings.localOnly"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.ColorToken.mutedInk)
            }

            Section(Copy.about) {
                Text(String(localized: "settings.aboutText"))
                Text(String(localized: "settings.version"))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(DesignSystem.ColorToken.mutedInk)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(DesignSystem.ColorToken.surface)
        .padding(DesignSystem.Layout.space6)
        .navigationTitle(Copy.settings)
        .confirmationDialog(Copy.deleteAllHistory, isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(Copy.delete, role: .destructive) { model.deleteAllHistory() }
            Button(Copy.cancel, role: .cancel) {}
        } message: {
            Text(String(localized: "history.deleteConfirmation"))
        }
    }

    private var parakeetIsReady: Bool {
        if case .ready = model.dictation.parakeetModelStatus { return true }
        return false
    }

    private var parakeetIsBusy: Bool {
        switch model.dictation.parakeetModelStatus {
        case .downloading, .validating, .loading: return true
        default: return false
        }
    }

    private var parakeetStatusTitle: String {
        switch model.dictation.parakeetModelStatus {
        case .notInstalled: return String(localized: "common.notInstalled")
        case .downloading: return String(localized: "common.downloading")
        case .validating: return String(localized: "common.validating")
        case .loading: return String(localized: "common.loading")
        case .ready: return String(localized: "common.ready")
        case .failed: return String(localized: "common.failed")
        }
    }

    private var parakeetActionTitle: String {
        switch model.dictation.parakeetModelStatus {
        case .failed: return String(localized: "settings.parakeetRetry")
        case .ready: return String(localized: "settings.parakeetReady")
        default: return String(localized: "settings.parakeetDownload")
        }
    }
}
