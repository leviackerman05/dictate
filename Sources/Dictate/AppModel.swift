import AppKit
import DictateCore
import Foundation
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case history
    case dictionary
    case settings

    var id: String { rawValue }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var section: AppSection = .history
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

    let dictation: DictationController
    let permissions: PermissionService
    private let historyStore: HistoryStore
    private let dictionaryStore: AtomicJSONStore<DictionaryDocument>

    private enum Keys {
        static let keepHistory = "keepHistory"
        static let retention = "retention"
        static let shortcut = "shortcut"
        static let customShortcut = "customShortcut"
        static let onboardingDismissed = "onboardingDismissed"
    }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Dictate", isDirectory: true)
        historyStore = HistoryStore(url: appSupport.appendingPathComponent("history.json"))
        dictionaryStore = AtomicJSONStore(url: appSupport.appendingPathComponent("dictionary.json"))
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

        dictation.onCompleted = { [weak self] item in self?.completed(item) }
        permissions.refresh()
        Task { [weak self] in await self?.loadLocalData() }
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

    func startRecording() { dictation.start(entries: dictionary) }
    func finishRecording() { dictation.finish() }
    func cancelRecording() { dictation.cancel() }

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
            let imported = merge ? dictionary + document.entries : document.entries
            if merge {
                var unique: [DictionaryEntry] = []
                for entry in imported {
                    if (try? DictionaryValidator.validate(entry, against: unique)) != nil { unique.append(entry) }
                }
                dictionary = unique
            } else {
                dictionary = imported
            }
            persistDictionary()
            dictionaryNotice = String(localized: "dictionary.imported")
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
        try? encoder.encode(DictionaryDocument(entries: dictionary)).write(to: url, options: [.atomic])
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
            await MainActor.run { [weak self] in self?.history = latest ?? self?.history ?? [] }
        }
    }

    private func loadLocalData() async {
        let loadedHistory = (try? await historyStore.load()) ?? []
        let loadedDictionary = (try? await dictionaryStore.load(default: DictionaryDocument(entries: [])))?.entries ?? []
        history = loadedHistory
        dictionary = loadedDictionary
        try? await historyStore.applyRetention(retention)
        history = (try? await historyStore.load()) ?? history
    }

    private func persistDictionary() {
        let document = DictionaryDocument(entries: dictionary)
        Task { [dictionaryStore] in try? await dictionaryStore.save(document) }
    }
}
