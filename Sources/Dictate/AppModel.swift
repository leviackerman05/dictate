import AppKit
import DictateCore
import Foundation
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case history
    case dictionary
    case statistics
    case aiModels
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return String(localized: "navigation.dashboard")
        case .history: return Copy.history
        case .dictionary: return Copy.dictionary
        case .statistics: return String(localized: "navigation.statistics")
        case .aiModels: return String(localized: "navigation.aiModels")
        case .settings: return Copy.settings
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .history: return "clock.arrow.circlepath"
        case .dictionary: return "character.book.closed"
        case .statistics: return "chart.bar.xaxis"
        case .aiModels: return "cpu"
        case .settings: return "gearshape"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard: return String(localized: "navigation.dashboardSubtitle")
        case .history: return String(localized: "navigation.historySubtitle")
        case .dictionary: return String(localized: "navigation.dictionarySubtitle")
        case .statistics: return String(localized: "navigation.statisticsSubtitle")
        case .aiModels: return String(localized: "navigation.aiModelsSubtitle")
        case .settings: return String(localized: "navigation.settingsSubtitle")
        }
    }
}

enum RecordingMode: String, CaseIterable, Codable, Identifiable, Equatable {
    case holdToTalk
    case clickToToggle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .holdToTalk: return String(localized: "recording.mode.hold")
        case .clickToToggle: return String(localized: "recording.mode.toggle")
        }
    }

    var gestureMode: ShortcutGestureMode {
        switch self {
        case .holdToTalk: return .holdToTalk
        case .clickToToggle: return .clickToToggle
        }
    }
}

extension AppearancePreference {
    var title: String {
        switch self {
        case .system: return String(localized: "appearance.system")
        case .light: return String(localized: "appearance.light")
        case .dark: return String(localized: "appearance.dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var section: AppSection = .dashboard
    @Published var history: [HistoryItem] = []
    @Published var dictionary: [DictionaryEntry] = []
    @Published var historySearch = ""
    @Published var dictionarySearch = ""
    @Published var dictionaryFilter: DictionaryEntryKind? = nil
    @Published var dictionaryNotice = ""
    @Published var keepHistory: Bool {
        didSet { UserDefaults.standard.set(keepHistory, forKey: Keys.keepHistory) }
    }
    @Published var retention: HistoryRetention {
        didSet { UserDefaults.standard.set(retention.rawValue, forKey: Keys.retention) }
    }
    @Published var shortcut: ShortcutChoice {
        didSet { UserDefaults.standard.set(shortcut.rawValue, forKey: Keys.shortcut) }
    }
    @Published var customShortcut: RecordedShortcut? {
        didSet {
            if let customShortcut, let data = try? JSONEncoder().encode(customShortcut) {
                UserDefaults.standard.set(data, forKey: Keys.customShortcut)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.customShortcut)
            }
        }
    }
    @Published var onboardingDismissed: Bool {
        didSet { UserDefaults.standard.set(onboardingDismissed, forKey: Keys.onboardingDismissed) }
    }
    @Published var microphoneEnabled: Bool {
        didSet { UserDefaults.standard.set(microphoneEnabled, forKey: Keys.microphoneEnabled) }
    }
    @Published var recordingMode: RecordingMode {
        didSet { UserDefaults.standard.set(recordingMode.rawValue, forKey: Keys.recordingMode) }
    }
    @Published var appearance: AppearancePreference {
        didSet {
            appearanceStore.value = appearance
            applyAppearance()
        }
    }
    @Published var showReadyIndicator: Bool {
        didSet { UserDefaults.standard.set(showReadyIndicator, forKey: Keys.showReadyIndicator) }
    }
    @Published var transcriptionProvider: TranscriptionProvider {
        didSet {
            UserDefaults.standard.set(transcriptionProvider.rawValue, forKey: Keys.transcriptionProvider)
            dictation.selectProvider(transcriptionProvider)
        }
    }

    let dictation: DictationController
    let permissions: PermissionService
    private let historyStore: HistoryStore
    private let dictionaryStore: AtomicJSONStore<DictionaryDocument>
    private let appearanceStore: AppearancePreferenceStore

    private enum Keys {
        static let keepHistory = "keepHistory"
        static let retention = "retention"
        static let shortcut = "shortcut"
        static let customShortcut = "customShortcut"
        static let onboardingDismissed = "onboardingDismissed"
        static let microphoneEnabled = "microphoneEnabled"
        static let recordingMode = "recordingMode"
        static let appearance = "appearance"
        static let showReadyIndicator = "showReadyIndicator"
        static let transcriptionProvider = "transcriptionProvider"
    }

    init(startBackgroundWork: Bool = true) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Dictate", isDirectory: true)
        historyStore = HistoryStore(url: appSupport.appendingPathComponent("history.json"))
        dictionaryStore = AtomicJSONStore(url: appSupport.appendingPathComponent("dictionary.json"))
        appearanceStore = AppearancePreferenceStore()
        permissions = PermissionService()
        dictation = DictationController(permissions: permissions)
        keepHistory = UserDefaults.standard.object(forKey: Keys.keepHistory) as? Bool ?? true
        retention = HistoryRetention(rawValue: UserDefaults.standard.string(forKey: Keys.retention) ?? "") ?? .forever
        shortcut = ShortcutChoice(rawValue: UserDefaults.standard.string(forKey: Keys.shortcut) ?? "") ?? .rightOption
        if let data = UserDefaults.standard.data(forKey: Keys.customShortcut) {
            customShortcut = try? JSONDecoder().decode(RecordedShortcut.self, from: data)
        } else {
            customShortcut = nil
        }
        onboardingDismissed = UserDefaults.standard.bool(forKey: Keys.onboardingDismissed)
        microphoneEnabled = UserDefaults.standard.object(forKey: Keys.microphoneEnabled) as? Bool ?? true
        recordingMode = RecordingMode(rawValue: UserDefaults.standard.string(forKey: Keys.recordingMode) ?? "") ?? .holdToTalk
        appearance = appearanceStore.value
        showReadyIndicator = UserDefaults.standard.object(forKey: Keys.showReadyIndicator) as? Bool ?? true
        let storedProvider = TranscriptionProvider(rawValue: UserDefaults.standard.string(forKey: Keys.transcriptionProvider) ?? "") ?? .apple
        // Apple remains the default for a fresh install. Preserve an explicit
        // Parakeet choice while its service checks the local cache; otherwise
        // a cached model would be unnecessarily replaced by Apple on launch.
        transcriptionProvider = storedProvider

        dictation.onCompleted = { [weak self] item in self?.completed(item) }
        if startBackgroundWork {
            dictation.selectProvider(transcriptionProvider)
        }
        applyAppearance()
        permissions.refresh()
        if startBackgroundWork {
            Task { [weak self] in await self?.loadLocalData() }
        }
    }

    func applyAppearance() {
        let nsAppearance: NSAppearance?
        switch appearance {
        case .system: nsAppearance = nil
        case .light: nsAppearance = NSAppearance(named: .aqua)
        case .dark: nsAppearance = NSAppearance(named: .darkAqua)
        }
        NSApp.appearance = nsAppearance
        for window in NSApp.windows { window.appearance = nsAppearance }
    }

    var filteredHistory: [HistoryItem] {
        let query = historySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return history }
        return history.filter {
            $0.originalTranscript.localizedCaseInsensitiveContains(query) || $0.correctedText.localizedCaseInsensitiveContains(query)
        }
    }

