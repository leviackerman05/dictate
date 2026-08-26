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

    func testCorrectionsPreserveRawTranscriptAndRespectUnicodeBoundaries() {
        let raw = "Zoë met résumé_writer, then said résumé!\nVersion 2 stayed résumé-based."
        let entries = [
            DictionaryEntry.correction(heard: "Zoë", written: "Zoë Saldaña"),
            DictionaryEntry.correction(heard: "résumé", written: "CV")
        ]

        let result = CorrectionMatcher().apply(raw, entries: entries)

        XCTAssertEqual(result.originalText, raw)
        XCTAssertEqual(
            result.correctedText,
            "Zoë Saldaña met résumé_writer, then said CV!\nVersion 2 stayed CV-based."
        )
        XCTAssertEqual(result.audits.map(\.heard), ["Zoë", "résumé", "résumé"])
    }

    func testEqualPriorityCorrectionsAreIndependentOfEntryOrder() {
        let spaced = DictionaryEntry.correction(heard: "new york", written: "New York")
        let hyphenated = DictionaryEntry.correction(heard: "new-york", written: "NY")
        let matcher = CorrectionMatcher()

        let forward = matcher.apply("new-york", entries: [spaced, hyphenated])
        let reversed = matcher.apply("new-york", entries: [hyphenated, spaced])

        XCTAssertEqual(forward.correctedText, reversed.correctedText)
        XCTAssertEqual(forward.audits.map { [$0.heard, $0.written] }, reversed.audits.map { [$0.heard, $0.written] })
    }

    func testCorrectionDoesNotCorruptUnrelatedWordsNumbersOrPunctuation() {
        let entries = [DictionaryEntry.correction(heard: "cat", written: "CAT")]
        let input = "cat, concatenate, bobcat, cat_2, cat2, (cat), and 42 cats."

        XCTAssertEqual(
            CorrectionMatcher().apply(input, entries: entries).correctedText,
            "CAT, concatenate, bobcat, cat_2, cat2, (CAT), and 42 cats."
        )
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

    func testValidationTreatsEquivalentSeparatorsAsDuplicates() throws {
        let existing = DictionaryEntry.correction(heard: "Claude Code", written: "Claude Code")
        let duplicate = DictionaryEntry.correction(heard: "claude-code", written: "claude code")

        XCTAssertThrowsError(try DictionaryValidator.validate(duplicate, against: [existing])) { error in
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
