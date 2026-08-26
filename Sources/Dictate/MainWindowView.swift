import DictateCore
import SwiftUI

struct MainWindowView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var permissions: PermissionService

    init(model: AppModel) {
        self.model = model
        _permissions = ObservedObject(wrappedValue: model.permissions)
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                DictateSidebar(model: model)
                Divider().overlay(DesignSystem.ColorToken.border)

                Group {
                    switch model.section {
                    case .dashboard: DashboardView(model: model)
                    case .history: HistoryView(model: model)
                    case .dictionary: DictionaryView(model: model)
                    case .statistics: StatisticsView(model: model)
                    case .aiModels: AIModelsView(model: model)
                    case .settings: SettingsView(model: model)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if !permissions.snapshot.microphone || !model.onboardingDismissed {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                OnboardingView(model: model)
                    .frame(width: DesignSystem.Layout.onboardingWidth, height: DesignSystem.Layout.onboardingHeight)
                    .dsPanel(cornerRadius: 18)
                    .shadow(color: .black.opacity(DesignSystem.Shadow.overlayOpacity), radius: DesignSystem.Shadow.overlayRadius, y: DesignSystem.Shadow.overlayY)
                    .zIndex(1)
            }
        }
        .foregroundStyle(DesignSystem.ColorToken.primaryText)
        .background(DesignSystem.ColorToken.background)
        .preferredColorScheme(model.appearance.colorScheme)
        .frame(minWidth: DesignSystem.Layout.mainMinWidth, idealWidth: DesignSystem.Layout.mainIdealWidth, minHeight: DesignSystem.Layout.mainMinHeight, idealHeight: DesignSystem.Layout.mainIdealHeight)
        .onAppear { permissions.refresh() }
    }
}

struct HistoryView: View {
    @ObservedObject var model: AppModel
    @State private var selectedDay: HistoryDayFilter = .today
    @State private var showDeleteConfirmation = false
    @State private var showCopyToast = false
    @State private var copyToastTask: Task<Void, Never>?

    private let sectionAccents: [Color] = [
        DesignSystem.ColorToken.action,
        DesignSystem.ColorToken.amberIndex,
        DesignSystem.ColorToken.mossIndex,
        DesignSystem.ColorToken.coralIndex
    ]

    private var availableDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    private var snapshot: HistorySnapshot {
        let items = model.filteredHistory
        let calendar = Calendar.current
        let visibleItems: [HistoryItem]
        if case .date(let date) = selectedDay {
            visibleItems = items.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
        } else {
            visibleItems = items
        }
        let sortedItems = visibleItems.sorted { $0.timestamp > $1.timestamp }
        let groups = Dictionary(grouping: sortedItems) { calendar.startOfDay(for: $0.timestamp) }
            .map { HistoryDayGroup(day: $0.key, items: $0.value.sorted { $0.timestamp > $1.timestamp }) }
            .sorted { $0.day > $1.day }
        return HistorySnapshot(items: sortedItems, groups: groups)
    }

