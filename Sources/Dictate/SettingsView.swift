import AppKit
import DictateCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var permissions: PermissionService
    @ObservedObject private var dictation: DictationController
    @State private var tab: SettingsTab = .general
    @State private var showDeleteConfirmation = false

    init(model: AppModel) {
        self.model = model
        _permissions = ObservedObject(wrappedValue: model.permissions)
        _dictation = ObservedObject(wrappedValue: model.dictation)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 22) {
                SettingsPageHeader()

                SettingsTabBar(selection: $tab)

                switch tab {
                case .general:
                    generalSettings
                case .audio:
                    audioSettings
                case .permissions:
                    permissionSettings
                }
            }
            .padding(32)
            .frame(maxWidth: 1100, alignment: .leading)
        }
        .background(DesignSystem.ColorToken.background)
        .onAppear { permissions.refresh() }
        .confirmationDialog(Copy.deleteAllHistory, isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(Copy.delete, role: .destructive) { model.deleteAllHistory() }
            Button(Copy.cancel, role: .cancel) {}
        } message: {
            Text(String(localized: "history.deleteConfirmation"))
        }
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard(
                title: String(localized: "settings.appearance"),
                detail: String(localized: "settings.appearanceDetail"),
                icon: "circle.lefthalf.filled"
            ) {
                HStack {
                    SettingsFieldLabel(
                        title: String(localized: "settings.appearance"),
                        detail: String(localized: "settings.appearanceDetail")
                    )
                    Spacer()
                    AppearanceChoiceBar(selection: $model.appearance)
                }
            }

            SettingsCard(
                title: String(localized: "settings.shortcut"),
                detail: String(localized: "settings.shortcutDetail"),
                icon: "command"
            ) {
                ShortcutChoiceMenu(selection: $model.shortcut)
                    // Keep the custom menu above the keyboard hint and the
                    // recording row that follow it in this settings card.
                    .zIndex(10)
                if model.shortcut == .fn {
                    FnKeyboardHint()
                }
                if model.shortcut == .custom {
                    ShortcutRecorder(shortcut: $model.customShortcut)
                        .frame(height: DesignSystem.Layout.shortcutRecorderHeight)
                        .accessibilityLabel(String(localized: "shortcut.recordPrompt"))
                    SettingsHelp(String(localized: "shortcut.recordDetail"))
                }

                Divider().overlay(DesignSystem.ColorToken.border)

                HStack {
                    SettingsFieldLabel(
                        title: String(localized: "settings.recordingBehavior"),
                        detail: model.recordingMode == .holdToTalk
                            ? String(localized: "settings.holdModeDetail")
                            : String(localized: "settings.toggleModeDetail")
                    )
                    Spacer()
                    RecordingModeChoiceBar(selection: $model.recordingMode)
                }
            }

            SettingsCard(
                title: String(localized: "settings.general"),
                detail: String(localized: "settings.generalDetail"),
                icon: "slider.horizontal.3"
            ) {
                SettingsToggleRow(
                    title: String(localized: "settings.showReadyIndicator"),
                    detail: String(localized: "settings.showReadyIndicatorDetail"),
                    isOn: $model.showReadyIndicator
                )
                Divider().overlay(DesignSystem.ColorToken.border)
                SettingsToggleRow(
                    title: Copy.keepHistory,
                    detail: String(localized: "settings.localOnly"),
                    isOn: $model.keepHistory
                )
                HStack {
                    SettingsFieldLabel(title: Copy.retention, detail: nil)
                    Spacer()
                    RetentionChoiceBar(selection: $model.retention, onChange: model.applyRetention)
                }
                HStack {
                    SettingsFieldLabel(title: Copy.deleteAllHistory, detail: String(localized: "settings.localOnly"))
                    Spacer()
                    Button(Copy.delete, role: .destructive) { showDeleteConfirmation = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            SettingsCard(
                title: Copy.about,
                detail: String(localized: "settings.updatesDetail"),
                icon: "info.circle"
            ) {
                HStack(alignment: .top) {
                    Text(String(localized: "settings.aboutText"))
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                    Spacer()
                    Text(String(localized: "settings.version"))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                }
                Divider().overlay(DesignSystem.ColorToken.border)
                HStack {
                    SettingsFieldLabel(
                        title: String(localized: "settings.reviewOnboarding"),
                        detail: String(localized: "settings.reviewOnboardingDetail")
                    )
                    Spacer()
                    Button(String(localized: "settings.reviewOnboarding")) {
                        model.onboardingDismissed = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private var audioSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard(
                title: String(localized: "settings.recordingModels"),
                detail: String(localized: "settings.recordingModelsDetail"),
                icon: "waveform"
            ) {
                SettingsToggleRow(
                    title: Copy.microphone,
                    detail: String(localized: "settings.microphoneDetail"),
                    isOn: $model.microphoneEnabled
                )
                SettingsPermissionRow(
                    title: Copy.microphone,
                    detail: String(localized: "settings.microphonePermissionDetail"),
                    isAllowed: permissions.snapshot.microphone,
                    action: { permissions.openMicrophoneSettings() }
                )
                Divider().overlay(DesignSystem.ColorToken.border)
                HStack {
                    SettingsFieldLabel(
                        title: String(localized: "settings.transcriptionModel"),
                        detail: model.transcriptionProvider.detail
                    )
                    Spacer()
                    ModelSelectorMenu(selection: $model.transcriptionProvider)
                }
                .zIndex(10)
                if model.transcriptionProvider == .apple {
                    ModelStatusRow(title: model.transcriptionProvider.title, status: .ready, progress: nil)
                }
            }

            SettingsCard(
                title: String(localized: "settings.localModels"),
                detail: String(localized: "models.catalogSubtitle"),
                icon: "cpu"
            ) {
                VStack(spacing: 0) {
                    ForEach(localProviders) { provider in
                        localModelRow(for: provider)
                        if provider != localProviders.last {
                            Divider().overlay(DesignSystem.ColorToken.border)
                                .padding(.vertical, 12)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func localModelRow(for provider: TranscriptionProvider) -> some View {
        let status = dictation.modelStatus(for: provider)
        let isSelected = model.transcriptionProvider == provider
        HStack(spacing: 14) {
            ModelStatusRow(
                title: provider.title,
                status: status,
                progress: downloadProgress(for: provider)
            )
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                switch status {
                case .notInstalled, .failed:
                    Button(status == .failed ? String(localized: "settings.parakeetRetry") : String(localized: "settings.parakeetDownload")) {
                        dictation.prepareModel(for: provider)
                    }
                    .buttonStyle(SettingsModelActionButtonStyle(prominent: true))
                case .downloading, .validating, .loading:
                    Button(String(localized: "settings.parakeetDownload")) {}
                        .buttonStyle(SettingsModelActionButtonStyle(prominent: true))
                        .disabled(true)
                case .ready:
                    if isSelected {
                        SettingsActiveBadge()
                    } else {
                        Button(String(localized: "models.useModel")) {
                            model.transcriptionProvider = provider
                        }
                        .buttonStyle(SettingsModelActionButtonStyle(prominent: true))
                    }
                    Button {
                        dictation.removeModel(for: provider)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(SettingsModelActionButtonStyle(destructive: true))
                    .help(String(localized: "settings.parakeetRemove"))
                }
            }
        }
    }

    private var permissionSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard(
                title: String(localized: "settings.insertionPermissions"),
                detail: String(localized: "settings.insertionDetail"),
                icon: "lock.shield"
            ) {
                SettingsPermissionRow(
                    title: Copy.accessibility,
                    detail: String(localized: "settings.insertionDetail"),
                    isAllowed: permissions.snapshot.accessibility,
                    action: { permissions.requestAccessibility() }
                )
                SettingsPermissionRow(
                    title: Copy.microphone,
                    detail: String(localized: "settings.microphonePermissionDetail"),
                    isAllowed: permissions.snapshot.microphone,
                    action: { permissions.openMicrophoneSettings() }
                )
            }

            SettingsCard(
                title: Copy.privacy,
                detail: String(localized: "settings.localOnly"),
                icon: "hand.raised"
            ) {
                SettingsFieldLabel(
                    title: String(localized: "privacy.localDataTitle"),
                    detail: String(localized: "privacy.localDataDetail")
                )
                Link(String(localized: "privacy.readPolicy"), destination: TrustLinks.privacyPolicy)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignSystem.ColorToken.action)
                    .accessibilityHint(String(localized: "privacy.readPolicyHint"))
                Divider().overlay(DesignSystem.ColorToken.border)
                SettingsToggleRow(
                    title: Copy.keepHistory,
                    detail: String(localized: "settings.localOnly"),
                    isOn: $model.keepHistory
                )
                HStack {
                    SettingsFieldLabel(title: Copy.retention, detail: nil)
                    Spacer()
                    RetentionChoiceBar(selection: $model.retention, onChange: model.applyRetention)
                }
            }
        }
    }

    private var localProviders: [TranscriptionProvider] {
        TranscriptionProvider.allCases.filter { $0 != .apple }
    }

    private func downloadProgress(for provider: TranscriptionProvider) -> Double? {
        if case .downloading(let progress) = dictation.modelStatus(for: provider) { return progress }
        return nil
    }
}

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general, audio, permissions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return String(localized: "settings.general")
        case .audio: return String(localized: "settings.audio")
        case .permissions: return String(localized: "settings.permissions")
        }
    }

    var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .audio: return "waveform"
        case .permissions: return "lock.shield"
        }
    }
}

private struct SettingsTabBar: View {
    @Binding var selection: SettingsTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                Button { selection = tab } label: {
                    Label(tab.title, systemImage: tab.icon)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(selection == tab ? DesignSystem.ColorToken.primaryText : DesignSystem.ColorToken.secondaryText)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(selection == tab ? DesignSystem.ColorToken.action.opacity(0.16) : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(DesignSystem.ColorToken.raisedSurface, in: Capsule())
        .overlay { Capsule().stroke(DesignSystem.ColorToken.border) }
    }
}

private struct AppearanceChoiceBar: View {
    @Binding var selection: AppearancePreference

    var body: some View {
        ChoicePillBar(items: AppearancePreference.allCases, selection: $selection) { $0.title }
    }
}

private struct RecordingModeChoiceBar: View {
    @Binding var selection: RecordingMode

    var body: some View {
        ChoicePillBar(items: RecordingMode.allCases, selection: $selection) { $0.title }
    }
}

private struct ShortcutChoiceMenu: View {
    @Binding var selection: ShortcutChoice

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            SettingsFieldLabel(
                title: String(localized: "settings.pushToTalk"),
                detail: String(localized: "settings.shortcutChoicesDetail")
            )
            Spacer(minLength: 20)
            DictateDropdown(
                selection: $selection,
                items: ShortcutChoice.allCases,
                title: { $0.title },
                width: 188,
                accessibilityLabel: String(localized: "settings.pushToTalk")
            )
        }
    }
}

