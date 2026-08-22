import DictateCore
import SwiftUI

struct MainWindowView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
                .navigationSplitViewColumnWidth(min: DesignSystem.Layout.sidebarWidth, ideal: DesignSystem.Layout.sidebarWidth, max: DesignSystem.Layout.sidebarWidth)
        } detail: {
            Group {
                switch model.section {
                case .history: HistoryView(model: model)
                case .dictionary: DictionaryView(model: model)
                case .settings: SettingsView(model: model)
                }
            }
            .background(DesignSystem.ColorToken.surface)
        }
        .background(DesignSystem.ColorToken.canvas)
        .frame(minWidth: DesignSystem.Layout.mainMinWidth, minHeight: DesignSystem.Layout.mainMinHeight)
        .sheet(isPresented: Binding(
            get: { !model.onboardingDismissed && !model.permissions.snapshot.canRecord },
            set: { isPresented in if !isPresented { model.onboardingDismissed = true } }
        )) {
            OnboardingView(model: model)
                .frame(width: DesignSystem.Layout.onboardingWidth, height: DesignSystem.Layout.onboardingHeight)
        }
    }
}

private struct SidebarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Layout.space6) {
            Text(Copy.appName)
                .font(.system(.title2, design: .serif))
                .foregroundStyle(DesignSystem.ColorToken.ink)
                .padding(.horizontal, DesignSystem.Layout.space4)
                .padding(.top, DesignSystem.Layout.space6)

            List(selection: $model.section) {
                Label(Copy.history, systemImage: "text.alignleft")
                    .tag(AppSection.history)
                Label(Copy.dictionary, systemImage: "character.book.closed")
                    .tag(AppSection.dictionary)
                Label(Copy.settings, systemImage: "slider.horizontal.3")
                    .tag(AppSection.settings)
            }
            .listStyle(.sidebar)

            VStack(alignment: .leading, spacing: DesignSystem.Layout.space2) {
                Button {
                    if model.dictation.state == .idle { model.startRecording() } else { model.cancelRecording() }
                } label: {
                    Label(model.dictation.state == .idle ? Copy.startRecording : Copy.cancelRecording,
                          systemImage: model.dictation.state == .idle ? "circle.fill" : "xmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(model.dictation.state == .idle ? DesignSystem.ColorToken.action : DesignSystem.ColorToken.recording)
                .accessibilityHint(String(localized: "accessibility.recordButton.hint"))

                HStack(spacing: DesignSystem.Layout.space2) {
                    Circle()
                        .fill(model.permissions.snapshot.canRecord ? DesignSystem.ColorToken.action : DesignSystem.ColorToken.recording)
                        .frame(width: DesignSystem.Layout.space2, height: DesignSystem.Layout.space2)
                    Text(model.permissions.snapshot.canRecord ? String(localized: "common.ready") : String(localized: "common.permissionsNeeded"))
                        .font(.caption)
                        .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                    Spacer()
                    Text(model.shortcut.title)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "accessibility.permissionStatus"))
            }
            .padding(.horizontal, DesignSystem.Layout.space4)
            .padding(.bottom, DesignSystem.Layout.space4)
        }
        .background(.regularMaterial)
    }
}

struct HistoryView: View {
    @ObservedObject var model: AppModel
    @State private var selection = Set<UUID>()
    @State private var showDeleteConfirmation = false