    var body: some View {
        let snapshot = snapshot
        VStack(spacing: 0) {
            DayIndex(selectedDay: $selectedDay, dates: availableDates)

            headerBar(itemCount: snapshot.items.count)

            SessionStatusStrip(controller: model.dictation)

            if snapshot.items.isEmpty {
                EmptyHistoryView(model: model, isFiltered: !model.historySearch.isEmpty || selectedDay != .all && selectedDay != .today)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(Array(snapshot.groups.enumerated()), id: \.element.id) { index, group in
                            VStack(alignment: .leading, spacing: 10) {
                                HistorySectionHeader(
                                    day: group.day,
                                    itemCount: group.items.count,
                                    accent: sectionAccents[index % sectionAccents.count]
                                )
                                ForEach(group.items) { item in
                                    HistoryCard(
                                        item: item,
                                        onCopy: {
                                            model.copyHistoryItem(item)
                                            flashCopyToast()
                                        },
                                        onDelete: { model.deleteHistory(ids: [item.id]) },
                                        onTogglePin: { model.togglePin(item) },
                                        onRetryInsertion: { model.dictation.retryInsertion(for: item) },
                                        onLearnCorrection: { model.learnCorrection($0) }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .background(DesignSystem.ColorToken.background)
            }
        }
        .background(DesignSystem.ColorToken.surface)
        .overlay(alignment: .bottom) {
            if showCopyToast { copyToast }
        }
        .confirmationDialog(Copy.deleteAllHistory, isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(Copy.delete, role: .destructive) {
                model.deleteAllHistory()
            }
            Button(Copy.cancel, role: .cancel) {}
        } message: {
            Text(String(localized: "history.deleteConfirmation"))
        }
    }

    private func headerBar(itemCount: Int) -> some View {
        HStack(alignment: .center, spacing: DesignSystem.Layout.space3) {
            Text(Copy.history)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
            Text(selectedDay.label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(DesignSystem.ColorToken.action)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(DesignSystem.ColorToken.action.opacity(0.1), in: Capsule())
                .overlay { Capsule().stroke(DesignSystem.ColorToken.action.opacity(0.28), lineWidth: DesignSystem.Layout.hairline) }

            Spacer()

            TextField(Copy.searchHistory, text: $model.historySearch)
                .textFieldStyle(.plain)
                .padding(.leading, 31)
                .padding(.trailing, 11)
                .frame(width: DesignSystem.Layout.historySearchWidth, height: 30)
                .background(DesignSystem.ColorToken.raisedSurface, in: RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusField))
                .overlay { RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusField).stroke(DesignSystem.ColorToken.border) }
                .overlay(alignment: .leading) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                        .padding(.leading, 10)
                        .allowsHitTesting(false)
                }
                .padding(.leading, 20)
                .accessibilityLabel(Copy.searchHistory)

            Text(String.localizedStringWithFormat(String(localized: "history.itemCount"), itemCount))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                .frame(minWidth: 50, alignment: .trailing)

            Menu {
                Button(Copy.exportHistory) { model.exportHistory() }
                Divider()
                Button(Copy.deleteAllHistory, role: .destructive) { showDeleteConfirmation = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                    .frame(width: 28, height: 28)
                    .background(DesignSystem.ColorToken.raisedSurface, in: RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusField))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusField)
                            .stroke(DesignSystem.ColorToken.border, lineWidth: DesignSystem.Layout.hairline)
                    }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(String(localized: "history.moreActions"))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 17)
    }

    private var copyToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignSystem.ColorToken.mossIndex)
            Text(String(localized: "recording.copied"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(DesignSystem.ColorToken.inverseText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(DesignSystem.ColorToken.primaryText, in: Capsule())
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .padding(.bottom, 26)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityLabel(String(localized: "recording.copied"))
    }

    private func flashCopyToast() {
        copyToastTask?.cancel()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { showCopyToast = true }
        copyToastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.22)) { showCopyToast = false }
        }
    }
}

private struct HistoryDayGroup: Identifiable {
    let day: Date
    let items: [HistoryItem]
    var id: Date { day }
}

private struct HistorySnapshot {
    let items: [HistoryItem]
    let groups: [HistoryDayGroup]
}

private enum HistoryDayFilter: Equatable {
    case date(Date)
    case all

    static var today: Self { .date(Calendar.current.startOfDay(for: .now)) }

    var label: String {
        switch self {
        case .all: return Copy.all
        case .date(let date):
            return Calendar.current.isDateInToday(date) ? String(localized: "history.today") : date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

private struct DayIndex: View {
    @Binding var selectedDay: HistoryDayFilter
    let dates: [Date]

    private let accents: [Color] = [
        DesignSystem.ColorToken.action,
        DesignSystem.ColorToken.amberIndex,
        DesignSystem.ColorToken.mossIndex,
        DesignSystem.ColorToken.action,
        DesignSystem.ColorToken.amberIndex,
        DesignSystem.ColorToken.mossIndex,
        DesignSystem.ColorToken.coralIndex
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(dates.enumerated()), id: \.element) { index, date in
                DayButton(
                    date: date,
                    accent: accents[index % accents.count],
                    isSelected: isSelected(date),
                    action: { selectedDay = .date(date) }
                )
            }
            DayButton(
                date: nil,
                accent: DesignSystem.ColorToken.primaryText,
                isSelected: isAllSelected,
                action: { selectedDay = .all }
            )
        }
        .frame(height: 59)
        .background(DesignSystem.ColorToken.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(DesignSystem.ColorToken.border).frame(height: 1) }
    }

    private var isAllSelected: Bool {
        if case .all = selectedDay { return true }
        return false
    }

    private func isSelected(_ date: Date) -> Bool {
        guard case .date(let chosen) = selectedDay else { return false }
        return Calendar.current.isDate(chosen, inSameDayAs: date)
    }
}

private struct DayButton: View {
    let date: Date?
    let accent: Color
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                if let date {
                    Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                    Text(date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                } else {
                    Text("ALL")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                    Text("•••")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
            }
            .foregroundStyle(isSelected ? DesignSystem.ColorToken.primaryText : DesignSystem.ColorToken.secondaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isHovering ? DesignSystem.ColorToken.raisedSurface.opacity(0.7) : .clear)
            .overlay(alignment: .bottom) {
                Rectangle().fill(isSelected ? accent : .clear).frame(height: isSelected ? 3 : 2)
            }
            .animation(.easeOut(duration: DesignSystem.Motion.feedback), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovering = hovering }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(date.map { $0.formatted(date: .complete, time: .omitted) } ?? Copy.all)
    }
}

private struct SessionStatusStrip: View {
    @ObservedObject var controller: DictationController

