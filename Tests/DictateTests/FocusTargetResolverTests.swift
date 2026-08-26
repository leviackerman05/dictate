import XCTest
@testable import DictateCore

final class FocusTargetResolverTests: XCTestCase {
    func testFocusIntentRequiresSameGenerationAndTarget() {
        let target = FocusTargetFingerprint(
            processIdentifier: 42,
            bundleIdentifier: "com.example.Editor",
            role: "AXTextArea",
            subrole: nil,
            frame: CGRect(x: 10, y: 10, width: 300, height: 40)
        )
        var tracker = FocusIntentTracker()
        let capture = tracker.begin(target)

        XCTAssertTrue(tracker.allows(capture, current: target))
        tracker.focusChanged(to: nil)
        XCTAssertFalse(tracker.allows(capture, current: target))
    }

    func testOriginalTargetRemainingFocusedIsAllowed() {
        let original = target(frame: CGRect(x: 10, y: 10, width: 300, height: 40))
        var tracker = FocusIntentTracker()
        let capture = tracker.begin(original)

        XCTAssertTrue(tracker.allows(capture, current: original))
    }

    func testSwitchingToAnotherFieldRejectsOriginalCapture() {
        let original = target(frame: CGRect(x: 10, y: 10, width: 300, height: 40))
        let second = target(frame: CGRect(x: 10, y: 80, width: 300, height: 40))
        var tracker = FocusIntentTracker()
        let capture = tracker.begin(original)

        tracker.focusChanged(to: second)

        XCTAssertFalse(tracker.allows(capture, current: second))
        XCTAssertFalse(tracker.allows(capture, current: original))
    }

    func testClosedOrUnavailableTargetRejectsOriginalCapture() {
        let original = target(frame: CGRect(x: 10, y: 10, width: 300, height: 40))
        var tracker = FocusIntentTracker()
        let capture = tracker.begin(original)

        tracker.focusChanged(to: nil)

        XCTAssertFalse(tracker.allows(capture, current: nil))
        XCTAssertEqual(
            FocusTargetResolver.select(source: .completion, currentIsUsable: false, preservedIsUsable: true),
            .missing
        )
    }

    func testPointerOutsideTargetInvalidatesWithoutTimeout() {
        let target = FocusTargetFingerprint(
            processIdentifier: 42,
            bundleIdentifier: "com.example.Editor",
            role: "AXTextArea",
            subrole: nil,
            frame: CGRect(x: 10, y: 10, width: 300, height: 40)
        )
        var tracker = FocusIntentTracker()
        let capture = tracker.begin(target)

        tracker.pointerDown(at: CGPoint(x: 900, y: 900))

        XCTAssertFalse(tracker.allows(capture, current: target))
    }

    func testPointerInsideTargetKeepsIntent() {
        let target = FocusTargetFingerprint(
            processIdentifier: 42,
            bundleIdentifier: "com.example.Editor",
            role: "AXTextArea",
            subrole: nil,
            frame: CGRect(x: 10, y: 10, width: 300, height: 40)
        )
        var tracker = FocusIntentTracker()
        let capture = tracker.begin(target)

        tracker.pointerDown(at: CGPoint(x: 150, y: 30))

        XCTAssertTrue(tracker.allows(capture, current: target))
    }

    func testRecentConfirmedHitAllowsTargetWithoutAXFrame() {
        XCTAssertFalse(FocusClickIntentPolicy.abandonsTarget(
            sameProcess: true,
            clickTime: 100,
            captureTime: 101,
            clickLocation: CGPoint(x: 400, y: 300),
            capturedFrame: nil,
            hitTestConfirmedTarget: true,
            focusRestoredAfterClick: false
        ))
    }

    func testRecentUnconfirmedHitRejectsTargetWithoutAXFrame() {
        XCTAssertTrue(FocusClickIntentPolicy.abandonsTarget(
            sameProcess: true,
            clickTime: 100,
            captureTime: 101,
            clickLocation: CGPoint(x: 400, y: 300),
            capturedFrame: nil,
            hitTestConfirmedTarget: false,
            focusRestoredAfterClick: false
        ))
    }

    func testStaleClickDoesNotAbandonCurrentTarget() {
        XCTAssertFalse(FocusClickIntentPolicy.abandonsTarget(
            sameProcess: true,
            clickTime: 50,
            captureTime: 101,
            clickLocation: CGPoint(x: 900, y: 900),
            capturedFrame: nil,
            hitTestConfirmedTarget: false,
            focusRestoredAfterClick: false
        ))
    }

