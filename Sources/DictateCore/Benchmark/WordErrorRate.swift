import Foundation

public enum WordErrorRate {
    public static func measure(reference: String, hypothesis: String) -> Double? {
        let expected = words(in: reference)
        guard !expected.isEmpty else { return nil }
        let actual = words(in: hypothesis)
        var previous = Array(0...actual.count)
        for (row, expectedWord) in expected.enumerated() {
            var current = [row + 1]
            current.reserveCapacity(actual.count + 1)
            for (column, actualWord) in actual.enumerated() {
                let substitution = previous[column] + (expectedWord == actualWord ? 0 : 1)
                let deletion = previous[column + 1] + 1
                let insertion = current[column] + 1
                current.append(min(substitution, deletion, insertion))
            }
            previous = current
        }
        return Double(previous[actual.count]) / Double(expected.count)
    }

    private static func words(in value: String) -> [String] {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}