    var body: some View {
        if controller.state != .idle {
            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: statusColor.opacity(0.45), radius: 4)
                Text(AccessibilitySupport.status(for: controller.state))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                Spacer()
                if isListening {
                    SignalLevelBars(level: controller.inputLevel, color: DesignSystem.ColorToken.action)
                } else if controller.state == .finalizing || controller.state == .delivering {
                    ProcessingDots()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 11)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: DesignSystem.Motion.settle, dampingFraction: 0.8), value: controller.state)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AccessibilitySupport.status(for: controller.state))
        }
    }

    private var statusColor: Color {
        if case .failed = controller.state { return DesignSystem.ColorToken.failure }
        return DesignSystem.ColorToken.action
    }

    private var isListening: Bool {
        switch controller.state {
        case .listening, .transcribing: return true
        default: return false
        }
    }
}

private struct EmptyHistoryView: View {
    @ObservedObject var model: AppModel
    let isFiltered: Bool

    var body: some View {
        VStack(spacing: 14) {
            BrandMark(size: 42, variant: .monochrome)
            Text(isFiltered ? String(localized: "history.empty.filteredTitle") : Copy.noHistory)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
            Text(isFiltered ? String(localized: "history.empty.filteredDetail") : Copy.noHistoryDetail)
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                .multilineTextAlignment(.center)
            if !isFiltered {
                Button { model.startRecording() } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(Copy.startRecording)
                    }
                }
                .buttonStyle(CobaltCapsuleButtonStyle())
                .disabled(!model.permissions.snapshot.canRecord)
                .accessibilityHint(String(localized: "accessibility.recordButton.hint"))
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(48)
        .background(DesignSystem.ColorToken.background)
    }
}

private struct HistorySectionHeader: View {
    let day: Date
    let itemCount: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(accent)
                .frame(width: 4, height: 13)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .kerning(0.9)
                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
            Text(String(format: "%02d", itemCount))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(DesignSystem.ColorToken.disabledText)
            Rectangle()
                .fill(DesignSystem.ColorToken.border)
                .frame(height: DesignSystem.Layout.hairline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
    }

    private var label: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return String(localized: "history.today") }
        if calendar.isDateInYesterday(day) { return String(localized: "history.yesterday") }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

private struct HistoryCard: View {
    let item: HistoryItem
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onRetryInsertion: () -> Void
    let onLearnCorrection: (CorrectionAudit) -> Void

    @State private var isHovering = false
    @State private var isExpanded = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            mainRow