    var filteredDictionary: [DictionaryEntry] {
        dictionary.filter { entry in
            let kindMatches = dictionaryFilter == nil || dictionaryFilter == entry.kind
            let query = dictionarySearch.trimmingCharacters(in: .whitespacesAndNewlines)
            let textMatches = query.isEmpty || entry.sourcePhrase.localizedCaseInsensitiveContains(query) || entry.targetPhrase?.localizedCaseInsensitiveContains(query) == true
            return kindMatches && textMatches
        }
    }

    var totalWordCount: Int {
        history.reduce(0) { total, item in
            total + item.correctedText.split { $0.isWhitespace || $0.isNewline }.count
        }
    }

    var thisWeekHistory: [HistoryItem] {
        guard let start = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: .now)) else {
            return history
        }
        return history.filter { $0.timestamp >= start }
    }

    var thisWeekWordCount: Int {
        thisWeekHistory.reduce(0) { total, item in
            total + item.correctedText.split { $0.isWhitespace || $0.isNewline }.count
        }
    }

    var totalDuration: TimeInterval {
        history.reduce(0) { $0 + $1.duration }
    }

    func startRecording(source: FocusCaptureSource = .mainWindow) {
        permissions.refresh()
        guard microphoneEnabled else { return }
        dictation.start(entries: dictionary, source: source)
    }
    func finishRecording() { dictation.finish() }
    func cancelRecording() { dictation.cancel() }
    func rememberExternalFocus() { dictation.rememberExternalFocus() }

    func completed(_ item: HistoryItem) {
        guard keepHistory else { return }
        history.insert(item, at: 0)
        Task { [historyStore] in try? await historyStore.append(item) }
    }

    func deleteHistory(ids: Set<UUID>) {
        history.removeAll { ids.contains($0.id) }
        Task { [historyStore] in try? await historyStore.delete(ids: ids) }
    }

    func deleteAllHistory() {
        history.removeAll()
        Task { [historyStore] in try? await historyStore.save([]) }
    }

    func copyHistoryItem(_ item: HistoryItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        _ = pasteboard.setString(item.correctedText, forType: .string)
    }

    func togglePin(_ item: HistoryItem) {
        guard let index = history.firstIndex(where: { $0.id == item.id }) else { return }
        history[index].isPinned.toggle()
        let pinned = history[index].isPinned
        Task { [historyStore] in try? await historyStore.setPinned(pinned, id: item.id) }
    }

    func saveDictionaryEntry(_ entry: DictionaryEntry) throws -> [DictionaryWarning] {
        let warnings = try DictionaryValidator.validate(entry, against: dictionary.filter { $0.id != entry.id })
        if let index = dictionary.firstIndex(where: { $0.id == entry.id }) {
            dictionary[index] = entry
        } else {
            dictionary.append(entry)
        }
        persistDictionary()
        return warnings
    }

    func deleteDictionaryEntry(_ entry: DictionaryEntry) {
        dictionary.removeAll { $0.id == entry.id }
        persistDictionary()
    }

    func learnCorrection(_ audit: CorrectionAudit) {
        let learned = DictionaryEntry.correction(heard: audit.heard, written: audit.written)
        guard !dictionary.contains(where: {
            $0.kind == .correction &&
            $0.sourcePhrase.caseInsensitiveCompare(learned.sourcePhrase) == .orderedSame &&
            $0.targetPhrase?.caseInsensitiveCompare(learned.targetPhrase ?? "") == .orderedSame
        }) else {
            dictionaryNotice = String(localized: "dictionary.alreadyLearned")
            return
        }
        do {
            _ = try DictionaryValidator.validate(learned, against: dictionary)
        } catch {
            dictionaryNotice = String(localized: "dictionary.learnFailed")
            return
        }
        dictionary.append(learned)
        persistDictionary()
        dictionaryNotice = String(localized: "dictionary.learned")
    }

    func setDictionaryEnabled(_ enabled: Bool, for entry: DictionaryEntry) {
        guard let index = dictionary.firstIndex(where: { $0.id == entry.id }) else { return }
        dictionary[index].isEnabled = enabled
        dictionary[index].updatedAt = .now
        persistDictionary()
    }

    func importDictionary(merge: Bool) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let document = try decoder.decode(DictionaryDocument.self, from: Data(contentsOf: url))
            try DictionaryValidator.validate(document: document)
            if merge {
                // Merge keeps the first occurrence of each rule and skips
                // entries that fail validation (invalid or duplicate) or that
                // carry advisory warnings (short, single-word patterns), so an
                // imported file can never silently widen the matching surface.
                var unique: [DictionaryEntry] = []
                var skipped = 0
                for entry in dictionary + document.entries {
                    do {
                        let warnings = try DictionaryValidator.validate(entry, against: unique)
                        if warnings.isEmpty {
                            unique.append(entry)
                        } else {
                            skipped += 1
                        }
                    } catch {
                        skipped += 1
                    }
                }
                dictionary = unique
                dictionaryNotice = skipped > 0
                    ? String(localized: "dictionary.importSkipped \(skipped)")
                    : String(localized: "dictionary.imported")
            } else {
                dictionary = document.entries
                dictionaryNotice = String(localized: "dictionary.imported")
            }
            persistDictionary()
        } catch {
            dictionaryNotice = String(localized: "dictionary.importFailed")
        }
    }

    func exportDictionary() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Dictate-Dictionary.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try encoder.encode(DictionaryDocument(entries: dictionary)).write(to: url, options: [.atomic])
        } catch {
            dictionaryNotice = String(localized: "dictionary.exportFailed")
        }
    }

    func exportHistory() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Dictate-History.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(HistoryDocument(items: history)).write(to: url, options: [.atomic])
    }

    func applyRetention() {
        Task { [historyStore, retention] in
            try? await historyStore.applyRetention(retention)
            let latest = try? await historyStore.load()
            await MainActor.run { [weak self] in
                guard let self, let latest else { return }
                self.history = self.mergedHistory(with: latest)
            }
        }
    }

    private func loadLocalData() async {
        async let historyLoad = historyStore.load()
        async let dictionaryLoad = dictionaryStore.load(default: DictionaryDocument(entries: []))
        let loadedHistory = (try? await historyLoad) ?? []
        let loadedDictionary = (try? await dictionaryLoad)?.entries ?? []
        await MainActor.run { [weak self] in
            guard let self else { return }
            let loadedIDs = Set(loadedHistory.map(\.id))
            let completedWhileLoading = self.history.filter { !loadedIDs.contains($0.id) }
            self.history = (loadedHistory + completedWhileLoading).sorted { $0.timestamp > $1.timestamp }
            self.dictionary = loadedDictionary
        }
        guard retention.cutoff(now: .now) != nil else { return }
        try? await historyStore.applyRetention(retention)
        let retainedHistory = (try? await historyStore.load()) ?? loadedHistory
        await MainActor.run { [weak self] in
            guard let self else { return }
            let retainedIDs = Set(retainedHistory.map(\.id))
            let completedWhileLoading = self.history.filter { !retainedIDs.contains($0.id) }
            self.history = (retainedHistory + completedWhileLoading).sorted { $0.timestamp > $1.timestamp }
        }
    }

    private func mergedHistory(with diskHistory: [HistoryItem]) -> [HistoryItem] {
        let diskIDs = Set(diskHistory.map(\.id))
        let completedSinceDiskRead = history.filter { !diskIDs.contains($0.id) }
        return (diskHistory + completedSinceDiskRead).sorted { $0.timestamp > $1.timestamp }
    }

    private func persistDictionary() {
        let document = DictionaryDocument(entries: dictionary)
        Task { [dictionaryStore] in try? await dictionaryStore.save(document) }
    }
}
