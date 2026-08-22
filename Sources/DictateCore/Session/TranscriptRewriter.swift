import Foundation

public protocol TranscriptRewriter: Sendable {
    func rewrite(_ text: String) async throws -> String
}

public struct NoOpTranscriptRewriter: TranscriptRewriter {
    public init() {}

    public func rewrite(_ text: String) async throws -> String { text }
}
