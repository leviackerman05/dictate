import AppKit
import DictateCore
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Dictate's compact Color Index dropdown, shared by Settings and model
/// selection instead of inheriting the platform menu-picker appearance.
struct DictateDropdown<Item: Hashable & Identifiable>: View {
    @Binding var selection: Item
    let items: [Item]
    let title: (Item) -> String
    var detail: ((Item) -> String)? = nil
    var width: CGFloat? = nil
    var accessibilityLabel: String? = nil
    @State private var isExpanded = false

    private var triggerHeight: CGFloat { detail == nil ? 34 : 44 }
    private var resolvedWidth: CGFloat { width ?? 220 }
    private var menuHeight: CGFloat { min(CGFloat(items.count) * 36 + 8, 296) }

    var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(selection))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    if let detail {
                        Text(detail(selection))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 12)
            .frame(width: resolvedWidth, height: triggerHeight, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .background(DesignSystem.ColorToken.raisedSurface, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isExpanded ? DesignSystem.ColorToken.focusRing : DesignSystem.ColorToken.border,
                    lineWidth: isExpanded ? 1.5 : DesignSystem.Layout.hairline
                )
        }
        .frame(width: resolvedWidth, height: triggerHeight)
        // A popover owns a separate AppKit surface, so the option list cannot
        // be clipped by the settings card or painted underneath the recording
        // behavior row. Its contents remain fully custom and theme-matched.
        .popover(isPresented: $isExpanded, arrowEdge: .top) {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(items) { item in
                        DictateDropdownRow(
                            title: title(item),
                            isSelected: item == selection
                        ) {
                            selection = item
                            isExpanded = false
                        }
                    }
                }
                .padding(4)
            }
            .scrollIndicators(items.count > 8 ? .visible : .hidden)
            .frame(width: resolvedWidth, height: menuHeight)
            .background(DesignSystem.ColorToken.surface)
            .onExitCommand { isExpanded = false }
        }
        .accessibilityLabel(accessibilityLabel ?? title(selection))
        .accessibilityValue(title(selection))
        .accessibilityAddTraits(isExpanded ? .isSelected : [])
    }
}

private struct DictateDropdownRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DesignSystem.ColorToken.action)
                    .opacity(isSelected ? 1 : 0)
            }
            .foregroundStyle(DesignSystem.ColorToken.primaryText)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(
                isSelected
                    ? DesignSystem.ColorToken.action.opacity(0.12)
                    : isHovered ? DesignSystem.ColorToken.raisedSurface : .clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct DictateSidebar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { model.section = .dashboard } label: {
                HStack(spacing: 11) {
                    BrandMark(size: 34)
                    Text(Copy.appName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignSystem.ColorToken.primaryText)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 30)

            Text(String(localized: "navigation.workspace"))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            VStack(spacing: 4) {
                ForEach(AppSection.allCases) { section in
                    SidebarNavigationButton(
                        section: section,
                        isSelected: model.section == section
                    ) { model.section = section }
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            HStack(spacing: 9) {
                Circle()
                    .fill(sidebarStatusColor)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(sidebarStatusTitle)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Text(String(localized: "navigation.localOnly"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                }
                Spacer()
            }
            .foregroundStyle(DesignSystem.ColorToken.primaryText)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: DesignSystem.Layout.sidebarWidth)
        .background(DesignSystem.ColorToken.sidebarBackground)
    }

    private var sidebarStatusTitle: String {
        guard model.dictation.state == .idle else {
            return AccessibilitySupport.status(for: model.dictation.state)
        }
        switch model.dictation.readiness {
        case .settingUp: return String(localized: "navigation.settingUp")
        case .modelLoaded:
            return String.localizedStringWithFormat(
                String(localized: "recording.modelLoaded"),
                model.transcriptionProvider.readinessTitle
            )
        case .ready: return String(localized: "navigation.ready")
        case .unavailable: return String(localized: "navigation.setupFailed")
        }
    }

    private var sidebarStatusColor: Color {
        if model.dictation.state != .idle { return DesignSystem.ColorToken.listening }
        switch model.dictation.readiness {
        case .settingUp: return DesignSystem.ColorToken.action
        case .modelLoaded: return DesignSystem.ColorToken.success
        case .ready: return DesignSystem.ColorToken.success
        case .unavailable: return DesignSystem.ColorToken.failure
        }
    }
}

private struct SidebarNavigationButton: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 20)
                Text(section.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                Spacer()
            }
            .foregroundStyle(isSelected ? DesignSystem.ColorToken.primaryText : DesignSystem.ColorToken.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected ? DesignSystem.ColorToken.sidebarSelection : hovering ? DesignSystem.ColorToken.raisedSurface : .clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct DashboardView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var dictation: DictationController

    init(model: AppModel) {
        self.model = model
        _dictation = ObservedObject(wrappedValue: model.dictation)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    eyebrow: String(localized: "dashboard.eyebrow"),
                    title: String(localized: "dashboard.title"),
                    subtitle: String(localized: "dashboard.subtitle")
                ) {
                    HStack(spacing: 10) {
                        DashboardModelStatusButton(
                            provider: model.transcriptionProvider,
                            readiness: dictation.readiness
                        ) {
                            model.section = .aiModels
                        }

                        DashboardRecordButton(
                            isRecording: isRecording,
                            isEnabled: isRecording || dictation.readiness == .ready
                        ) {
                            if isRecording {
                                model.finishRecording()
                            } else {
                                model.startRecording()
                            }
                        }
                    }
                }

                VStack(spacing: 16) {
                    DashboardOverviewCard(model: model)

                    LazyVGrid(columns: dashboardColumns, alignment: .leading, spacing: 16) {
                        QuickActionsCard(model: model)
                        RecentTranscriptionsCard(model: model)
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 1180, alignment: .leading)
        }
        .background(DesignSystem.ColorToken.background)
    }

    private var dashboardColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 240), spacing: 16, alignment: .top),
            GridItem(.flexible(minimum: 240), spacing: 16, alignment: .top)
        ]
    }

    private var isRecording: Bool {
        switch dictation.state {
        case .idle, .failed: return false
        default: return true
        }
    }
}

