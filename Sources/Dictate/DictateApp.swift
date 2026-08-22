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
                    if appDelegate.model.dictation.state == .idle { appDelegate.model.startRecording() }
                    else { appDelegate.model.finishRecording() }
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
                Button(Copy.cancelRecording) { appDelegate.model.cancelRecording() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            CommandMenu(Copy.appName) {
                Button(Copy.history) { appDelegate.model.section = .history }
                    .keyboardShortcut("1", modifiers: [.command])
                Button(Copy.dictionary) { appDelegate.model.section = .dictionary }
                    .keyboardShortcut("2", modifiers: [.command])
                Button(Copy.settings) { appDelegate.model.section = .settings }
                    .keyboardShortcut(",", modifiers: [.command])
            }
        }

        Settings {
            SettingsView(model: appDelegate.model)
                .frame(width: DesignSystem.Layout.settingsWidth, height: DesignSystem.Layout.settingsHeight)
        }
    }
}
