import Foundation

@main
struct CoreSmoke {
    static func main() {
        let matcher = CorrectionMatcher()
        let corrections = [
            DictionaryEntry.correction(heard: "cloud code", written: "Claude Code"),
            DictionaryEntry.correction(heard: "go", written: "move")
        ]
        let cases = [
            ("cloud code", "Claude Code"),
            ("CloudCode and cloud-code", "Claude Code and Claude Code"),
            ("cloud codebase", "cloud codebase"),
            ("go go go", "move move move"),
            ("", "")
        ]
        for (input, expected) in cases {
            let actual = matcher.apply(input, entries: corrections).correctedText
            precondition(actual == expected, "Mismatch for \(input): \(actual)")
        }

        var machine = DictationStateMachine()
        for event in [
            DictationEvent.startRequested,
            .resourcesReady,
            .audioStarted,
            .partialText("hello", level: 0.4),
            .finalText("hello"),
            .insertionSucceeded
        ] { _ = machine.send(event) }
        precondition(machine.state == .idle)
        print("DictateCore smoke checks passed")
    }
}