    func testClickAwayAfterCaptureStillRejectsFramelessTarget() {
        XCTAssertTrue(FocusClickIntentPolicy.abandonsTarget(
            sameProcess: true,
            clickTime: 102,
            captureTime: 101,
            clickLocation: CGPoint(x: 900, y: 900),
            capturedFrame: nil,
            hitTestConfirmedTarget: true,
            focusRestoredAfterClick: false
        ))
    }

    func testGlobalShortcutUsesOnlyCurrentEditableTarget() {
        XCTAssertEqual(
            FocusTargetResolver.select(source: .globalShortcut, currentIsUsable: true, preservedIsUsable: true),
            .current
        )
        XCTAssertEqual(
            FocusTargetResolver.select(source: .globalShortcut, currentIsUsable: false, preservedIsUsable: true),
            .missing
        )
        XCTAssertEqual(
            FocusTargetResolver.select(source: .globalShortcut, currentIsUsable: false, preservedIsUsable: false),
            .missing
        )
    }

    func testCompletionUsesOnlyCurrentlyFocusedEditableTarget() {
        XCTAssertEqual(
            FocusTargetResolver.select(source: .completion, currentIsUsable: true, preservedIsUsable: true),
            .current
        )
        XCTAssertEqual(
            FocusTargetResolver.select(source: .completion, currentIsUsable: false, preservedIsUsable: true),
            .missing
        )
    }

    func testMainWindowNeverFallsBackToPreservedTarget() {
        XCTAssertEqual(
            FocusTargetResolver.select(source: .mainWindow, currentIsUsable: true, preservedIsUsable: true),
            .current
        )
        XCTAssertEqual(
            FocusTargetResolver.select(source: .mainWindow, currentIsUsable: false, preservedIsUsable: true),
            .missing
        )
        XCTAssertEqual(
            FocusTargetResolver.select(source: .mainWindow, currentIsUsable: false, preservedIsUsable: false),
            .missing
        )
    }

    func testMenuBarNeverFallsBackToPreservedTarget() {
        XCTAssertEqual(
            FocusTargetResolver.select(source: .menuBar, currentIsUsable: true, preservedIsUsable: false),
            .current
        )
        XCTAssertEqual(
            FocusTargetResolver.select(source: .menuBar, currentIsUsable: false, preservedIsUsable: true),
            .missing
        )
        XCTAssertEqual(
            FocusTargetResolver.select(source: .menuBar, currentIsUsable: false, preservedIsUsable: false),
            .missing
        )
    }

    func testRetryNeverFallsBackToPreservedEditableTarget() {
        XCTAssertEqual(
            FocusTargetResolver.select(source: .retry, currentIsUsable: true, preservedIsUsable: true),
            .current
        )
        XCTAssertEqual(
            FocusTargetResolver.select(source: .retry, currentIsUsable: false, preservedIsUsable: true),
            .missing
        )
        XCTAssertEqual(
            FocusTargetResolver.select(source: .retry, currentIsUsable: false, preservedIsUsable: false),
            .missing
        )
    }

    func testElectronAndWebEditorsUsePasteFirstStrategy() {
        XCTAssertEqual(
            TextDeliveryStrategyPolicy.strategy(isWebBacked: true, isElectronApplication: false),
            .pasteFirst
        )
        XCTAssertEqual(
            TextDeliveryStrategyPolicy.strategy(isWebBacked: false, isElectronApplication: true),
            .pasteFirst
        )
        XCTAssertEqual(
            TextDeliveryStrategyPolicy.strategy(isWebBacked: false, isElectronApplication: false),
            .accessibilityFirst
        )
    }

    func testClipboardRestoresOnlyWhenTemporaryValueIsStillCurrent() {
        XCTAssertTrue(PasteboardRestorationPolicy.shouldRestore(temporaryChangeCount: 12, currentChangeCount: 12))
        XCTAssertFalse(PasteboardRestorationPolicy.shouldRestore(temporaryChangeCount: 12, currentChangeCount: 13))
    }

    private func target(frame: CGRect) -> FocusTargetFingerprint {
        FocusTargetFingerprint(
            processIdentifier: 42,
            bundleIdentifier: "com.example.Editor",
            role: "AXTextArea",
            subrole: nil,
            frame: frame
        )
    }
}