private struct DashboardModelStatusButton: View {
    let provider: TranscriptionProvider
    let readiness: DictationReadiness
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                readinessMark
                    .frame(width: 15, height: 15)

                VStack(alignment: .leading, spacing: 1) {
                    Text(provider.title)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(DesignSystem.ColorToken.primaryText)
                        .lineLimit(1)
                    Text(statusTitle)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 2)

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
            }
            .padding(.horizontal, 11)
            .frame(width: 232, height: 38)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(hovering ? DesignSystem.ColorToken.raisedSurface : DesignSystem.ColorToken.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(hovering ? DesignSystem.ColorToken.action.opacity(0.55) : DesignSystem.ColorToken.border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(String(localized: "dashboard.model.open"))
        .accessibilityLabel("\(provider.title), \(statusTitle)")
        .accessibilityHint(String(localized: "dashboard.model.open"))
    }

    @ViewBuilder
    private var readinessMark: some View {
        switch readiness {
        case .settingUp:
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.72)
        case .modelLoaded:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignSystem.ColorToken.success)
        case .ready:
            Circle()
                .fill(DesignSystem.ColorToken.success)
                .frame(width: 7, height: 7)
        case .unavailable:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignSystem.ColorToken.failure)
        }
    }

    private var statusTitle: String {
        switch readiness {
        case .settingUp: return String(localized: "dashboard.model.settingUp")
        case .modelLoaded: return String(localized: "dashboard.model.loaded")
        case .ready: return String(localized: "dashboard.model.ready")
        case .unavailable: return String(localized: "dashboard.model.unavailable")
        }
    }

    private var statusColor: Color {
        switch readiness {
        case .settingUp: return DesignSystem.ColorToken.action
        case .modelLoaded, .ready: return DesignSystem.ColorToken.success
        case .unavailable: return DesignSystem.ColorToken.failure
        }
    }
}

/// The dashboard's start/stop control. Deliberately not an Apple default
/// button: a tall cobalt capsule with an inner top highlight, a soft cobalt
/// glow, hover lift, and — while a session is running — a pulsing white dot
/// and a coral stop affordance.
private struct DashboardRecordButton: View {
    let isRecording: Bool
    let isEnabled: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if isRecording {
                    PulsingRecordingDot()
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(isRecording ? Copy.stopRecording : Copy.startRecording)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(DesignSystem.ColorToken.inverseText)
            .padding(.horizontal, 20)
            .frame(height: 38)
            .background {
                Capsule().fill(isRecording ? DesignSystem.ColorToken.failure : DesignSystem.ColorToken.action)
                Capsule().fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .overlay {
                Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.38), radius: 10, y: 4)
        }
        .disabled(!isEnabled)
        .buttonStyle(DashboardRecordButtonStyle(hovering: $hovering))
        .onHover { hovering = isEnabled && $0 }
        .opacity(isEnabled ? 1 : 0.48)
        .animation(.spring(duration: DesignSystem.Motion.stateMorph, bounce: 0.18), value: isRecording)
        .animation(.easeOut(duration: DesignSystem.Motion.directFeedback), value: isEnabled)
        .accessibilityLabel(isRecording ? Copy.stopRecording : Copy.startRecording)
    }

    private var tint: Color {
        isRecording ? DesignSystem.ColorToken.failure : DesignSystem.ColorToken.action
    }
}

