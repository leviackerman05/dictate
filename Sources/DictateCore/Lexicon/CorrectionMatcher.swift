import Foundation

/// Applies a single, non-recursive correction pass. Matching is case-insensitive,
/// boundary-aware, and treats whitespace, a hyphen, and no separator as equivalent
/// between words in a source phrase.
public struct CorrectionMatcher: Sendable {
    private struct Pattern: Sendable {
        let source: String
        let target: String
        let expression: NSRegularExpression
        let order: Int
    }

    public init() {}

    public func apply(_ text: String, entries: [DictionaryEntry]) -> CorrectionResult {
        guard !text.isEmpty else { return CorrectionResult(originalText: text, correctedText: text, audits: []) }

        let patterns = entries
            .filter { $0.isEnabled && $0.kind == .correction }
            .enumerated()
            .compactMap { offset, entry in makePattern(entry, offset: offset) }
            .sorted {
                if $0.source.count == $1.source.count { return $0.order < $1.order }
                return $0.source.count > $1.source.count
            }

        guard !patterns.isEmpty else { return CorrectionResult(originalText: text, correctedText: text, audits: []) }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var candidates: [(range: NSRange, replacement: String, source: String, order: Int)] = []
        for pattern in patterns {
            for match in pattern.expression.matches(in: text, range: fullRange) {
                candidates.append((match.range, pattern.target, pattern.source, pattern.order))
            }
        }

        // Pick the longest match at each position, then move left-to-right so
        // overlapping corrections cannot produce ambiguous output.
        candidates.sort {
            if $0.range.location == $1.range.location {
                if $0.range.length == $1.range.length { return $0.order < $1.order }
                return $0.range.length > $1.range.length
            }
            return $0.range.location < $1.range.location
        }
        var selected: [(range: NSRange, replacement: String, source: String)] = []
        var occupiedThrough = -1
        for candidate in candidates {
            guard candidate.range.location > occupiedThrough else { continue }
            selected.append((candidate.range, candidate.replacement, candidate.source))
            occupiedThrough = candidate.range.location + candidate.range.length - 1
        }

        var corrected = text
        var audits: [CorrectionAudit] = []
        for match in selected.reversed() {
            guard let swiftRange = Range(match.range, in: corrected) else { continue }
            let heard = String(corrected[swiftRange])
            corrected.replaceSubrange(swiftRange, with: match.replacement)
            audits.append(CorrectionAudit(heard: heard, written: match.replacement))
        }
        audits.reverse()
        return CorrectionResult(originalText: text, correctedText: corrected, audits: audits)
    }

    private func makePattern(_ entry: DictionaryEntry, offset: Int) -> Pattern? {
        guard let target = entry.targetPhrase?.trimmingCharacters(in: .whitespacesAndNewlines), !target.isEmpty else { return nil }
        let source = entry.sourcePhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return nil }

        let pieces = source.split { $0.isWhitespace || $0 == "-" }.map(String.init)
        guard !pieces.isEmpty else { return nil }
        let joined = pieces.map(NSRegularExpression.escapedPattern).joined(separator: "(?:\\s|[-])*" )
        let expressionText = "(?<![\\p{L}\\p{N}_])" + joined + "(?![\\p{L}\\p{N}_])"
        guard let expression = try? NSRegularExpression(pattern: expressionText, options: [.caseInsensitive]) else { return nil }
        return Pattern(source: source, target: target, expression: expression, order: offset)
    }
}

public enum VocabularySelector {
    public static func select(
        entries: [DictionaryEntry],
        context: String,
        limit: Int = 24
    ) -> [String] {
        let enabled = entries.filter { $0.isEnabled && $0.kind == .vocabulary }
        let foldedContext = context.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return enabled
            .map { entry -> (entry: DictionaryEntry, score: Int) in
                let folded = entry.sourcePhrase.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                let score: Int
                if foldedContext.contains(folded) { score = 1000 + folded.count }
                else if folded.split(separator: " ").contains(where: { foldedContext.contains($0) }) { score = 500 + folded.count }
                else { score = folded.count }
                return (entry, score)
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score { return lhs.entry.updatedAt > rhs.entry.updatedAt }
                return lhs.score > rhs.score
            }
            .prefix(max(0, limit))
            .map(\.entry.sourcePhrase)
    }
}
