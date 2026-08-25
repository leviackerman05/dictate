import XCTest
@testable import DictateCore

final class AppearanceAndPebbleTests: XCTestCase {
    func testAppearancePreferencePersistsAndDefaultsToSystem() {
        let suiteName = "Dictate.AppearanceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppearancePreferenceStore(defaults: defaults, key: "test.appearance")
        XCTAssertEqual(store.value, .system)
        store.value = .dark

        let reloaded = AppearancePreferenceStore(defaults: defaults, key: "test.appearance")
        XCTAssertEqual(reloaded.value, .dark)
    }

    func testSignalPebbleMapsSessionAndDeliveryStates() {
        XCTAssertEqual(SignalPebbleStateMapper.phase(state: .idle, notice: nil), .ready)
        XCTAssertEqual(SignalPebbleStateMapper.phase(state: .listening, notice: nil), .listening)
        XCTAssertEqual(SignalPebbleStateMapper.phase(state: .finalizing, notice: nil), .processing)
        XCTAssertEqual(SignalPebbleStateMapper.phase(state: .idle, notice: .inserted), .inserted)
        XCTAssertEqual(SignalPebbleStateMapper.phase(state: .idle, notice: .recovery), .recovery)
        XCTAssertEqual(SignalPebbleStateMapper.phase(state: .failed(.captureUnavailable), notice: nil), .failed)
    }
}
