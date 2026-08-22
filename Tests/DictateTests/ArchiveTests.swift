import Foundation
import XCTest
@testable import DictateCore

final class ArchiveTests: XCTestCase {
    func testHistoryRoundTripAndRetention() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = HistoryStore(url: directory.appendingPathComponent("history.json"))
        let now = Date(timeIntervalSince1970: 1_000_000)
        let old = HistoryItem(timestamp: now.addingTimeInterval(-9 * 86_400), originalTranscript: "old", correctedText: "old", duration: 1, insertionResult: .inserted)
        let fresh = HistoryItem(timestamp: now, originalTranscript: "fresh", correctedText: "fresh", duration: 1, insertionResult: .inserted)
        try await store.save([old, fresh])
        try await store.applyRetention(.oneWeek, now: now)
        let loaded = try await store.load()
        XCTAssertEqual(loaded.map(\.originalTranscript), ["fresh"])
    }

    func testDictionaryDocumentSchemaRoundTrip() throws {
        let document = DictionaryDocument(entries: [DictionaryEntry.vocabulary("Dictate")])
        let data = try JSONEncoder().encode(document)
        let decoded = try JSONDecoder().decode(DictionaryDocument.self, from: data)
        XCTAssertEqual(decoded, document)
        XCTAssertNoThrow(try DictionaryValidator.validate(document: decoded))
    }
}