private struct DashboardRecordButtonStyle: ButtonStyle {
    @Binding var hovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : hovering ? 1.02 : 1)
            .brightness(hovering && !configuration.isPressed ? 0.05 : 0)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(duration: DesignSystem.Motion.feedback, bounce: 0.3), value: configuration.isPressed)
            .animation(.spring(duration: DesignSystem.Motion.feedback, bounce: 0.3), value: hovering)
    }
}

private struct PulsingRecordingDot: View {
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 9, height: 9)
                .scaleEffect(pulsing ? 1.8 : 0.5)
                .opacity(pulsing ? 0 : 0.85)
            Circle()
                .fill(Color.white)
                .frame(width: 7, height: 7)
        }
        .frame(width: 14, height: 14)
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}

struct TranscribeAudioView: View {
    @ObservedObject var model: AppModel
    @State private var audioURL: URL?
    @State private var transcript = ""
    @State private var isTranscribing = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    eyebrow: String(localized: "transcribe.eyebrow"),
                    title: String(localized: "transcribe.title"),
                    subtitle: String(localized: "transcribe.subtitle")
                )

                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Image(systemName: "waveform.badge.plus")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(DesignSystem.ColorToken.accentViolet)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(audioURL?.lastPathComponent ?? String(localized: "transcribe.chooseTitle"))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            Text(audioURL == nil ? String(localized: "transcribe.chooseDetail") : String(localized: "transcribe.readyDetail"))
                                .font(.system(size: 12))
                                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                        }
                        Spacer()
                        Button(String(localized: "transcribe.chooseButton")) { chooseAudioFile() }
                            .buttonStyle(.borderedProminent)
                            .tint(DesignSystem.ColorToken.accentViolet)
                    }

                    if let audioURL {
                        HStack(spacing: 10) {
                            Button(isTranscribing ? String(localized: "transcribe.transcribing") : String(localized: "transcribe.transcribeButton")) {
                                transcribe(audioURL)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isTranscribing)
                            if isTranscribing { ProgressView().controlSize(.small) }
                            Spacer()
                            Text(model.transcriptionProvider.title)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                        }
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DesignSystem.ColorToken.failure)
                    }
                }
                .padding(24)
                .dsCard()

                if !transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: String(localized: "transcribe.resultTitle"), subtitle: String(localized: "transcribe.resultSubtitle"))
                        Text(transcript)
                            .font(.system(size: 16, design: .rounded))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
                            .padding(16)
                            .background(DesignSystem.ColorToken.raisedSurface, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(20)
                    .dsCard()
                }
            }
            .padding(32)
            .frame(maxWidth: 1180, alignment: .leading)
        }
        .background(DesignSystem.ColorToken.background)
    }

    private func chooseAudioFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        audioURL = url
        transcript = ""
        errorMessage = ""
    }

    private func transcribe(_ url: URL) {
        isTranscribing = true
        errorMessage = ""
        Task { @MainActor in
            defer { isTranscribing = false }
            do {
                transcript = try await model.dictation.transcribeAudioFile(at: url, entries: model.dictionary)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct StatisticsView: View {
    @ObservedObject var model: AppModel
    @State private var range: StatisticsRange = .week

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    eyebrow: String(localized: "statistics.eyebrow"),
                    title: String(localized: "statistics.title"),
                    subtitle: String(localized: "statistics.subtitle")
                ) {
                    RangeSelector(selection: $range)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 14)], spacing: 14) {
                    MetricCard(eyebrow: String(localized: "statistics.totalWords"), value: "\(model.totalWordCount)", label: String(localized: "statistics.allTime"), icon: "text.word.spacing", tint: DesignSystem.ColorToken.accentViolet)
                    MetricCard(eyebrow: String(localized: "statistics.sessions"), value: "\(model.history.count)", label: String(localized: "statistics.transcriptions"), icon: "doc.text", tint: DesignSystem.ColorToken.accentBlue)
                    MetricCard(eyebrow: String(localized: "statistics.average"), value: averageWords, label: String(localized: "statistics.wordsPerSession"), icon: "chart.line.uptrend.xyaxis", tint: DesignSystem.ColorToken.success)
                    MetricCard(eyebrow: String(localized: "statistics.time"), value: formattedDuration(model.totalDuration), label: String(localized: "statistics.listeningTime"), icon: "timer", tint: DesignSystem.ColorToken.amberIndex)
                }

                VStack(alignment: .leading, spacing: 16) {
                    SectionHeading(title: String(localized: "statistics.activity"), subtitle: String(localized: "statistics.activitySubtitle"))
                    WeeklyBars(values: dailyWordCounts, labels: dayLabels)
                        .frame(height: 220)
                }
                .padding(22)
                .dsCard()
            }
            .padding(32)
            .frame(maxWidth: 1180, alignment: .leading)
        }
        .background(DesignSystem.ColorToken.background)
    }

    private var averageWords: String {
        guard !model.history.isEmpty else { return "0" }
        return "\(model.totalWordCount / model.history.count)"
    }

    private var dayLabels: [String] {
        let calendar = Calendar.current
        return (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: .now)?.formatted(.dateTime.weekday(.narrow))
        }
    }

    private var dailyWordCounts: [Int] {
        let calendar = Calendar.current
        let dates = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: .now) }
        return dates.map { date in
            model.history.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }.reduce(0) { total, item in
                total + item.correctedText.split { $0.isWhitespace || $0.isNewline }.count
            }
        }
    }
}