private struct FnKeyboardHint: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "keyboard")
                .foregroundStyle(DesignSystem.ColorToken.action)
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "settings.fnHintTitle"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Text(String(localized: "settings.fnHintDetail"))
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
    }
}

private struct RetentionChoiceBar: View {
    @Binding var selection: HistoryRetention
    let onChange: () -> Void

    var body: some View {
        ChoicePillBar(items: HistoryRetention.allCases, selection: $selection, onChange: onChange) { retention in
            switch retention {
            case .oneDay: return String(localized: "settings.oneDay")
            case .oneWeek: return String(localized: "settings.oneWeek")
            case .oneMonth: return String(localized: "settings.oneMonth")
            case .forever: return String(localized: "settings.forever")
            }
        }
    }
}

private struct ChoicePillBar<Item: Equatable & Identifiable>: View {
    let items: [Item]
    @Binding var selection: Item
    var onChange: () -> Void = {}
    let title: (Item) -> String
    @State private var hovered: Item?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(items) { item in
                Button {
                    selection = item
                    onChange()
                } label: {
                    Text(title(item))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(selection == item ? DesignSystem.ColorToken.primaryText : DesignSystem.ColorToken.secondaryText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(
                            selection == item
                                ? DesignSystem.ColorToken.action.opacity(0.16)
                                : hovered == item ? DesignSystem.ColorToken.action.opacity(0.08) : .clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in hovered = hovering ? item : nil }
            }
        }
        .padding(3)
        .background(DesignSystem.ColorToken.raisedSurface, in: Capsule())
        .overlay { Capsule().stroke(DesignSystem.ColorToken.border) }
    }
}

