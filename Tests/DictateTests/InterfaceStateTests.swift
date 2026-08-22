import XCTest
@testable import DictateCore

/// These state-focused tests are the CLI-safe portion of the interface test suite.
/// The macOS app target owns the real SwiftUI/AppKit screenshot tests when run from Xcode.
final class InterfaceStateTests: XCTestCase {
    func testRequiredVisualStatesHaveDistinctSessionStates() {
        var machine = DictationStateMachine()
        XCTAssertEqual(machine.state, .idle)
        _ = machine.send(.startRequested)
        XCTAssertEqual(machine.state, .preparing)
        _ = machine.send(.resourcesReady)
        _ = machine.send(.audioStarted)
        XCTAssertEqual(machine.state, .listening)
        _ = machine.send(.partialText("live", level: 0.5))
        XCTAssertEqual(machine.state, .transcribing(partialText: "live", level: 0.5))
        _ = machine.send(.failure(.microphonePermissionDenied))
        XCTAssertEqual(machine.state, .failed(.microphonePermissionDenied))
    }
}