private enum StatisticsRange: String, CaseIterable, Identifiable {
    case week, month, year
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

private struct RangeSelector: View {
    @Binding var selection: StatisticsRange

    var body: some View {
        HStack(spacing: 3) {
            ForEach(StatisticsRange.allCases) { range in
                Button(range.title) { selection = range }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(selection == range ? DesignSystem.ColorToken.primaryText : DesignSystem.ColorToken.secondaryText)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(selection == range ? DesignSystem.ColorToken.action.opacity(0.16) : .clear, in: Capsule())
            }
        }
        .padding(3)
        .background(DesignSystem.ColorToken.raisedSurface, in: Capsule())
        .overlay { Capsule().stroke(DesignSystem.ColorToken.border) }
    }
}

struct AIModelsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var dictation: DictationController

    init(model: AppModel) {
        self.model = model
        _dictation = ObservedObject(wrappedValue: model.dictation)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    eyebrow: String(localized: "models.eyebrow"),
                    title: String(localized: "models.title"),
                    subtitle: String(localized: "models.subtitle")
                )

                currentModelStrip

                heroCard

                catalogSection
            }
            .padding(32)
            .frame(maxWidth: 1180, alignment: .leading)
        }
        .background(DesignSystem.ColorToken.background)
        .onAppear { dictation.refreshModelStatuses() }
    }

    // MARK: Current model strip

    private var currentModelStrip: some View {
        let provider = model.transcriptionProvider
        let status = provider == .apple ? .ready : dictation.modelStatus(for: provider)
        return HStack(spacing: 13) {
            Image(systemName: "waveform")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignSystem.ColorToken.action)
                .frame(width: 42, height: 42)
                .background(DesignSystem.ColorToken.action.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "models.currentlyUsing").uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                HStack(spacing: 8) {
                    Text(provider.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignSystem.ColorToken.primaryText)
                    EngineBadge(engine: provider.engineTitle)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                Circle()
                    .fill(status == .ready ? DesignSystem.ColorToken.success : DesignSystem.ColorToken.warning)
                    .frame(width: 6, height: 6)
                Text(status == .ready ? String(localized: "models.active") : String(localized: "common.notInstalled"))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(DesignSystem.ColorToken.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.ColorToken.border.opacity(0.6), lineWidth: DesignSystem.Layout.hairline)
        }
    }

    // MARK: Hero (recommended model)

    private var heroCard: some View {
        let provider = TranscriptionProvider.parakeet
        let status = dictation.modelStatus(for: provider)
        let isSelected = model.transcriptionProvider == provider
        return HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                    Text(String(localized: "models.recommended").uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                }
                .foregroundStyle(DesignSystem.ColorToken.action)

                Text(provider.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignSystem.ColorToken.primaryText)
                    .padding(.top, 14)

                HStack(spacing: 8) {
                    LanguageBadge(isEnglishOnly: provider.isEnglishOnly)
                    ModelSizeChip(size: provider.sizeDescription)
                }
                .padding(.top, 10)

                Text(provider.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                Spacer(minLength: 18)

                heroAction(provider: provider, status: status, isSelected: isSelected)
                    .padding(.top, 18)
            }

            VStack(alignment: .leading, spacing: 14) {
                Text(String(localized: "models.performance").uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                ScoreMeter(label: String(localized: "models.speed"), score: provider.speedScore, tint: DesignSystem.ColorToken.action)
                ScoreMeter(label: String(localized: "models.accuracy"), score: provider.accuracyScore, tint: DesignSystem.ColorToken.action)
            }
            .padding(18)
            .frame(width: 300, alignment: .leading)
            .background(DesignSystem.ColorToken.primaryText.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(DesignSystem.ColorToken.primaryText.opacity(0.08), lineWidth: 1)
            }
        }
        .padding(28)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DesignSystem.ColorToken.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.ColorToken.action.opacity(0.08), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DesignSystem.ColorToken.action.opacity(0.25), lineWidth: 1)
        }
        .shadow(color: DesignSystem.ColorToken.action.opacity(0.10), radius: 20, y: 8)
    }

    @ViewBuilder
    private func heroAction(provider: TranscriptionProvider, status: RecognitionModelStatus, isSelected: Bool) -> some View {
        switch status {
        case .notInstalled, .failed:
            Button {
                dictation.prepareModel(for: provider)
            } label: {
                HStack(spacing: 7) {
                    Text(status == .failed ? String(localized: "settings.parakeetRetry") : String(localized: "models.download"))
                    Image(systemName: status == .failed ? "arrow.clockwise" : "arrow.down")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .buttonStyle(ModelActionButtonStyle(prominent: true, large: true))
        case .downloading(let progress):
            ModelDownloadProgress(progress: progress)
        case .validating, .loading:
            HStack(spacing: 9) {
                ProgressView()
                    .controlSize(.small)
                    .tint(DesignSystem.ColorToken.action)
                Text(String(localized: "models.preparing"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(DesignSystem.ColorToken.raisedSurface, in: Capsule())
            .overlay { Capsule().stroke(DesignSystem.ColorToken.border, lineWidth: DesignSystem.Layout.hairline) }
        case .ready:
            if isSelected {
                ActiveBadge(large: true)
            } else {
                Button {
                    model.transcriptionProvider = provider
                } label: {
                    HStack(spacing: 7) {
                        Text(String(localized: "models.useModel"))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                .buttonStyle(ModelActionButtonStyle(prominent: true, large: true))
            }
        }
    }

    // MARK: Catalog

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionHeading(title: String(localized: "models.catalog"), subtitle: String(localized: "models.catalogSubtitle"))

            engineGroup(title: String(localized: "models.group.parakeet"), providers: parakeetProviders)

            engineGroup(title: String(localized: "models.group.whisper"), providers: whisperProviders)

            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "models.builtIn"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                ModelCatalogCard(model: model, provider: .apple, allowsRemoval: false)
            }
        }
        .padding(22)
        .dsCard()
    }

    private func engineGroup(title: String, providers: [TranscriptionProvider]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(DesignSystem.ColorToken.primaryText)
            ForEach(providers) { provider in
                ModelCatalogCard(model: model, provider: provider)
            }
        }
    }

    private var parakeetProviders: [TranscriptionProvider] { [.parakeet, .parakeetV2, .parakeet110m] }

    private var whisperProviders: [TranscriptionProvider] {
        [.whisperTiny, .whisperBase, .whisperSmall, .whisperMedium, .whisperLargeV3Turbo]
    }
}

private struct PageHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing

    init(eyebrow: String, title: String, subtitle: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(DesignSystem.ColorToken.accentViolet)
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(DesignSystem.ColorToken.primaryText)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
            }
            Spacer()
            trailing()
        }
    }
}

