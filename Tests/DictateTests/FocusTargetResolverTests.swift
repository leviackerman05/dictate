import XCTest
@testable import DictateCore

final class FocusTargetResolverTests: XCTestCase {
    func testGlobalShortcutUsesOnlyCurrentEditableTarget() {
        XCTAssertEqual(
            FocusTargetResolver.select(source: .globalShortcut, currentIsUsable: true, preservedIsUsable: true),
            .current
        )
        XCTAssertEqual(
            FocusTargetResolver.select(source: .globalShortcut, currentIsUsable: false, preservedIsUsable: true),
            .missing
        )
    }

    func testUIInvocationCanUseImmediatelyPreservedEditableTarget() {
        XCTAssertEqual(
            FocusTargetResolver.select(source: .mainWindow, currentIsUsable: false, preservedIsUsable: true),
            .preserved
        )
        XCTAssertEqual(
            FocusTargetResolver.select(source: .menuBar, currentIsUsable: false, preservedIsUsable: false),
            .missing
        )
    }
}
