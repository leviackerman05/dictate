import DictateCore
import XCTest

final class BenchmarkMetricTests: XCTestCase {
    func testWordErrorRateCountsSubstitutionsInsertionsAndDeletions() {
        XCTAssertEqual(WordErrorRate.measure(reference: "one two three", hypothesis: "one too three")!, 1.0 / 3.0, accuracy: 0.000_001)
        XCTAssertEqual(WordErrorRate.measure(reference: "one two", hypothesis: "one extra two")!, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(WordErrorRate.measure(reference: "one two", hypothesis: "one")!, 0.5, accuracy: 0.000_001)
    }

    func testWordErrorRateNormalizationIsDocumentedAndDeterministic() {
        XCTAssertEqual(WordErrorRate.measure(reference: "Résumé, CAFÉ!", hypothesis: "resume cafe"), 0)
        XCTAssertNil(WordErrorRate.measure(reference: "…", hypothesis: "anything"))
    }
}
