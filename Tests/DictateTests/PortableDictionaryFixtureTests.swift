import Foundation
import Testing
@testable import DictateCore

struct PortableDictionaryFixtureTests {
    struct Fixture: Decodable {
        struct Case: Decodable { let input: String; let expected: String }
        let dictionary: DictionaryDocument
        let cases: [Case]
    }

    @Test func sharedDictionaryBehavesTheSameOnMacAndPortable() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Fixtures/portable-dictionary.json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let fixture = try decoder.decode(Fixture.self, from: Data(contentsOf: url))
        for item in fixture.cases {
            #expect(CorrectionMatcher().apply(item.input, entries: fixture.dictionary.entries).correctedText == item.expected)
        }
    }
}
