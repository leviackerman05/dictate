import XCTest
@testable import DictateCore

final class CorrectionMatcherTests: XCTestCase {
    func testTableDrivenCorrections() {
        let cases: [(input: String, expected: String, count: Int)] = [
            ("cloud code is useful", "Claude Code is useful", 1),
            ("CloudCode and cloud-code", "Claude Code and Claude Code", 2),
            ("cloud codebase and cloud", "cloud codebase and cloud", 0),
            ("A CLOUD CODE, then Cloud Code.", "A Claude Code, then Claude Code.", 2),
            ("RÉSUMÉ, résumé", "CV, CV", 2),
            ("naïve café", "naïve café", 0),
            ("go go go", "move move move", 3),
            ("", "", 0),
            ("cloud code cloud", "Claude Code cloud", 1)
        ]
        let entries = [
            DictionaryEntry.correction(heard: "cloud code", written: "Claude Code"),
            DictionaryEntry.correction(heard: "go", written: "move"),
            DictionaryEntry.correction(heard: "résumé", written: "CV")
        ]
        let matcher = CorrectionMatcher()
        for item in cases {
            let result = matcher.apply(item.input, entries: entries)
            XCTAssertEqual(result.correctedText, item.expected, item.input)
            XCTAssertEqual(result.audits.count, item.count, item.input)
        }
    }

    func testLongestOverlappingPhraseWins() {
        let entries = [
            DictionaryEntry.correction(heard: "new york", written: "New York"),
            DictionaryEntry.correction(heard: "new york city", written: "New York City")
        ]
        let result = CorrectionMatcher().apply("new york city", entries: entries)
        XCTAssertEqual(result.correctedText, "New York City")
        XCTAssertEqual(result.audits.count, 1)
    }

    func testReplacementIsNotRecursivelyCorrected() {
        let entries = [
            DictionaryEntry.correction(heard: "a", written: "b"),
            DictionaryEntry.correction(heard: "b", written: "c")
        ]
        XCTAssertEqual(CorrectionMatcher().apply("a", entries: entries).correctedText, "b")
    }

    func testValidationAllowsRiskWarningButRejectsDuplicates() throws {
        let first = DictionaryEntry.correction(heard: "x", written: "X")
        let warnings = try DictionaryValidator.validate(first)
        XCTAssertFalse(warnings.isEmpty)
        let duplicate = DictionaryEntry.correction(heard: "x", written: "X")
        XCTAssertThrowsError(try DictionaryValidator.validate(duplicate, against: [first])) { error in
            XCTAssertEqual(error as? DictionaryValidationError, .duplicate)
        }
    }

    func testVocabularySelectionIsBoundedAndRelevant() {
        let entries = (0..<30).map { DictionaryEntry.vocabulary("term \($0)") } + [DictionaryEntry.vocabulary("Claude Code")]
        let selected = VocabularySelector.select(entries: entries, context: "I am using Claude Code", limit: 5)
        XCTAssertEqual(selected.count, 5)
        XCTAssertEqual(selected.first, "Claude Code")
    }
}