private struct SettingsPageHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "settings.eyebrow").uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(DesignSystem.ColorToken.accentViolet)
            Text(Copy.settings)
                .font(.system(size: 32, weight: .bold, design: .serif))
            Text(String(localized: "settings.subtitle"))
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let detail: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignSystem.ColorToken.accentViolet)
                    .frame(width: 30, height: 30)
                    .background(DesignSystem.ColorToken.accentViolet.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                }
                Spacer()
            }
            content()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.ColorToken.cardBackground, in: RoundedRectangle(cornerRadius: 15))
        .overlay { RoundedRectangle(cornerRadius: 15).stroke(DesignSystem.ColorToken.border) }
    }
}

private struct SettingsFieldLabel: View {
    let title: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            SettingsFieldLabel(title: title, detail: nil)
            Spacer()
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            SettingsFieldLabel(title: title, detail: detail)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

private struct SettingsPermissionRow: View {
    let title: String
    let detail: String
    let isAllowed: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isAllowed ? DesignSystem.ColorToken.success : DesignSystem.ColorToken.warning)
                .frame(width: 8, height: 8)
            SettingsFieldLabel(title: title, detail: detail)
            Spacer()
            Text(isAllowed ? String(localized: "common.allowed") : String(localized: "common.required"))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(isAllowed ? DesignSystem.ColorToken.success : DesignSystem.ColorToken.warning)
            if !isAllowed {
                Button(Copy.openSettings, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}

private struct SettingsHelp: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(DesignSystem.ColorToken.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ModelStatusRow: View {
    let title: String
    let status: RecognitionModelStatus
    let progress: Double?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .lineLimit(1)
            Spacer(minLength: 4)
            if let progress {
                SettingsDownloadRing(progress: progress)
            } else if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .tint(DesignSystem.ColorToken.action)
            }
            Text(statusLabel)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(statusLabel)
    }

    private var statusLabel: String {
        switch status {
        case .notInstalled: return String(localized: "common.notInstalled")
        case .downloading: return String(localized: "common.downloading")
        case .validating: return String(localized: "common.validating")
        case .loading: return String(localized: "common.loading")
        case .ready: return String(localized: "common.ready")
        case .failed: return String(localized: "common.failed")
        }
    }

    private var statusColor: Color {
        switch status {
        case .ready: return DesignSystem.ColorToken.success
        case .failed: return DesignSystem.ColorToken.failure
        case .downloading, .validating, .loading: return DesignSystem.ColorToken.warning
        case .notInstalled: return DesignSystem.ColorToken.secondaryText
        }
    }

    private var isBusy: Bool {
        switch status {
        case .downloading, .validating, .loading: return true
        default: return false
        }
    }
}

private struct SettingsDownloadRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(DesignSystem.ColorToken.border, lineWidth: 2)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(DesignSystem.ColorToken.action, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((progress * 100).rounded()))")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
        }
        .frame(width: 24, height: 24)
    }
}

