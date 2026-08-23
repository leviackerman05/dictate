import XCTest
@testable import DictateCore

final class ShortcutGestureReducerTests: XCTestCase {
    func testHoldStartsOnceAndStopsOnRelease() {
        var reducer = ShortcutGestureReducer()
        XCTAssertEqual(reducer.reduce(.physicalDown, mode: .holdToTalk, session: .idle), .start)
        XCTAssertEqual(reducer.reduce(.physicalDown, mode: .holdToTalk, session: .preparing), .none)
        XCTAssertEqual(reducer.reduce(.keyRepeat, mode: .holdToTalk, session: .recording), .none)
        XCTAssertEqual(reducer.reduce(.physicalUp, mode: .holdToTalk, session: .recording), .requestStop)
        XCTAssertFalse(reducer.physicalPressed)
    }

    func testReleaseDuringPreparationStopsAfterCaptureCanStart() {
        var reducer = ShortcutGestureReducer()
        XCTAssertEqual(reducer.reduce(.physicalDown, mode: .holdToTalk, session: .idle), .start)
        XCTAssertEqual(reducer.reduce(.physicalUp, mode: .holdToTalk, session: .preparing), .requestStop)
    }

    func testToggleKeepsSessionAfterKeyUpAndSecondPressStops() {
        var reducer = ShortcutGestureReducer()
        XCTAssertEqual(reducer.reduce(.physicalDown, mode: .clickToToggle, session: .idle), .start)
        XCTAssertEqual(reducer.reduce(.physicalUp, mode: .clickToToggle, session: .preparing), .none)
        XCTAssertEqual(reducer.reduce(.physicalDown, mode: .clickToToggle, session: .recording), .requestStop)
        XCTAssertEqual(reducer.reduce(.physicalUp, mode: .clickToToggle, session: .finalizing), .none)
    }

    func testToggleRepeatDoesNotStopAndFinalizingIgnoresPress() {
        var reducer = ShortcutGestureReducer()
        XCTAssertEqual(reducer.reduce(.physicalDown, mode: .clickToToggle, session: .idle), .start)
        XCTAssertEqual(reducer.reduce(.keyRepeat, mode: .clickToToggle, session: .preparing), .none)
        _ = reducer.reduce(.physicalUp, mode: .clickToToggle, session: .preparing)
        XCTAssertEqual(reducer.reduce(.physicalDown, mode: .clickToToggle, session: .finalizing), .none)
    }
}
