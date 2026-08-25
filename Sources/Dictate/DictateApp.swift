import SwiftUI

@main
struct DictateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(Copy.appName) {
            MainWindowView(model: appDelegate.model)
        }
        .commands {
            CommandGroup(after: .textEditing) {
                Button(Copy.startRecording) {
                    if appDelegate.model.dictation.state == .idle || appDelegate.model.dictation.lastFailure != nil { appDelegate.model.startRecording() }
                    else { appDelegate.model.finishRecording() }
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
                .disabled(appDelegate.model.dictation.state == .finalizing || appDelegate.model.dictation.state == .delivering)
            }
            CommandGroup(after: .textEditing) {
                Button(Copy.cancelRecording) { appDelegate.model.cancelRecording() }
                    .keyboardShortcut(.escape)
                    .disabled(appDelegate.model.dictation.state == .idle)
            }
            CommandMenu(Copy.appName) {
                Button(Copy.dashboard) { appDelegate.model.section = .dashboard }
                    .keyboardShortcut("1", modifiers: [.command])
                Button(Copy.history) { appDelegate.model.section = .history }
                    .keyboardShortcut("2", modifiers: [.command])
                Button(Copy.dictionary) { appDelegate.model.section = .dictionary }
                    .keyboardShortcut("3", modifiers: [.command])
                Button(Copy.statistics) { appDelegate.model.section = .statistics }
                    .keyboardShortcut("4", modifiers: [.command])
                Button(Copy.aiModels) { appDelegate.model.section = .aiModels }
                    .keyboardShortcut("5", modifiers: [.command])
                Button(Copy.settings) { appDelegate.model.section = .settings }
                    .keyboardShortcut(",", modifiers: [.command])
            }
        }

        Settings {
            SettingsView(model: appDelegate.model)
                .frame(width: DesignSystem.Layout.settingsWidth, height: DesignSystem.Layout.settingsHeight)
                .foregroundStyle(DesignSystem.ColorToken.ink)
                .preferredColorScheme(appDelegate.model.appearance.colorScheme)
        }
    }
}