private struct SectionHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
        }
    }
}

private struct MetricCard: View {
    let eyebrow: String
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
            Text(eyebrow.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .dsCard()
    }
}

private struct DashboardOverviewCard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(alignment: .center, spacing: 36) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "dashboard.thisWeek"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                Text("\(model.thisWeekWordCount)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignSystem.ColorToken.primaryText)
                Text(String(localized: "dashboard.wordsDictated"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
            }
            .frame(width: 180, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "dashboard.weekActivity"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(String(localized: "dashboard.weekActivitySubtitle"))
                    .font(.system(size: 11))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                WeeklyLineChart(values: values, labels: labels)
                    .frame(maxWidth: .infinity, minHeight: 126)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .leading)
        .dsCard()
    }

    private var labels: [String] {
        (0..<7).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: .now)?.formatted(.dateTime.weekday(.narrow)) }
    }

    private var values: [Int] {
        let calendar = Calendar.current
        return (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { return nil }
            return model.history.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }.reduce(0) { $0 + $1.correctedText.split { $0.isWhitespace || $0.isNewline }.count }
        }
    }
}

private struct QuickActionsCard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeading(title: String(localized: "dashboard.quickActions"), subtitle: String(localized: "dashboard.quickActionsSubtitle"))
            QuickActionButton(title: String(localized: "dashboard.openHistory"), detail: String(localized: "dashboard.openHistoryDetail"), icon: "clock.arrow.circlepath") { model.section = .history }
            QuickActionButton(title: String(localized: "dashboard.manageDictionary"), detail: String(localized: "dashboard.manageDictionaryDetail"), icon: "character.book.closed") { model.section = .dictionary }
            QuickActionButton(title: String(localized: "dashboard.chooseModel"), detail: String(localized: "dashboard.chooseModelDetail"), icon: "cpu") { model.section = .aiModels }
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
        .dsCard()
    }
}

