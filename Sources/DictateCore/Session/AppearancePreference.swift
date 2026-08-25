import Foundation

public enum AppearancePreference: String, CaseIterable, Codable, Identifiable, Sendable, Equatable {
    case system
    case light
    case dark

    public var id: String { rawValue }
}

public struct AppearancePreferenceStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "appearance") {
        self.defaults = defaults
        self.key = key
    }

    public var value: AppearancePreference {
        get { AppearancePreference(rawValue: defaults.string(forKey: key) ?? "") ?? .system }
        nonmutating set { defaults.set(newValue.rawValue, forKey: key) }
    }
}
