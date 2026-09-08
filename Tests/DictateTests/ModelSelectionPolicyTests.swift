import XCTest
@testable import DictateCore

final class ModelSelectionPolicyTests: XCTestCase {
    func testUnsupportedSavedAppleFallsBackToInstalledModel() {
        XCTAssertEqual(ModelSelectionPolicy.select(saved: "apple", supported: ["tiny", "parakeet"], installed: ["parakeet"], recommended: "tiny"), "parakeet")
    }
    func testPreservesExplicitSupportedChoiceWithoutNeedingDownload() {
        XCTAssertEqual(ModelSelectionPolicy.select(saved: "tiny", supported: ["apple", "tiny"], installed: ["apple"], recommended: "apple"), "tiny")
    }
    func testFreshInstallUsesRecommendationAndEmptyCatalogIsUnavailable() {
        XCTAssertEqual(ModelSelectionPolicy.select(saved: nil, supported: ["tiny", "base"], installed: [], recommended: "tiny"), "tiny")
        XCTAssertNil(ModelSelectionPolicy.select(saved: "apple", supported: [], installed: [], recommended: "tiny"))
    }
}