private struct WeeklyLineChart: View {
    let values: [Int]
    let labels: [String]

    var body: some View {
        GeometryReader { geometry in
            let maxValue = max(values.max() ?? 1, 1)
            let points = values.enumerated().map { index, value in
                CGPoint(
                    x: values.count > 1 ? geometry.size.width * CGFloat(index) / CGFloat(values.count - 1) : geometry.size.width / 2,
                    y: geometry.size.height - 26 - (geometry.size.height - 42) * CGFloat(value) / CGFloat(maxValue)
                )
            }
            ZStack(alignment: .bottom) {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                }
                .stroke(DesignSystem.ColorToken.action, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(DesignSystem.ColorToken.cardBackground)
                        .overlay { Circle().stroke(DesignSystem.ColorToken.action, lineWidth: 2) }
                        .frame(width: 7, height: 7)
                        .position(point)
                }

                HStack {
                    ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                        Text(label)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct WeeklyBars: View {
    let values: [Int]
    let labels: [String]
    @State private var hoveredIndex: Int?

    var body: some View {
        GeometryReader { geometry in
            let maxValue = max(values.max() ?? 1, 1)
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    VStack(spacing: 7) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 5)
                            .fill(index == values.count - 1 ? DesignSystem.ColorToken.accentViolet : DesignSystem.ColorToken.accentBlue.opacity(0.72))
                            .frame(height: max(8, (geometry.size.height - 25) * CGFloat(value) / CGFloat(maxValue)))
                            .overlay(alignment: .top) {
                                if hoveredIndex == index {
                                    Text("\(value) words")
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundStyle(DesignSystem.ColorToken.primaryText)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(DesignSystem.ColorToken.cardBackground, in: Capsule())
                                        .overlay { Capsule().stroke(DesignSystem.ColorToken.border) }
                                        .fixedSize()
                                        .offset(y: -32)
                                        .allowsHitTesting(false)
                                }
                            }
                            .zIndex(hoveredIndex == index ? 2 : 0)
                        .onHover { isHovering in
                            hoveredIndex = isHovering ? index : nil
                        }
                        Text(labels.indices.contains(index) ? labels[index] : "")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct QuickActionButton: View {
    let title: String
    let detail: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .foregroundStyle(DesignSystem.ColorToken.accentViolet)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 12, weight: .semibold, design: .rounded))
                    Text(detail).font(.system(size: 10)).foregroundStyle(DesignSystem.ColorToken.secondaryText)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(DesignSystem.ColorToken.primaryText)
    }
}

private struct RecentTranscriptionsCard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                SectionHeading(title: String(localized: "dashboard.recent"), subtitle: String(localized: "dashboard.recentSubtitle"))
                Spacer()
                Button(String(localized: "dashboard.viewAll")) { model.section = .history }
                    .buttonStyle(.link)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            if model.history.isEmpty {
                Text(Copy.noHistoryDetail)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                    .padding(.vertical, 18)
            } else {
                ForEach(Array(model.history.prefix(3))) { item in
                    DashboardHistoryRow(item: item)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .leading)
        .dsCard()
    }
}

private struct DashboardHistoryRow: View {
    let item: HistoryItem

    var body: some View {
        HStack(spacing: 11) {
            Circle()
                .fill(DesignSystem.ColorToken.accentBlue)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.correctedText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(1)
                Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
            }
            Spacer()
            Text(formattedDuration(item.duration))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
        }
        .padding(.vertical, 6)
    }
}

private struct ModelCatalogCard: View {
    @ObservedObject var model: AppModel
    let provider: TranscriptionProvider
    var allowsRemoval: Bool = true
    @State private var hovering = false