    private var groups: [(String, [HistoryItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: model.filteredHistory) { item in
            if calendar.isDateInToday(item.timestamp) { return String(localized: "history.today") }
            if calendar.isDateInYesterday(item.timestamp) { return String(localized: "history.yesterday") }
            return item.timestamp.formatted(date: .abbreviated, time: .omitted)
        }
        return grouped.sorted { $0.value.map(\.timestamp).max() ?? .distantPast > $1.value.map(\.timestamp).max() ?? .distantPast }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignSystem.Layout.space3) {
                Text(Copy.history)
                    .font(.system(.title, design: .serif))
                Spacer()
                TextField(Copy.searchHistory, text: $model.historySearch)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: DesignSystem.Layout.historySearchWidth)
                    .accessibilityLabel(Copy.searchHistory)
                Menu {
                    Button(Copy.exportHistory) { model.exportHistory() }
                    Divider()
                    Button(Copy.deleteAllHistory, role: .destructive) { showDeleteConfirmation = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel(String(localized: "history.moreActions"))
            }
            .padding(.horizontal, DesignSystem.Layout.space8)
            .padding(.vertical, DesignSystem.Layout.space6)

            Divider().overlay(DesignSystem.ColorToken.hairline)

            ActiveTranscriptionView(controller: model.dictation)

            if groups.isEmpty {
                EmptyHistoryView(model: model)
            } else {
                List(selection: $selection) {
                    ForEach(groups, id: \.0) { group in
                        Section(group.0) {
                            ForEach(group.1) { item in
                                HistoryRow(item: item, model: model)
                                    .tag(item.id)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(DesignSystem.ColorToken.surface)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        if !selection.isEmpty {
                            Button(Copy.delete, role: .destructive) { showDeleteConfirmation = true }
                        }
                    }
                }
            }
        }
        .confirmationDialog(Copy.deleteAllHistory, isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(Copy.delete, role: .destructive) {
                if selection.isEmpty { model.deleteAllHistory() } else { model.deleteHistory(ids: selection); selection.removeAll() }
            }
            Button(Copy.cancel, role: .cancel) {}
        } message: {
            Text(String(localized: "history.deleteConfirmation"))
        }
    }
}

private struct ActiveTranscriptionView: View {
    @ObservedObject var controller: DictationController

    var body: some View {
        if controller.state == .idle {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DesignSystem.Layout.space2) {
                HStack(spacing: DesignSystem.Layout.space2) {
                    Circle()
                        .fill(DesignSystem.ColorToken.recording)
                        .frame(width: DesignSystem.Layout.space2, height: DesignSystem.Layout.space2)
                    Text(AccessibilitySupport.status(for: controller.state))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                }
                Text(controller.liveText.isEmpty ? String(localized: "recording.speakPrompt") : controller.liveText)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(DesignSystem.ColorToken.ink)
                    .frame(maxWidth: DesignSystem.Layout.transcriptMeasure, alignment: .leading)
                BreathLine(level: controller.inputLevel, active: true)
            }
            .padding(.horizontal, DesignSystem.Layout.space8)
            .padding(.vertical, DesignSystem.Layout.space4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AccessibilitySupport.status(for: controller.state))
            .accessibilityValue(controller.liveText)
        }
    }
}

private struct EmptyHistoryView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Layout.space3) {
            Spacer()
            Text(Copy.noHistory)
                .font(.system(.title, design: .serif))
                .foregroundStyle(DesignSystem.ColorToken.ink)
                .frame(maxWidth: DesignSystem.Layout.transcriptMeasure, alignment: .leading)
            Text(Copy.noHistoryDetail)
                .foregroundStyle(DesignSystem.ColorToken.mutedInk)
            Button(Copy.startRecording) { model.startRecording() }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.ColorToken.action)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Layout.space12)
        .background(DesignSystem.ColorToken.surface)
    }
}

private struct HistoryRow: View {
    let item: HistoryItem
    @ObservedObject var model: AppModel
    @State private var isHovering = false
    @State private var showAudit = false

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Layout.space3) {
            Rectangle()
                .fill(item.isPinned ? DesignSystem.ColorToken.action : .clear)
                .frame(width: DesignSystem.Layout.space1)
            VStack(alignment: .leading, spacing: DesignSystem.Layout.space2) {
                HStack(spacing: DesignSystem.Layout.space2) {
                    Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                    Text(formatDuration(item.duration))
                    Spacer()
                    if isHovering {
                        Button { model.dictation.copy(item) } label: { Image(systemName: "doc.on.doc") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(Copy.copyText)
                        Button { model.dictation.retryInsertion(for: item) } label: { Image(systemName: "arrow.uturn.forward") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(Copy.retryInsertion)
                        Button { model.togglePin(item) } label: { Image(systemName: item.isPinned ? "pin.slash" : "pin") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(String(localized: item.isPinned ? "history.unpin" : "history.pin"))
                    }
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(DesignSystem.ColorToken.mutedInk)

                Text(item.correctedText)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(DesignSystem.ColorToken.ink)
                    .frame(maxWidth: DesignSystem.Layout.transcriptMeasure, alignment: .leading)

                if !item.correctionAudit.isEmpty {
                    DisclosureGroup(String.localizedStringWithFormat(String(localized: "history.correctionCount"), item.correctionAudit.count), isExpanded: $showAudit) {
                        ForEach(item.correctionAudit) { audit in
                            HStack(spacing: DesignSystem.Layout.space2) {
                                Text(audit.heard)
                                Image(systemName: "arrow.right")
                                Text(audit.written)
                            }
                            .font(.caption)
                            .foregroundStyle(DesignSystem.ColorToken.mutedInk)
                        }
                    }
                    .font(.caption)
                    .tint(DesignSystem.ColorToken.action)
                }
                BreathLine(level: 0.2, active: false)
            }
        }
        .padding(.vertical, DesignSystem.Layout.space4)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.correctedText)
        .accessibilityValue("\(item.timestamp.formatted(date: .omitted, time: .shortened)), \(formatDuration(item.duration))")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(duration) / 60, Int(duration) % 60)
    }
}
