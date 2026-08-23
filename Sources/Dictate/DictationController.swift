import AppKit
import Combine
import DictateCore
import Foundation

enum DeliveryNotice: Equatable {
    case inserted
    case textReady(DeliveryResult)
    case copied
}

@MainActor
final class DictationController: ObservableObject {
    @Published private(set) var state: DictationState = .idle
    @Published private(set) var liveText = ""
    @Published private(set) var inputLevel = 0.0
    @Published private(set) var lastFailure: DictationFailure?
    @Published private(set) var feedbackMessage = ""
    @Published private(set) var deliveryNotice: DeliveryNotice?
    @Published private(set) var pendingCopyText: String?

    var onCompleted: ((HistoryItem) -> Void)?
    @Published private(set) var parakeetModelStatus: RecognitionModelStatus = .notInstalled

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
    private var timeoutTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var sessionID: UUID?
    private var captureStarted = false
    private var stopRequested = false
    private var recovery = DeliveryRecoveryState()
    private var activeEntries: [DictionaryEntry] = []
    private var modelStatusCancellable: AnyCancellable?
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
        self.modelStatusCancellable = nil
        if let parakeet = parakeet as? ParakeetRecognitionService {
            parakeetModelStatus = parakeet.modelStatus
            modelStatusCancellable = parakeet.modelStatusPublisher.sink { [weak self] status in
                self?.parakeetModelStatus = status
            }
        } else {
            parakeetModelStatus = parakeet.modelStatus
        }
    }

    var speechModelAvailable: Bool { activeRecognition.modelIsAvailable }
    var activeModelStatus: RecognitionModelStatus { activeRecognition.modelStatus }
    private var activeRecognition: any SpeechRecognizing {
        provider == .parakeet ? parakeetRecognition : appleRecognition
    }

    func prepareParakeetModel() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do { try await self.parakeetRecognition.prepare() }
            catch { self.feedbackMessage = String(localized: "settings.parakeet.failed") }
        }
    }

    func removeParakeetModel() {
        guard let parakeet = parakeetRecognition as? ParakeetRecognitionService else { return }
        parakeet.removeDownloadedModel()
    }

    func start(entries: [DictionaryEntry], source: FocusCaptureSource = .mainWindow) {
        guard recovery.canStartNewSession else {
            feedbackMessage = String(localized: "recording.recoveryPending")
            deliveryNotice = .textReady(.copiedForRecovery)
            return
        }
        if case .failed = state { resetPublishedState() }
        guard case .idle = state else {
            feedbackMessage = String(localized: "recording.busy")
            return
        }

        activeEntries = entries
        lastFailure = nil
        liveText = ""
        inputLevel = 0
        feedbackMessage = ""
        deliveryNotice = nil
        noticeTask?.cancel()
        permissions.refresh()
        let recognition = activeRecognition
        let newSessionID = UUID()
        sessionID = newSessionID
        stopRequested = false
        captureStarted = false
        _ = machine.send(.startRequested)
        publish()

        // This must happen before any asynchronous model preparation or audio
        // start. If Dictate is frontmost, FocusSnapshotService keeps the last
        // valid external target instead of accidentally targeting its own UI.
        activeFocus = delivery.captureFocus(source: source)
        DictateLog.lifecycle.debug("dictation start source=\(source.rawValue, privacy: .public) provider=\(String(describing: self.provider), privacy: .public)")
        guard permissions.snapshot.microphone else { fail(.microphonePermissionDenied); return }
        if provider == .parakeet, !parakeetRecognition.modelIsAvailable {
            feedbackMessage = String(localized: "recording.parakeetNotReady")
            fail(.speechModelUnavailable)
            return
        }

        sessionTask = Task { @MainActor [weak self] in
            await self?.runSession(id: newSessionID, recognition: recognition, entries: entries)
        }
    }

    func finish() {
        guard state != .idle, !state.isFailed, state != .finalizing, state != .delivering else { return }
        DictateLog.lifecycle.debug("dictation finish requested state=\(String(describing: self.state), privacy: .public)")
        stopRequested = true
        _ = machine.send(.stopRequested)
        publish()
        if captureStarted { stopCapture() }
    }

    func rememberExternalFocus() {
        delivery.rememberExternalFocus()
    }

    func cancel() {
        guard state != .idle else { return }
        sessionID = nil
        stopRequested = true
        stopCapture()
        appleRecognition.cancel()
        parakeetRecognition.cancel()
        sessionTask?.cancel()
        sessionTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        noticeTask?.cancel()
        noticeTask = nil
        _ = machine.send(.cancel)
        resetPublishedState()
    }

    func retryInsertion(for item: HistoryItem) {
        let focus = delivery.captureFocus(source: .retry)
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await self.delivery.insert(item.correctedText, into: focus)
            self.recovery.resolve(item.correctedText, outcome: self.recoveryOutcome(for: result))
            self.pendingCopyText = self.recovery.text
            self.showDelivery(result)
        }
    }

    func copy(_ item: HistoryItem) {
        copyText(item.correctedText)
    }

    func copyPendingText() {
        guard let pendingCopyText else { return }
        copyText(pendingCopyText)
    }

    func discardPendingText() {
        recovery.clear()
        pendingCopyText = nil
        feedbackMessage = ""
        noticeTask?.cancel()
        noticeTask = nil
        deliveryNotice = nil
    }

    func updateInputLevel(_ level: Double) { inputLevel = min(max(level, 0), 1) }

    private func runSession(id: UUID, recognition: any SpeechRecognizing, entries: [DictionaryEntry]) async {
        do {
            try await recognition.prepare()
            guard isCurrent(id) else { return }

            let stream = try capture.start()
            captureStarted = true
            DictateLog.capture.debug("dictation audio capture active")
            _ = machine.send(.resourcesReady)
            _ = machine.send(.audioStarted)
            startedAt = .now
            publish()
            scheduleMaximumDuration(for: id)

            // If a hold was released while the model was preparing, begin the
            // stream only long enough to close it through the same finalization
            // path. This guarantees one stop and one final result.
            if stopRequested { stopCapture() }

            let vocabulary = VocabularySelector.select(entries: entries, context: "", limit: 24)
            let transcript = try await recognition.transcribe(stream: stream, contextualVocabulary: vocabulary) { [weak self] partial in
                guard let self, self.sessionID == id else { return }
                DictateLog.recognition.debug("partial received chars=\(partial.count, privacy: .public)")
                self.liveText = partial
                _ = self.machine.send(.partialText(partial, level: self.inputLevel))
                self.publish()
            } onLevel: { [weak self] level in
                guard let self, self.sessionID == id else { return }
                self.updateInputLevel(level)
            }
            guard isCurrent(id) else { return }
            DictateLog.recognition.debug("recognition completed chars=\(transcript.count, privacy: .public)")
            await finalize(transcript, id: id)
        } catch RecognitionError.cancelled {
            guard isCurrent(id) else { return }
            resetWithoutInsertion()
        } catch RecognitionError.onDeviceModelUnavailable {
            guard isCurrent(id) else { return }
            fail(.speechModelUnavailable)
        } catch CaptureError.noInput, CaptureError.unableToStart {
            guard isCurrent(id) else { return }
            fail(.captureUnavailable)
        } catch {
            guard isCurrent(id) else { return }
            DictateLog.recognition.error("recognition failed: \(String(describing: error), privacy: .public)")
            fail(.recognitionUnavailable)
        }
    }

    private func finalize(_ transcript: String, id: UUID) async {
        guard isCurrent(id) else { return }
        stopCapture()
        timeoutTask?.cancel()
        timeoutTask = nil
        let trimmed = TranscriptText.normalize(transcript)
        DictateLog.recognition.debug("final transcript chars=\(trimmed.count, privacy: .public)")
        guard !trimmed.isEmpty else {
            resetWithoutInsertion()
            return
        }

        if state == .listening || state.isTranscribing { _ = machine.send(.stopRequested) }
        _ = machine.send(.finalText(trimmed))
        publish()

        let result = matcher.apply(trimmed, entries: activeEntries)
        let insertion = await delivery.insert(result.correctedText, into: activeFocus)
        recovery.resolve(result.correctedText, outcome: recoveryOutcome(for: insertion))
        pendingCopyText = recovery.text
        let item = HistoryItem(
            timestamp: .now,
            originalTranscript: result.originalText,
            correctedText: result.correctedText,
            duration: startedAt.map { Date.now.timeIntervalSince($0) } ?? 0,
            insertionResult: historyResult(for: insertion),
            correctionAudit: result.audits
        )
        onCompleted?(item)

        switch insertion {
        case .insertedViaAccessibility, .insertedViaPaste:
            _ = machine.send(.insertionSucceeded)
            showDelivery(insertion)
        case .copiedForRecovery, .noTarget, .permissionMissing:
            _ = machine.send(.insertionSucceeded)
            feedbackMessage = ""
            showDelivery(insertion)
        case .deliveryFailed:
            // Recognition completed successfully. Delivery recovery is an
            // idle, actionable state rather than a failed recording session.
            _ = machine.send(.insertionSucceeded)
            showDelivery(insertion)
        }
        resetPublishedState()
    }

    private func fail(_ failure: DictationFailure) {
        DictateLog.lifecycle.error("dictation failed: \(failure.rawValue, privacy: .public)")
        sessionID = nil
        stopCapture()
        appleRecognition.cancel()
        parakeetRecognition.cancel()
        sessionTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        _ = machine.send(.failure(failure))
        lastFailure = failure
        publish()
    }

    private func resetWithoutInsertion() {
        sessionID = nil
        stopCapture()
        timeoutTask?.cancel()
        timeoutTask = nil
        _ = machine.send(.cancel)
        resetPublishedState()
    }

    private func resetPublishedState(keepFailure: Bool = false) {
        sessionTask = nil
        captureStarted = false
        stopRequested = false
        if !keepFailure { machine = DictationStateMachine() }
        state = keepFailure ? .failed(lastFailure ?? .insertionFailed) : machine.state
        if !keepFailure { lastFailure = nil }
        liveText = ""
        inputLevel = 0
        startedAt = nil
        activeFocus = nil
        publish()
    }

    private func stopCapture() {
        guard captureStarted else { return }
        capture.stop()
        captureStarted = false
        DictateLog.capture.debug("audio capture stopped")
    }

    private func scheduleMaximumDuration(for id: UUID) {
        timeoutTask?.cancel()
        timeoutTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000) }
            catch { return }
            guard let self, self.isCurrent(id), self.state != .idle else { return }
            self.fail(.sessionTimedOut)
        }
    }

    private func isCurrent(_ id: UUID) -> Bool { sessionID == id }

    private func historyResult(for result: DeliveryResult) -> InsertionResult {
        switch result {
        case .insertedViaAccessibility: return .insertedViaAccessibility
        case .insertedViaPaste: return .insertedViaPaste
        case .copiedForRecovery: return .copiedForRecovery
        case .noTarget: return .noTarget
        case .permissionMissing: return .permissionMissing
        case .deliveryFailed: return .deliveryFailed
        }
    }

    private func recoveryOutcome(for result: DeliveryResult) -> DeliveryRecoveryOutcome {
        switch result {
        case .insertedViaAccessibility, .insertedViaPaste: return .inserted
        case .copiedForRecovery, .noTarget: return .noTarget
        case .permissionMissing: return .permissionMissing
        case .deliveryFailed: return .deliveryFailed
        }
    }

    private func showDelivery(_ result: DeliveryResult) {
        switch result {
        case .insertedViaAccessibility, .insertedViaPaste:
            recovery.clear()
            pendingCopyText = nil
            // A successful insertion leaves no persistent overlay. The
            // recording indicator disappears as soon as finalization finishes.
            deliveryNotice = nil
            feedbackMessage = ""
            noticeTask?.cancel()
            noticeTask = nil
        case .copiedForRecovery, .noTarget, .permissionMissing, .deliveryFailed:
            deliveryNotice = .textReady(result)
            // Recovery remains visible until the user explicitly copies or
            // discards the text. It should never disappear under their cursor.
            noticeTask?.cancel()
            noticeTask = nil
        }
    }

    private func copyText(_ text: String) {
        noticeTask?.cancel()
        NSPasteboard.general.clearContents()
        _ = NSPasteboard.general.setString(text, forType: .string)
        recovery.clear()
        pendingCopyText = nil
        feedbackMessage = ""
        deliveryNotice = nil
    }

    private func publish() { state = machine.state }
}