            if isExpanded {
                expandedContent
            }
        }
        .background(isHovering || isExpanded ? DesignSystem.ColorToken.raisedSurface : DesignSystem.ColorToken.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusSurface))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusSurface)
                .fill(DesignSystem.ColorToken.action.opacity(isHovering || isExpanded ? 0.045 : 0))
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusSurface)
                .stroke(
                    isHovering || isExpanded ? DesignSystem.ColorToken.action.opacity(0.35) : DesignSystem.ColorToken.border,
                    lineWidth: DesignSystem.Layout.hairline
                )
                .allowsHitTesting(false)
        }
        .shadow(
            color: .black.opacity(isHovering || isExpanded ? 0.09 : 0.05),
            radius: isHovering || isExpanded ? 12 : 7,
            y: 4
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: DesignSystem.Motion.feedback)) { isHovering = hovering }
        }
        .confirmationDialog(String(localized: "history.deleteItemTitle"), isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(Copy.delete, role: .destructive) {
                onDelete()
            }
            Button(Copy.cancel, role: .cancel) {}
        } message: {
            Text(String(localized: "history.deleteItemMessage"))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.correctedText)
        .accessibilityValue("\(item.timestamp.formatted(date: .omitted, time: .shortened)), \(formatDuration(item.duration)), \(item.insertionResult.detailText)")
    }

    private var mainRow: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: toggleExpanded) {
                HStack(alignment: .top, spacing: 14) {
                    dateBadge

                    VStack(alignment: .leading, spacing: 9) {
                        Text(item.correctedText)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(DesignSystem.ColorToken.primaryText)
                            .lineLimit(2)
                            .lineSpacing(3)
                            .frame(maxWidth: DesignSystem.Layout.transcriptMeasure, alignment: .leading)
                        metadataRow
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            quickActions
                .padding(.top, 1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private var dateBadge: some View {
        VStack(spacing: 2) {
            Text(item.timestamp.formatted(.dateTime.day()))
                .font(.system(size: 21, weight: .semibold, design: .serif))
                .foregroundStyle(DesignSystem.ColorToken.primaryText)
            Text(item.timestamp.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                .kerning(0.4)
        }
        .frame(width: 44)
        .padding(.top, 2)
        .accessibilityHidden(true)
    }

    private var metadataRow: some View {
        HStack(spacing: 12) {
            metadataLabel("clock", item.timestamp.formatted(date: .omitted, time: .shortened))
            metadataLabel("text.alignleft", "\(wordCount) words")
            metadataLabel("waveform", formatDuration(item.duration))
            InsertionBadge(result: item.insertionResult)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DesignSystem.ColorToken.amberIndex)
                    .accessibilityLabel(String(localized: "history.pinned"))
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: 5) {
            hoverActions
                .opacity(isHovering || isExpanded ? 1 : 0)
                .allowsHitTesting(isHovering || isExpanded)

            Button(action: toggleExpanded) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            }
            .buttonStyle(HistoryIconButtonStyle(tint: DesignSystem.ColorToken.secondaryText))
            .accessibilityLabel(isExpanded ? Copy.collapse : Copy.expand)
        }
    }

    private var hoverActions: some View {
        HStack(spacing: 5) {
            Button { onCopy() } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(HistoryIconButtonStyle())
            .accessibilityLabel(Copy.copyText)

            Button { showDeleteConfirmation = true } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(HistoryIconButtonStyle(tint: DesignSystem.ColorToken.failure))
            .accessibilityLabel(Copy.delete)
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider().overlay(DesignSystem.ColorToken.border)

            Text(item.correctedText)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(DesignSystem.ColorToken.primaryText)
                .textSelection(.enabled)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !item.correctionAudit.isEmpty {
                auditSection
            }

            actionRow
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    private var auditSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 10, weight: .semibold))
                Text(String.localizedStringWithFormat(String(localized: "history.correctionCount"), item.correctionAudit.count))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(DesignSystem.ColorToken.mossIndex)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(item.correctionAudit) { audit in
                    HStack(spacing: 7) {
                        Text(audit.heard)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .semibold))
                        Text(audit.written)
                            .foregroundStyle(DesignSystem.ColorToken.primaryText)
                        Spacer(minLength: 8)
                        Button(String(localized: "dictionary.learn")) { onLearnCorrection(audit) }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(DesignSystem.ColorToken.action)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(DesignSystem.ColorToken.action.opacity(0.09), in: Capsule())
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                }
            }
        }
        .padding(12)
        .background(DesignSystem.ColorToken.background.opacity(0.55), in: RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusField))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusField)
                .stroke(DesignSystem.ColorToken.border, lineWidth: DesignSystem.Layout.hairline)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button { onCopy() } label: {
                Label(Copy.copyText, systemImage: "doc.on.doc")
            }
            .buttonStyle(HistoryActionButtonStyle(tint: DesignSystem.ColorToken.action))

            Button { onTogglePin() } label: {
                Label(item.isPinned ? String(localized: "history.unpin") : String(localized: "history.pin"),
                      systemImage: item.isPinned ? "pin.slash" : "pin")
            }
            .buttonStyle(HistoryActionButtonStyle())

            if item.insertionResult.canRetryInsertion {
                Button { onRetryInsertion() } label: {
                    Label(Copy.retryInsertion, systemImage: "arrow.uturn.forward")
                }
                .buttonStyle(HistoryActionButtonStyle())
            }

            Spacer(minLength: 0)

            Button(role: .destructive) { showDeleteConfirmation = true } label: {
                Label(Copy.delete, systemImage: "trash")
            }
            .buttonStyle(HistoryActionButtonStyle(tint: DesignSystem.ColorToken.failure))
        }
    }

    private func metadataLabel(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(DesignSystem.ColorToken.secondaryText)
    }

    private var wordCount: Int {
        item.correctedText.split(whereSeparator: { $0.isWhitespace }).count
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(duration) / 60, Int(duration) % 60)
    }

    private func toggleExpanded() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            isExpanded.toggle()
        }
    }
}

