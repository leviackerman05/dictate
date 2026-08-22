import XCTest
@testable import DictateCore

final class StateMachineTests: XCTestCase {
    func testHappyPath() {
        var machine = DictationStateMachine()
        let events: [DictationEvent] = [.startRequested, .resourcesReady, .audioStarted, .partialText("hello", level: 0.4), .finalText("hello"), .insertionSucceeded]
        for event in events { _ = machine.send(event) }
        XCTAssertEqual(machine.state, .idle)
    }

    func testInvalidTransitionsAreIgnored() {
        var machine = DictationStateMachine()
        XCTAssertEqual(machine.send(.resourcesReady).disposition, .ignored)
        XCTAssertEqual(machine.send(.finalText("no")).disposition, .ignored)
        XCTAssertEqual(machine.state, .idle)
    }

    func testSecondStartIsIgnoredDuringFinalization() {
        var machine = DictationStateMachine()
        _ = machine.send(.startRequested)
        _ = machine.send(.resourcesReady)
        _ = machine.send(.audioStarted)
        _ = machine.send(.finalText("done"))
        let result = machine.send(.startRequested)
        XCTAssertEqual(result.disposition, .ignoredWhileFinalizing)
        XCTAssertEqual(machine.state, .inserting(text: "done"))
    }

    func testCancellationNeverLeavesPartialText() {
        var machine = DictationStateMachine()
        _ = machine.send(.startRequested)
        _ = machine.send(.resourcesReady)
        _ = machine.send(.audioStarted)
        _ = machine.send(.partialText("partial", level: 1))
        _ = machine.send(.cancel)
        XCTAssertEqual(machine.state, .idle)
    }

    func testFailureCanRecover() {
        var machine = DictationStateMachine()
        _ = machine.send(.startRequested)
        _ = machine.send(.failure(.speechModelUnavailable))
        XCTAssertEqual(machine.state, .failed(.speechModelUnavailable))
        _ = machine.send(.reset)
        XCTAssertEqual(machine.state, .idle)
    }
}
