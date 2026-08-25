import Foundation

public enum InsertionResult: String, Codable, CaseIterable, Sendable {
    case inserted
    case insertedViaAccessibility
    case insertedViaPaste
    case copiedOnly
    case copiedForRecovery
    case noTarget
    case permissionMissing
    case deliveryFailed
    case failed
    case notRequested
}

public struct HistoryItem: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let originalTranscript: String
    public let correctedText: String
    public let duration: TimeInterval
    public let insertionResult: InsertionResult
    public let correctionAudit: [CorrectionAudit]
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        originalTranscript: String,
        correctedText: String,
        duration: TimeInterval,
        insertionResult: InsertionResult,
        correctionAudit: [CorrectionAudit] = [],
        isPinned: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.originalTranscript = originalTranscript
        self.correctedText = correctedText
        self.duration = duration
        self.insertionResult = insertionResult
        self.correctionAudit = correctionAudit
        self.isPinned = isPinned
    }
}

public struct HistoryDocument: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public var items: [HistoryItem]

    public init(schemaVersion: Int = 1, items: [HistoryItem] = []) {
        self.schemaVersion = schemaVersion
        self.items = items
    }
}

public enum HistoryRetention: String, Codable, CaseIterable, Sendable, Identifiable, Equatable {
    case oneDay
    case oneWeek
    case oneMonth
    case forever

    public var id: String { rawValue }

    public func cutoff(now: Date) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .oneDay: return calendar.date(byAdding: .day, value: -1, to: now)
        case .oneWeek: return calendar.date(byAdding: .day, value: -7, to: now)
        case .oneMonth: return calendar.date(byAdding: .month, value: -1, to: now)
        case .forever: return nil
        }
    }
}

public actor HistoryStore {
    private let url: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(url: URL) {
        self.url = url
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() throws -> [HistoryItem] {
        try loadDocument().items
    }

    public func save(_ items: [HistoryItem]) throws {
        try saveDocument(HistoryDocument(items: items))
    }

    public func append(_ item: HistoryItem) throws {
        var items = try load()
        items.insert(item, at: 0)
        try save(items)
    }

    public func delete(ids: Set<UUID>) throws {
        try save(try load().filter { !ids.contains($0.id) })
    }

    public func setPinned(_ pinned: Bool, id: UUID) throws {
        var items = try load()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned = pinned
        try save(items)
    }

    public func applyRetention(_ retention: HistoryRetention, now: Date = .now) throws {
        guard let cutoff = retention.cutoff(now: now) else { return }
        try save(try load().filter { $0.isPinned || $0.timestamp >= cutoff })
    }

    private func loadDocument() throws -> HistoryDocument {
        guard FileManager.default.fileExists(atPath: url.path) else { return HistoryDocument() }
        return try decoder.decode(HistoryDocument.self, from: Data(contentsOf: url))
    }

    private func saveDocument(_ document: HistoryDocument) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(document).write(to: url, options: [.atomic])
    }
}