private struct InsertionBadge: View {
    let result: InsertionResult

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(result.badgeColor)
                .frame(width: 5, height: 5)
            Text(result.badgeText)
        }
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundStyle(result.badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(result.badgeColor.opacity(0.11), in: Capsule())
        .overlay {
            Capsule().stroke(result.badgeColor.opacity(0.28), lineWidth: DesignSystem.Layout.hairline)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(result.detailText)
    }
}

private extension InsertionResult {
    var badgeText: String {
        switch self {
        case .inserted, .insertedViaAccessibility, .insertedViaPaste: return String(localized: "history.badge.inserted")
        case .copiedOnly, .copiedForRecovery: return String(localized: "history.badge.copied")
        case .noTarget: return String(localized: "history.badge.noTarget")
        case .permissionMissing, .deliveryFailed, .failed: return String(localized: "history.badge.failed")
        case .notRequested: return String(localized: "history.notInserted")
        }
    }

    var detailText: String {
        switch self {
        case .inserted, .insertedViaAccessibility, .insertedViaPaste: return String(localized: "history.inserted")
        case .copiedOnly, .copiedForRecovery: return String(localized: "history.copyRecovery")
        case .noTarget: return String(localized: "history.noTarget")
        case .permissionMissing: return String(localized: "history.accessibilityRequired")
        case .deliveryFailed, .failed: return String(localized: "history.deliveryFailed")
        case .notRequested: return String(localized: "history.notInserted")
        }
    }

    var badgeColor: Color {
        switch self {
        case .inserted, .insertedViaAccessibility, .insertedViaPaste: return DesignSystem.ColorToken.mossIndex
        case .copiedOnly, .copiedForRecovery: return DesignSystem.ColorToken.amberIndex
        case .noTarget, .permissionMissing, .deliveryFailed, .failed: return DesignSystem.ColorToken.coralIndex
        case .notRequested: return DesignSystem.ColorToken.secondaryText
        }
    }

    var canRetryInsertion: Bool {
        self != .insertedViaAccessibility && self != .insertedViaPaste
    }
}

private struct HistoryIconButtonStyle: ButtonStyle {
    var tint: Color = DesignSystem.ColorToken.secondaryText

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 24, height: 24)
            .background(DesignSystem.ColorToken.raisedSurface, in: Circle())
            .overlay {
                Circle().stroke(DesignSystem.ColorToken.border, lineWidth: DesignSystem.Layout.hairline)
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(response: DesignSystem.Motion.feedback, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private struct HistoryActionButtonStyle: ButtonStyle {
    var tint: Color = DesignSystem.ColorToken.primaryText

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(DesignSystem.ColorToken.raisedSurface, in: Capsule())
            .overlay { Capsule().stroke(DesignSystem.ColorToken.border, lineWidth: DesignSystem.Layout.hairline) }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(response: DesignSystem.Motion.feedback, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private struct CobaltCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(isEnabled ? DesignSystem.ColorToken.inverseText : DesignSystem.ColorToken.disabledText)
            .padding(.horizontal, 22)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(isEnabled ? DesignSystem.ColorToken.action : DesignSystem.ColorToken.border.opacity(0.55))
            )
            .overlay {
                Capsule().stroke(isEnabled ? DesignSystem.ColorToken.action.opacity(0.35) : .clear, lineWidth: DesignSystem.Layout.hairline)
            }
            .shadow(
                color: isEnabled ? DesignSystem.ColorToken.action.opacity(isHovering ? 0.3 : 0.14) : .clear,
                radius: isHovering ? 12 : 7,
                y: 4
            )
            .scaleEffect(configuration.isPressed ? 0.96 : isHovering ? 1.03 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: DesignSystem.Motion.feedback, dampingFraction: 0.65), value: isHovering)
            .animation(.spring(response: DesignSystem.Motion.feedback, dampingFraction: 0.65), value: configuration.isPressed)
            .onHover { hovering in isHovering = hovering }
    }
}

private struct SignalLevelBars: View {
    let level: Double
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.06)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate * 7.5
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<10, id: \.self) { index in
                    let motion = 0.35 + 0.65 * abs(sin(phase + Double(index) * 0.82))
                    let envelope = max(0.08, level)
                    Capsule()
                        .fill(color.opacity(0.52 + envelope * 0.48))
                        .frame(width: 2, height: max(3, CGFloat(5 + 18 * envelope * motion)))
                }
            }
            .frame(height: 24)
        }
        .accessibilityHidden(true)
    }
}

private struct ProcessingDots: View {
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { _ in
                Circle().fill(DesignSystem.ColorToken.action).frame(width: 4, height: 4)
            }
        }
        .accessibilityHidden(true)
    }
}
