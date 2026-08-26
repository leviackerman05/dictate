import XCTest
@testable import DictateCore

final class TranscriptAssemblyStateTests: XCTestCase {
    func testVolatileRevisionsReplaceInsteadOfAppending() {
        var state = TranscriptAssemblyState()
        XCTAssertEqual(state.apply("final phrase A", isFinal: true), "final phrase A")
        XCTAssertEqual(state.apply("tentative B1", isFinal: false), "final phrase A tentative B1")
        XCTAssertEqual(state.apply("revised B2", isFinal: false), "final phrase A revised B2")
        XCTAssertEqual(state.volatileText, "revised B2")
    }

    func testFinalVolatilePhraseIsAppendedExactlyOnce() {
        var state = TranscriptAssemblyState()
        _ = state.apply("A", isFinal: true)
        _ = state.apply("B2", isFinal: false)
        XCTAssertEqual(state.apply("B2", isFinal: true), "A B2")
        XCTAssertEqual(state.apply("", isFinal: false), "A B2")
        XCTAssertEqual(state.finish(), "A B2")
    }

    func testDisjointFinalizedPhrasesFormOneParagraph() {
        var state = TranscriptAssemblyState()
        _ = state.apply("First phrase.", isFinal: true)
        _ = state.apply("Second phrase", isFinal: true)
        _ = state.apply("Third phrase.", isFinal: true)
        XCTAssertEqual(state.visibleText, "First phrase. Second phrase Third phrase.")
        XCTAssertEqual(state.finish(), state.visibleText)
    }

    func testLongPauseKeepsEarlierFinalizedSentence() {
        var state = TranscriptAssemblyState()
        XCTAssertEqual(state.apply("First sentence.", isFinal: true), "First sentence.")
        XCTAssertEqual(state.apply("", isFinal: false), "First sentence.")
        XCTAssertEqual(
            state.apply("Second sentence after a pause.", isFinal: true),
            "First sentence. Second sentence after a pause."
        )
        XCTAssertEqual(state.finish(), "First sentence. Second sentence after a pause.")
    }

    func testEmptyVolatileResultRevokesPreviousHypothesis() {
        var state = TranscriptAssemblyState()
        _ = state.apply("A", isFinal: true)
        _ = state.apply("obsolete B", isFinal: false)
        XCTAssertEqual(state.apply("", isFinal: false), "A")
        XCTAssertEqual(state.volatileText, "")
    }

    func testParakeetSingleCompleteResultIsNotDuplicated() {
        var state = TranscriptAssemblyState()
        _ = state.apply("complete Parakeet result", isFinal: true)
        XCTAssertEqual(state.finish(), "complete Parakeet result")
        XCTAssertEqual(state.finalizedText, "complete Parakeet result")
    }

    func testNoTargetAndMissingPermissionPreserveRecovery() {
        var recovery = DeliveryRecoveryState()
        recovery.resolve("complete transcript", outcome: .noTarget)
        XCTAssertEqual(recovery.text, "complete transcript")
        recovery.resolve("another transcript", outcome: .permissionMissing)
        XCTAssertEqual(recovery.text, "another transcript")
        recovery.resolve("failed transcript", outcome: .deliveryFailed)
        XCTAssertEqual(recovery.text, "failed transcript")
    }

    func testPartialDeliveryFailurePreservesCompleteUnicodePayload() {
        let sentence = "Line one: café №42.\nLine two: 你好, Dictate!"
        let longPayload = Array(repeating: sentence, count: 200).joined(separator: "\n")
        var recovery = DeliveryRecoveryState()

        recovery.resolve(longPayload, outcome: .deliveryFailed)

        XCTAssertEqual(recovery.text, TranscriptText.normalize(longPayload))
        XCTAssertFalse(recovery.canStartNewSession)
    }

    func testPermissionRevocationKeepsCompletedTranscriptRecoverable() {
        var recovery = DeliveryRecoveryState()

        recovery.resolve("Accessibility was revoked after recording.", outcome: .permissionMissing)

        XCTAssertEqual(recovery.text, "Accessibility was revoked after recording.")
    }

    func testPendingRecoveryBlocksSilentOverwriteAndClearsExplicitly() {
        var recovery = DeliveryRecoveryState()
        XCTAssertTrue(recovery.canStartNewSession)
        recovery.preserve("complete transcript")
        XCTAssertFalse(recovery.canStartNewSession)
        XCTAssertEqual(recovery.text, "complete transcript")
        recovery.clear()
        XCTAssertTrue(recovery.canStartNewSession)
    }

    func testSuccessfulInsertionClearsRecovery() {
        var recovery = DeliveryRecoveryState(text: "old pending text")
        recovery.resolve("new transcript", outcome: .inserted)
        XCTAssertNil(recovery.text)
        XCTAssertTrue(recovery.canStartNewSession)
    }
}