/// Custom capsule button for local-model actions in Settings. No
/// `.bordered`/`.borderedProminent`.
private struct SettingsModelActionButtonStyle: ButtonStyle {
    var prominent: Bool = false
    var destructive: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(backgroundColor, in: Capsule())
            .overlay { Capsule().stroke(borderColor, lineWidth: DesignSystem.Layout.hairline) }
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: DesignSystem.Motion.feedback, bounce: 0.2), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        if prominent { return DesignSystem.ColorToken.inverseText }
        if destructive { return DesignSystem.ColorToken.failure }
        return DesignSystem.ColorToken.primaryText
    }

    private var backgroundColor: Color {
        if prominent { return DesignSystem.ColorToken.action }
        if destructive { return DesignSystem.ColorToken.failure.opacity(0.1) }
        return DesignSystem.ColorToken.raisedSurface
    }

    private var borderColor: Color {
        if prominent { return .clear }
        if destructive { return DesignSystem.ColorToken.failure.opacity(0.35) }
        return DesignSystem.ColorToken.border
    }
}

private struct SettingsActiveBadge: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .bold))
            Text(String(localized: "models.active"))
        }
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .foregroundStyle(DesignSystem.ColorToken.action)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(DesignSystem.ColorToken.action.opacity(0.14), in: Capsule())
    }
}
