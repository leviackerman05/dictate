import Foundation

public enum DictionaryEntryKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case vocabulary
    case correction

    public var id: String { rawValue }
}

public struct DictionaryEntry: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var kind: DictionaryEntryKind
    public var sourcePhrase: String
    public var targetPhrase: String?
    public var notes: String?
    public var isEnabled: Bool
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        kind: DictionaryEntryKind,
        sourcePhrase: String,
        targetPhrase: String? = nil,
        notes: String? = nil,
        isEnabled: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.sourcePhrase = sourcePhrase
        self.targetPhrase = targetPhrase
        self.notes = notes
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func vocabulary(_ phrase: String) -> DictionaryEntry {
        DictionaryEntry(kind: .vocabulary, sourcePhrase: phrase)
    }

    public static func correction(heard: String, written: String) -> DictionaryEntry {
        DictionaryEntry(kind: .correction, sourcePhrase: heard, targetPhrase: written)
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, sourcePhrase, targetPhrase, notes, isEnabled, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(DictionaryEntryKind.self, forKey: .kind)
        sourcePhrase = try container.decode(String.self, forKey: .sourcePhrase)
        targetPhrase = try container.decodeIfPresent(String.self, forKey: .targetPhrase)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

public struct DictionaryDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let exportedAt: Date
    public let entries: [DictionaryEntry]

    public init(
        schemaVersion: Int = DictionaryDocument.currentSchemaVersion,
        exportedAt: Date = .now,
        entries: [DictionaryEntry]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.entries = entries
    }
}

public struct DictionaryWarning: Equatable, Sendable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

public enum DictionaryValidationError: Error, Equatable, LocalizedError, Sendable {
    case emptySource
    case emptyTarget
    case vocabularyCannotHaveTarget
    case correctionRequiresTarget
    case duplicate
    case unsupportedSchema(Int)

    public var errorDescription: String? {
        switch self {
        case .emptySource: "The heard or preferred phrase cannot be empty."
        case .emptyTarget: "The written phrase cannot be empty."
        case .vocabularyCannotHaveTarget: "Vocabulary entries cannot include a written correction."
        case .correctionRequiresTarget: "A correction needs both a heard form and a written form."
        case .duplicate: "An identical enabled dictionary entry already exists."
        case .unsupportedSchema(let version): "Dictionary schema version \(version) is not supported."
        }
    }
}

public enum DictionaryValidator {
    public static func validate(
        _ entry: DictionaryEntry,
        against existing: [DictionaryEntry] = []
    ) throws -> [DictionaryWarning] {
        let source = entry.sourcePhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { throw DictionaryValidationError.emptySource }

        switch entry.kind {
        case .vocabulary:
            if let target = entry.targetPhrase, !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw DictionaryValidationError.vocabularyCannotHaveTarget
            }
        case .correction:
            guard let target = entry.targetPhrase else { throw DictionaryValidationError.correctionRequiresTarget }
            guard !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DictionaryValidationError.emptyTarget
            }
        }

        let normalizedSource = normalizedPhrase(source)
        let normalizedTarget = entry.targetPhrase.map(normalizedPhrase)
        let isDuplicate = existing.contains { candidate in
            candidate.kind == entry.kind &&
            normalizedPhrase(candidate.sourcePhrase) == normalizedSource &&
            candidate.targetPhrase.map(normalizedPhrase) == normalizedTarget
        }
        if isDuplicate { throw DictionaryValidationError.duplicate }

        var warnings: [DictionaryWarning] = []
        if normalizedSource.count <= 3 {
            warnings.append(DictionaryWarning(message: "Short patterns can affect ordinary prose. For example, “\(source)” may match inside a larger phrase."))
        }
        if normalizedSource.split(whereSeparator: { $0 == " " || $0 == "-" }).count == 1 && normalizedSource.count <= 7 {
            warnings.append(DictionaryWarning(message: "Single-word patterns are broad. Check the live example before saving."))
        }
        return warnings
    }

    public static func validate(document: DictionaryDocument) throws {
        guard document.schemaVersion == DictionaryDocument.currentSchemaVersion else {
            throw DictionaryValidationError.unsupportedSchema(document.schemaVersion)
        }
        var seen: [DictionaryEntry] = []
        for entry in document.entries {
            _ = try validate(entry, against: seen)
            seen.append(entry)
        }
    }

    private static func normalizedPhrase(_ phrase: String) -> String {
        phrase
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split { $0.isWhitespace || $0 == "-" }
            .joined()
            .lowercased()
    }
}

public struct CorrectionAudit: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let heard: String
    public let written: String

    public init(id: UUID = UUID(), heard: String, written: String) {
        self.id = id
        self.heard = heard
        self.written = written
    }
}

public struct CorrectionResult: Equatable, Sendable {
    public let originalText: String
    public let correctedText: String
    public let audits: [CorrectionAudit]

    public init(originalText: String, correctedText: String, audits: [CorrectionAudit]) {
        self.originalText = originalText
        self.correctedText = correctedText
        self.audits = audits
    }
}
