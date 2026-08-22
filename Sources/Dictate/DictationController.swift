import AppKit
import DictateCore
import Foundation

@MainActor
final class DictationController: ObservableObject {
    @Published private(set) var state: DictationState = .idle
    @Published private(set) var liveText = ""
    @Published private(set) var inputLevel = 0.0
    @Published private(set) var lastFailure: DictationFailure?
    @Published private(set) var feedbackMessage = ""

    var onCompleted: ((HistoryItem) -> Void)?

    private var machine = DictationStateMachine()
    private let capture: any AudioCapturing
    private let appleRecognition: any SpeechRecognizing
    private let parakeetRecognition: any SpeechRecognizing
    private let delivery: any FocusDelivering
    private let permissions: PermissionService
    private let matcher = CorrectionMatcher()
    private var activeFocus: FocusSnapshot?
    private var startedAt: Date?
    private var sessionTask: Task<Void, Never>?
    private var activeEntries: [DictionaryEntry] = []
    var provider: TranscriptionProvider = .apple

    init(
        capture: any AudioCapturing = AudioCaptureService(),
        recognition: any SpeechRecognizing = SpeechRecognitionService(),
        parakeet: any SpeechRecognizing = ParakeetRecognitionService(),
        delivery: any FocusDelivering = FocusSnapshotService(),
        permissions: PermissionService = PermissionService()
    ) {
        self.capture = capture
        self.appleRecognition = recognition
        self.parakeetRecognition = parakeet
        self.delivery = delivery
        self.permissions = permissions
    }

    var speechModelAvailable: Bool { activeRecognition.modelIsAvailable }

    private var activeRecognition: any SpeechRecognizing {
        provider == .parakeet ? parakeetRecognition : appleRecognition
    }

    func start(entries: [DictionaryEntry]) {
        guard case .idle = state else {
            feedbackMessage = String(localized: "recording.busy")
            return
        }
        activeEntries = entries
        lastFailure = nil
        liveText = ""
        feedbackMessage = ""
        permissions.refresh()
        let recognition = activeRecognition
        DictateLog.lifecycle.debug("recording requested mic=\(self.permissions.snapshot.microphone) provider=\(self.provider.rawValue, privacy: .public) model=\(recognition.modelIsAvailable)")
        _ = machine.send(.startRequested)
        publish()
        DictateLog.lifecycle.debug("dictation session preparing")
        activeFocus = delivery.captureFocus()
        guard permissions.snapshot.microphone else { fail(.microphonePermissionDenied); return }
        guard recognition.modelIsAvailable else { fail(.speechModelUnavailable); return }
        _ = machine.send(.resourcesReady)
        do {
            let stream = try capture.start()
            _ = machine.send(.audioStarted)
            DictateLog.capture.debug("audio capture started")
            startedAt = .now
            publish()
            sessionTask = Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let vocabulary = VocabularySelector.select(entries: entries, context: "", limit: 24)
                    let transcript = try await recognition.transcribe(stream: stream, contextualVocabulary: vocabulary) { [weak self] partial in
                        guard let self else { return }
                        self.liveText = partial
                        _ = self.machine.send(.partialText(partial, level: self.inputLevel))
                        self.publish()
                    } onLevel: { [weak self] level in self?.updateInputLevel(level) }
                    self.finish(transcript)
                } catch RecognitionError.cancelled {
                    self.resetWithoutInsertion()
                } catch {
                    DictateLog.recognition.error("recognition failed: \(String(describing: error), privacy: .public)")
                    self.fail(.recognitionUnavailable)
                }
            }
        } catch {
            DictateLog.capture.error("audio capture failed: \(String(describing: error), privacy: .public)")
            fail(.captureUnavailable)
        }
    }

    func finish() {
        guard state == .listening || state.isTranscribing else { return }
        capture.stop()
        DictateLog.capture.debug("audio capture stopped")
    }

    func cancel() {
        guard state != .idle else { return }
        capture.stop()
        appleRecognition.cancel()
        parakeetRecognition.cancel()
        sessionTask?.cancel()
        sessionTask = nil
        _ = machine.send(.cancel)
        resetPublishedState()
    }

    func retryInsertion(for item: HistoryItem) {
        let result = delivery.insert(item.correctedText, into: delivery.captureFocus(), allowAutomaticInsertion: permissions.snapshot.accessibility)
        feedbackMessage = result == .inserted ? String(localized: "recording.inserted") : String(localized: "recording.copiedOnly")
    }

    func copy(_ item: HistoryItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.correctedText, forType: .string)
    }

    func updateInputLevel(_ level: Double) { inputLevel = min(max(level, 0), 1) }

    private func finish(_ transcript: String) {
        capture.stop()
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            resetWithoutInsertion()
            return
        }
        let result = matcher.apply(trimmed, entries: activeEntries)
        _ = machine.send(.finalText(result.correctedText))
        publish()
        let insertion = delivery.insert(result.correctedText, into: activeFocus, allowAutomaticInsertion: permissions.snapshot.accessibility)
        let item = HistoryItem(
            timestamp: .now,
            originalTranscript: result.originalText,
            correctedText: result.correctedText,
            duration: startedAt.map { Date.now.timeIntervalSince($0) } ?? 0,
            insertionResult: insertion == .inserted ? .inserted : insertion == .copiedOnly ? .copiedOnly : .failed,
            correctionAudit: result.audits
        )
        onCompleted?(item)
        if insertion == .inserted {
            DictateLog.delivery.debug("text delivery completed")
            _ = machine.send(.insertionSucceeded)
        } else if insertion == .copiedOnly {
            feedbackMessage = String(localized: "recording.copiedOnly")
            _ = machine.send(.insertionSucceeded)
        } else {
            _ = machine.send(.insertionFailed)
            lastFailure = .insertionFailed
        }
        resetPublishedState(keepFailure: insertion == .failed)
    }

    private func fail(_ failure: DictationFailure) {
        DictateLog.lifecycle.error("dictation failed: \(failure.rawValue, privacy: .public)")
        capture.stop()
        appleRecognition.cancel()
        parakeetRecognition.cancel()
        _ = machine.send(.failure(failure))
        lastFailure = failure
        publish()
    }

    private func resetWithoutInsertion() {
        _ = machine.send(.cancel)
        resetPublishedState()
    }

    private func resetPublishedState(keepFailure: Bool = false) {
        state = keepFailure ? .failed(lastFailure ?? .insertionFailed) : .idle
        if !keepFailure { lastFailure = nil }
        liveText = ""
        inputLevel = 0
        startedAt = nil
        activeFocus = nil
        publish()
    }

    private func publish() { state = machine.state }
}

private extension DictationState {
    var isTranscribing: Bool {
        if case .transcribing = self { return true }
        return false
    }
}

// A small boundary keeps the AppKit focus implementation replaceable in tests.
@MainActor
final class FocusSnapshotService {
    func captureFocus() -> FocusSnapshot { FocusSnapshot.capture() }
    func insert(_ text: String, into focus: FocusSnapshot?, allowAutomaticInsertion: Bool) -> DeliveryResult {
        guard allowAutomaticInsertion else {
            return (focus ?? FocusSnapshot.capture()).copyOnly(text)
        }
        return (focus ?? FocusSnapshot.capture()).insert(text)
    }
}
