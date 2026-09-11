import XCTest
@testable import DictateCore

final class ModelSelectionPolicyTests: XCTestCase {
    func testRevisedSetupPrefersAppleOverSavedOrCachedParakeet() {
        XCTAssertEqual(ModelSelectionPolicy.select(saved: "parakeet", supported: ["apple", "parakeet"], installed: ["parakeet"], recommended: "apple", preferRecommendation: true), "apple")
        XCTAssertEqual(ModelSelectionPolicy.select(saved: nil, supported: ["apple", "parakeet"], installed: ["parakeet"], recommended: "apple", preferRecommendation: true), "apple")
    }
    func testRecommendationNeverSelectsAnUnsupportedAppleAPI() {
        XCTAssertEqual(ModelSelectionPolicy.select(saved: "parakeet", supported: ["tiny", "parakeet"], installed: ["parakeet"], recommended: "apple", preferRecommendation: true), "parakeet")
    }
    func testUnsupportedSavedAppleFallsBackToInstalledModel() {
        XCTAssertEqual(ModelSelectionPolicy.select(saved: "apple", supported: ["tiny", "parakeet"], installed: ["parakeet"], recommended: "tiny"), "parakeet")
    }
    func testPreservesExplicitSupportedChoiceWithoutNeedingDownload() {
        XCTAssertEqual(ModelSelectionPolicy.select(saved: "tiny", supported: ["apple", "tiny"], installed: ["apple"], recommended: "apple"), "tiny")
    }
    func testFreshInstallUsesRecommendationAndEmptyCatalogIsUnavailable() {
        XCTAssertEqual(ModelSelectionPolicy.select(saved: nil, supported: ["apple", "parakeet"], installed: ["parakeet"], recommended: "apple"), "apple")
        XCTAssertEqual(ModelSelectionPolicy.select(saved: nil, supported: ["tiny", "base"], installed: [], recommended: "tiny"), "tiny")
        XCTAssertNil(ModelSelectionPolicy.select(saved: "apple", supported: [], installed: [], recommended: "tiny"))
    }
}
