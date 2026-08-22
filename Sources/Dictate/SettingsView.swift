import DictateCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var showDeleteConfirmation = false

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
            }

            Section(Copy.speech) {
                LabeledContent(Copy.microphone, value: model.permissions.snapshot.microphone ? String(localized: "common.available") : String(localized: "common.needsPermission"))
                LabeledContent(Copy.speechRecognition, value: model.permissions.snapshot.speech ? String(localized: "common.available") : String(localized: "common.needsPermission"))
                LabeledContent(String(localized: "settings.speechModel"), value: model.dictation.speechModelAvailable ? String(localized: "common.available") : String(localized: "common.unavailable"))
                if !model.dictation.speechModelAvailable {
                    Text(String(localized: "settings.speechModelDetail"))
                        .font(.caption)
                        .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                }
                Button(Copy.checkAgain) { model.permissions.refresh() }
            }

            Section(Copy.insertion) {
                LabeledContent(Copy.accessibility, value: model.permissions.snapshot.accessibility ? String(localized: "common.available") : String(localized: "common.optional"))
                Text(String(localized: "settings.insertionDetail"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                if !model.permissions.snapshot.accessibility {
                    Button(Copy.openSettings) { model.permissions.openAccessibilitySettings() }
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
}