private extension DictationState {
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    var isTranscribing: Bool {
        if case .transcribing = self { return true }
        return false
    }
}

// A small boundary keeps the AppKit focus implementation replaceable in tests.
@MainActor
final class FocusSnapshotService {
    private var preservedExternalFocus: FocusSnapshot?

    func rememberExternalFocus() {
        let current = FocusSnapshot.capture()
        if current.isUsableExternalTarget {
            preservedExternalFocus = current
            DictateLog.delivery.debug("preserved external focus target")
        } else if current.hasExternalApplication {
            preservedExternalFocus = nil
            DictateLog.delivery.debug("cleared preserved focus: external app has no editable target")
        }
    }

    func captureFocus(source: FocusCaptureSource) -> FocusSnapshot {
        let current = FocusSnapshot.capture()
        if current.hasExternalApplication && !current.isUsableExternalTarget {
            preservedExternalFocus = nil
            DictateLog.delivery.debug("focus target=invalid current external target; cleared preserved target")
        }
        let selection = FocusTargetResolver.select(
            source: source,
            currentIsUsable: current.isUsableExternalTarget,
            preservedIsUsable: preservedExternalFocus?.isUsableExternalTarget == true
        )
        switch selection {
        case .current:
            preservedExternalFocus = current
            DictateLog.delivery.debug("focus target=current source=\(source.rawValue, privacy: .public)")
            return current
        case .preserved:
            guard let preservedExternalFocus else { return current }
            DictateLog.delivery.debug("focus target=preserved source=\(source.rawValue, privacy: .public)")
            return preservedExternalFocus
        case .missing:
            DictateLog.delivery.debug("focus target=missing source=\(source.rawValue, privacy: .public)")
            return current
        }
    }

    func insert(_ text: String, into focus: FocusSnapshot?) async -> DeliveryResult {
        await (focus ?? FocusSnapshot.capture()).insert(text)
    }
}