    var body: some View {
        let status = resolvedStatus
        let isSelected = model.transcriptionProvider == provider
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(engineTint)
                .frame(width: 38, height: 38)
                .background(engineTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 9) {
                    Text(provider.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(DesignSystem.ColorToken.primaryText)
                    LanguageBadge(isEnglishOnly: provider.isEnglishOnly)
                }
                Text(provider.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    ModelSizeChip(size: provider.sizeDescription)
                }
                HStack(spacing: 24) {
                    ScoreMeter(label: String(localized: "models.speed"), score: provider.speedScore, tint: engineTint, compact: true)
                        .frame(width: 116)
                    ScoreMeter(label: String(localized: "models.accuracy"), score: provider.accuracyScore, tint: engineTint, compact: true)
                        .frame(width: 116)
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 10) {
                ModelStatusBadge(status: status)
                actions(status: status, isSelected: isSelected)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? DesignSystem.ColorToken.action.opacity(0.06) : DesignSystem.ColorToken.cardBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected ? DesignSystem.ColorToken.action.opacity(0.4) : DesignSystem.ColorToken.border.opacity(hovering ? 1 : 0.5),
                    lineWidth: isSelected ? 1.5 : DesignSystem.Layout.hairline
                )
        }
        .shadow(color: .black.opacity(hovering ? 0.08 : 0.03), radius: hovering ? 12 : 6, y: hovering ? 5 : 2)
        .animation(.easeOut(duration: DesignSystem.Motion.feedback), value: hovering)
        .animation(.easeOut(duration: DesignSystem.Motion.feedback), value: isSelected)
        .onHover { hovering = $0 }
    }

    private var resolvedStatus: RecognitionModelStatus {
        provider == .apple ? .ready : model.dictation.modelStatus(for: provider)
    }

    private var iconName: String {
        switch provider.engineTitle {
        case "Apple": return "applelogo"
        case "Whisper": return "text.quote"
        default: return "waveform"
        }
    }

    private var engineTint: Color {
        switch provider.engineTitle {
        case "Apple": return DesignSystem.ColorToken.accentBlue
        case "Parakeet": return DesignSystem.ColorToken.mossIndex
        case "Whisper": return DesignSystem.ColorToken.amberIndex
        default: return DesignSystem.ColorToken.action
        }
    }

    @ViewBuilder
    private func actions(status: RecognitionModelStatus, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            switch status {
            case .notInstalled, .failed:
                Button {
                    model.dictation.prepareModel(for: provider)
                } label: {
                    Text(status == .failed ? String(localized: "settings.parakeetRetry") : String(localized: "models.download"))
                }
                .buttonStyle(ModelActionButtonStyle(prominent: true))
            case .downloading, .validating, .loading:
                Button(String(localized: "models.download")) {}
                    .buttonStyle(ModelActionButtonStyle(prominent: true))
                    .disabled(true)
            case .ready:
                if isSelected {
                    ActiveBadge()
                } else {
                    Button(String(localized: "models.useModel")) {
                        model.transcriptionProvider = provider
                    }
                    .buttonStyle(ModelActionButtonStyle(prominent: true))
                }
                if allowsRemoval {
                    Button {
                        model.dictation.removeModel(for: provider)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(ModelActionButtonStyle(destructive: true))
                    .help(String(localized: "settings.parakeetRemove"))
                }
            }
        }
    }
}

/// Custom capsule button for model actions. No `.bordered`/`.borderedProminent`.
private struct ModelActionButtonStyle: ButtonStyle {
    var prominent: Bool = false
    var destructive: Bool = false
    var large: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: large ? 13 : 11, weight: .semibold, design: .rounded))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, large ? 20 : 14)
            .padding(.vertical, large ? 11 : 8)
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

private struct EngineBadge: View {
    let engine: String

    var body: some View {
        Text(engine.uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14), in: Capsule())
    }

    private var tint: Color {
        switch engine {
        case "Apple": return DesignSystem.ColorToken.accentBlue
        case "Parakeet": return DesignSystem.ColorToken.mossIndex
        case "Whisper": return DesignSystem.ColorToken.amberIndex
        default: return DesignSystem.ColorToken.action
        }
    }
}

private struct LanguageBadge: View {
    let isEnglishOnly: Bool

    var body: some View {
        let tint = isEnglishOnly ? DesignSystem.ColorToken.secondaryText : DesignSystem.ColorToken.mossIndex
        Text(isEnglishOnly ? String(localized: "models.englishOnly") : String(localized: "models.multilingual"))
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.6)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }
}

private struct ModelSizeChip: View {
    let size: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "internaldrive")
                .font(.system(size: 10))
            Text(size)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(DesignSystem.ColorToken.secondaryText)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(DesignSystem.ColorToken.primaryText.opacity(0.05), in: Capsule())
    }
}

/// A 10-segment capsule meter for a 1–10 score. Segments read better than a
/// bare continuous bar and keep the palette doing the talking.
private struct ScoreMeter: View {
    let label: String
    let score: Double
    let tint: Color
    var compact: Bool = false

    private var filledSegments: Int {
        min(10, max(0, Int(score.rounded())))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: compact ? 8 : 9, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
            HStack(spacing: compact ? 2.5 : 3.5) {
                ForEach(0..<10, id: \.self) { index in
                    Capsule()
                        .fill(index < filledSegments ? tint : DesignSystem.ColorToken.border.opacity(0.55))
                        .frame(height: compact ? 4 : 6)
                }
            }
        }
    }
}

private struct ActiveBadge: View {
    var large: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: large ? 12 : 10, weight: .bold))
            Text(String(localized: "models.active"))
        }
        .font(.system(size: large ? 13 : 10, weight: .bold, design: .rounded))
        .foregroundStyle(DesignSystem.ColorToken.action)
        .padding(.horizontal, large ? 18 : 11)
        .padding(.vertical, large ? 11 : 7)
        .background(DesignSystem.ColorToken.action.opacity(0.14), in: Capsule())
    }
}

/// Hero download state: spinner, "Downloading…", live percent, and a capsule
/// progress bar, plus the first-download reassurance.
private struct ModelDownloadProgress: View {
    let progress: Double?

    var body: some View {
        let fraction = min(max(progress ?? 0, 0), 1)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                ProgressView()
                    .controlSize(.small)
                    .tint(DesignSystem.ColorToken.action)
                Text(String(localized: "common.downloading"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(DesignSystem.ColorToken.secondaryText)
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignSystem.ColorToken.action)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DesignSystem.ColorToken.border.opacity(0.55))
                        .frame(height: 6)
                    Capsule()
                        .fill(DesignSystem.ColorToken.action)
                        .frame(width: max(6, geo.size.width * fraction), height: 6)
                        .animation(.easeOut(duration: DesignSystem.Motion.feedback), value: fraction)
                }
            }
            .frame(width: 300, height: 6)
            Text(String(localized: "models.largeDownloadHint"))
                .font(.system(size: 11))
                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
        }
    }
}

struct ModelSelectorMenu: View {
    @Binding var selection: TranscriptionProvider

    var body: some View {
        DictateDropdown(
            selection: $selection,
            items: TranscriptionProvider.allCases,
            title: { $0.title },
            detail: { provider in
                provider == .apple ? String(localized: "models.builtIn") : provider.sizeDescription
            },
            width: 240,
            accessibilityLabel: String(localized: "settings.transcriptionModel")
        )
    }
}

private struct ModelStatusBadge: View {
    let status: RecognitionModelStatus

    var body: some View {
        HStack(spacing: 6) {
            if case .downloading(let progress) = status, let progress {
                DownloadProgressRing(progress: progress)
            } else if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .tint(DesignSystem.ColorToken.action)
            } else {
                Circle().fill(statusColor).frame(width: 7, height: 7)
            }
            Text(modelStatusLabel(status))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(DesignSystem.ColorToken.secondaryText)
        }
        .fixedSize()
    }

    private var isBusy: Bool {
        switch status {
        case .downloading, .validating, .loading: return true
        default: return false
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
}

private struct DownloadProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(DesignSystem.ColorToken.border, lineWidth: 2)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(DesignSystem.ColorToken.action, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((min(max(progress, 0), 1) * 100).rounded()))")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(DesignSystem.ColorToken.primaryText)
        }
        .frame(width: 24, height: 24)
        .accessibilityLabel(String.localizedStringWithFormat(String(localized: "models.downloadProgress"), Int((progress * 100).rounded())))
    }
}

private func modelStatusLabel(_ status: RecognitionModelStatus) -> String {
    switch status {
    case .notInstalled: return String(localized: "common.notInstalled")
    case .downloading: return String(localized: "common.downloading")
    case .validating: return String(localized: "common.validating")
    case .loading: return String(localized: "common.loading")
    case .ready: return String(localized: "common.ready")
    case .failed: return String(localized: "common.failed")
    }
}

private func formattedDuration(_ duration: TimeInterval) -> String {
    let seconds = max(0, Int(duration.rounded()))
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

private extension View {
    func dsCard() -> some View {
        background(DesignSystem.ColorToken.cardBackground, in: RoundedRectangle(cornerRadius: 15))
            .overlay { RoundedRectangle(cornerRadius: 15).stroke(DesignSystem.ColorToken.border, lineWidth: 1) }
    }
}
