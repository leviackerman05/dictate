import AppKit
import Combine
import DictateCore
import FluidAudio
import Foundation

enum DeliveryNotice: Equatable {
    case textReady(DeliveryResult)
}

enum DictationReadiness: Equatable {
    case settingUp
    case ready
    case unavailable
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
    @Published private(set) var readiness: DictationReadiness = .settingUp

    var onCompleted: ((HistoryItem) -> Void)?
    /// Legacy accessor kept for the pre-multi-model UI; mirrors the v3 service.
    var parakeetModelStatus: RecognitionModelStatus { modelStatus(for: .parakeet) }

    private var machine = DictationStateMachine()
    private let capture: any AudioCapturing
    private let appleRecognition: any SpeechRecognizing
    private let injectedParakeet: (any SpeechRecognizing)?
    private let delivery: any FocusDelivering
    private let permissions: PermissionService
    private let matcher = CorrectionMatcher()
    private var activeFocus: FocusSnapshot?
    private var startedAt: Date?
    private var sessionTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var finalizationWatchdog: Task<Void, Never>?
    private var warmupTask: Task<Void, Never>?
    private var warmupID = UUID()
    private var sessionID: UUID?
    private var captureStarted = false
    private var stopRequested = false
    private var recovery = DeliveryRecoveryState()
    private var activeEntries: [DictionaryEntry] = []
    private var parakeetServices: [TranscriptionProvider: any SpeechRecognizing] = [:]
    private var whisperServices: [TranscriptionProvider: WhisperRecognitionService] = [:]
    /// Forwards each service's status changes through `objectWillChange` so
    /// SwiftUI views (including the legacy computed `parakeetModelStatus`)
    /// stay live.
    private var statusSubscriptions: [TranscriptionProvider: AnyCancellable] = [:]
    private(set) var provider: TranscriptionProvider = .apple

    init(
        capture: any AudioCapturing = AudioCaptureService(),
        recognition: any SpeechRecognizing = SpeechRecognitionService(),
        parakeet: any SpeechRecognizing = ParakeetRecognitionService(),
        delivery: any FocusDelivering = FocusSnapshotService(),
        permissions: PermissionService = PermissionService()
    ) {
        self.capture = capture
        self.appleRecognition = recognition
        self.injectedParakeet = parakeet
        self.delivery = delivery
        self.permissions = permissions
        // Eagerly create the v3 service so an already-downloaded model is
        // detected on launch, matching the previous eager service creation.
        _ = parakeetService(for: .parakeet)

        if let recoveredText = SessionRecoveryJournal.text {
            recovery = DeliveryRecoveryState(text: recoveredText)
            pendingCopyText = recoveredText
            deliveryNotice = .textReady(.copiedForRecovery)
        }
    }

    var speechModelAvailable: Bool { activeRecognition.modelIsAvailable }
    var activeModelStatus: RecognitionModelStatus { activeRecognition.modelStatus }
    private var activeRecognition: any SpeechRecognizing {
        recognitionService(for: provider)
    }

    // MARK: - Model management

    func selectProvider(_ provider: TranscriptionProvider) {
        self.provider = provider
        warmUpSelectedModel()
    }

    func warmUpSelectedModel() {
        warmupTask?.cancel()
        let id = UUID()
        warmupID = id
        let selectedProvider = provider
        let recognition = recognitionService(for: selectedProvider)
        readiness = .settingUp
        if state == .idle { feedbackMessage = "" }
        DictateLog.lifecycle.debug("model warm-up started provider=\(String(describing: selectedProvider), privacy: .public)")

        warmupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await recognition.prepare()
                guard !Task.isCancelled,
                      self.warmupID == id,
                      self.provider == selectedProvider else { return }
                self.readiness = .ready
                self.warmupTask = nil
                DictateLog.lifecycle.debug("model warm-up completed provider=\(String(describing: selectedProvider), privacy: .public)")
            } catch is CancellationError {
                // Provider changes deliberately cancel the superseded warm-up.
            } catch RecognitionError.cancelled {
                // Recognition services normalize cancellation to their own error.
            } catch {
                guard self.warmupID == id,
                      self.provider == selectedProvider else { return }
                self.readiness = .unavailable
                self.warmupTask = nil
                self.feedbackMessage = String(localized: "recording.modelSetupFailed")
                DictateLog.lifecycle.error("model warm-up failed provider=\(String(describing: selectedProvider), privacy: .public) error=\(String(describing: error), privacy: .public)")
            }
        }
    }

    func modelStatus(for provider: TranscriptionProvider) -> RecognitionModelStatus {
        provider == .apple ? .ready : recognitionService(for: provider).modelStatus
    }

    func prepareModel(for provider: TranscriptionProvider) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.provider == provider {
                self.readiness = .settingUp
            }
            do {
                try await self.recognitionService(for: provider).prepare()
                if self.provider == provider {
                    self.readiness = .ready
                }
            } catch {
                if self.provider == provider {
                    self.readiness = .unavailable
                }
                switch provider {
                case .parakeet, .parakeetV2, .parakeet110m:
                    self.feedbackMessage = String(localized: "settings.parakeet.failed")
                default:
                    // Whisper failures surface through modelStatus == .failed.
                    break
                }
            }
        }
    }

    func removeModel(for provider: TranscriptionProvider) {
        if self.provider == provider {
            warmupTask?.cancel()
            warmupTask = nil
            warmupID = UUID()
            readiness = .unavailable
            feedbackMessage = String(localized: "recording.modelNotReady")
        }
        switch provider {
        case .apple:
            return
        case .parakeet, .parakeetV2, .parakeet110m:
            (recognitionService(for: provider) as? ParakeetRecognitionService)?.removeDownloadedModel()
        case .whisperTiny, .whisperBase, .whisperSmall, .whisperMedium, .whisperLargeV3Turbo:
            (recognitionService(for: provider) as? WhisperRecognitionService)?.removeDownloadedModel()
        }
    }

    func refreshModelStatuses() {
        for provider in TranscriptionProvider.allCases where provider != .apple {
            let service = recognitionService(for: provider)
            if let parakeet = service as? ParakeetRecognitionService {
                parakeet.refreshStatus()
            } else if let whisper = service as? WhisperRecognitionService {
                whisper.refreshStatus()
            }
        }
    }

    private func recognitionService(for provider: TranscriptionProvider) -> any SpeechRecognizing {
        switch provider {
        case .apple:
            return appleRecognition
        case .parakeet, .parakeetV2, .parakeet110m:
            return parakeetService(for: provider)
        case .whisperTiny, .whisperBase, .whisperSmall, .whisperMedium, .whisperLargeV3Turbo:
            return whisperService(for: provider)
        }
    }

    private func parakeetService(for provider: TranscriptionProvider) -> any SpeechRecognizing {
        if let existing = parakeetServices[provider] { return existing }
        let service: any SpeechRecognizing
        if provider == .parakeet, let injected = injectedParakeet {
            service = injected
        } else {
            let version: AsrModelVersion
            switch provider {
            case .parakeet: version = .v3
            case .parakeetV2: version = .v2
            case .parakeet110m: version = .tdtCtc110m
            default: version = .v3
            }
            service = ParakeetRecognitionService(modelVersion: version)
        }
        parakeetServices[provider] = service
        if let parakeet = service as? ParakeetRecognitionService {
            statusSubscriptions[provider] = parakeet.modelStatusPublisher.sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        }
        return service
    }

    private func whisperService(for provider: TranscriptionProvider) -> WhisperRecognitionService {
        if let existing = whisperServices[provider] { return existing }
        guard let variant = provider.whisperVariant else {
            preconditionFailure("Whisper providers must carry a WhisperKit variant")
        }
        let service = WhisperRecognitionService(variant: variant)
        whisperServices[provider] = service
        statusSubscriptions[provider] = service.modelStatusPublisher.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        return service
    }

    func prepareParakeetModel() {
        prepareModel(for: .parakeet)
    }

    func removeParakeetModel() {
        removeModel(for: .parakeet)
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
        guard readiness == .ready else {
            feedbackMessage = String(localized: readiness == .settingUp ? "recording.settingUp" : "recording.modelSetupFailed")
            if readiness == .unavailable { warmUpSelectedModel() }
            return
        }

        activeEntries = entries
        lastFailure = nil
        liveText = ""
        inputLevel = 0
        feedbackMessage = ""
        deliveryNotice = nil
        SessionRecoveryJournal.clear()
        noticeTask?.cancel()
        permissions.refresh()
        let recognition = activeRecognition
        let newSessionID = UUID()

        // Capture the external cursor before publishing any recording state.
        // Publishing shows the floating Dictate panel; even though that panel
        // is non-activating, some accessibility stacks transiently report it
        // while the window is being ordered onscreen.
        activeFocus = delivery.captureFocus(source: source)

        sessionID = newSessionID
        stopRequested = false
        captureStarted = false
        _ = machine.send(.startRequested)
        publish()
        DictateLog.lifecycle.debug("dictation start source=\(source.rawValue, privacy: .public) provider=\(String(describing: self.provider), privacy: .public)")
        guard permissions.snapshot.microphone else { fail(.microphonePermissionDenied); return }
        sessionTask = Task { @MainActor [weak self] in
            await self?.runSession(id: newSessionID, recognition: recognition, entries: entries)
        }
    }

    func finish() {
        guard state != .idle, !state.isFailed, state != .finalizing, state != .delivering else { return }
        DictateLog.lifecycle.debug("dictation finish requested state=\(String(describing: self.state), privacy: .public)")

        // A press released before audio capture begins is an accidental/empty
        // gesture. Cancel it immediately instead of waiting for model setup,
        // starting the microphone briefly, and only then returning to idle.
        if state == .preparing, !captureStarted {
            cancel()
            return
        }

        stopRequested = true
        _ = machine.send(.stopRequested)
        publish()
        if captureStarted { stopCapture() }
        armFinalizationWatchdog()
    }

    func rememberExternalFocus() {
        delivery.rememberExternalFocus()
    }

    func cancel() {
        guard state != .idle else { return }
        // Preserve whatever has already been transcribed even if cancellation
        // arrives during finalization, after the microphone has stopped.
        let retainedRecovery = preserveLiveTextForRecovery()
        sessionID = nil
        stopRequested = true
        stopCapture()
        appleRecognition.cancel()
        for service in parakeetServices.values { service.cancel() }
        for service in whisperServices.values { service.cancel() }
        sessionTask?.cancel()
        sessionTask = nil
        noticeTask?.cancel()
        noticeTask = nil
        finalizationWatchdog?.cancel()
        finalizationWatchdog = nil
        _ = machine.send(.cancel)
        resetPublishedState()
        if retainedRecovery { showRecoveryNotice(.copiedForRecovery) }
    }

    func retryInsertion(for item: HistoryItem) {
        let focus = delivery.captureFocus(source: .retry)
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await self.delivery.insert(item.correctedText, into: focus)
            self.recovery.resolve(item.correctedText, outcome: self.recoveryOutcome(for: result))
            self.pendingCopyText = self.recovery.text
            self.syncRecoveryJournal()
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
        SessionRecoveryJournal.clear()
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
            // If a hold was released while the model was preparing, begin the
            // stream only long enough to close it through the same finalization
            // path. This guarantees one stop and one final result.
            if stopRequested { stopCapture() }

            let vocabulary = VocabularySelector.select(entries: entries, context: "", limit: 24)
            let transcript = try await recognition.transcribe(stream: stream, contextualVocabulary: vocabulary) { [weak self] partial in
                guard let self, self.sessionID == id else { return }
                DictateLog.recognition.debug("partial received chars=\(partial.count, privacy: .public)")
                self.liveText = partial
                self.persistPartialTranscript(partial)
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
        // Commit the completed text before attempting AppKit delivery. If the
        // app exits while the paste is being dispatched, the text is still
        // available to copy on the next launch.
        SessionRecoveryJournal.save(result.correctedText)
        // The destination is the explicitly focused editor when recognition
        // finishes, not necessarily the editor that was focused when the
        // shortcut went down. This lets a user begin speaking in one app and
        // deliberately move to another field before release. captureFocus
        // still applies the click-away guard, so an abandoned last responder
        // cannot become an implicit destination.
        let completionFocus = delivery.captureFocus(source: .completion)
        let insertion = await delivery.insert(result.correctedText, into: completionFocus)
        recovery.resolve(result.correctedText, outcome: recoveryOutcome(for: insertion))
        pendingCopyText = recovery.text
        syncRecoveryJournal()
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
        if failure == .speechModelUnavailable {
            readiness = .unavailable
        }
        let retainedRecovery = preserveLiveTextForRecovery()
        sessionID = nil
        stopCapture()
        appleRecognition.cancel()
        for service in parakeetServices.values { service.cancel() }
        for service in whisperServices.values { service.cancel() }
        sessionTask = nil
        _ = machine.send(.failure(failure))
        if retainedRecovery {
            resetPublishedState()
            showRecoveryNotice(.deliveryFailed)
        } else {
            lastFailure = failure
            publish()
        }
    }

    func transcribeAudioFile(at url: URL, entries: [DictionaryEntry]) async throws -> String {
        let stream = try AudioFileStreamService.makeStream(from: url)
        let vocabulary = entries
            .filter(\.isEnabled)
            .flatMap { [$0.sourcePhrase, $0.targetPhrase].compactMap { $0 } }
        let transcript = try await activeRecognition.transcribe(
            stream: stream,
            contextualVocabulary: vocabulary,
            onPartial: { _ in },
            onLevel: { _ in }
        )
        return TranscriptText.normalize(transcript)
    }

    private func resetWithoutInsertion() {
        let retainedRecovery = preserveLiveTextForRecovery()
        sessionID = nil
        stopCapture()
        _ = machine.send(.cancel)
        resetPublishedState()
        if retainedRecovery { showRecoveryNotice(.deliveryFailed) }
    }

    private func resetPublishedState(keepFailure: Bool = false) {
        finalizationWatchdog?.cancel()
        finalizationWatchdog = nil
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

    private func armFinalizationWatchdog() {
        finalizationWatchdog?.cancel()
        let expectedSessionID = sessionID
        let timeout: Duration = provider == .apple ? .seconds(12) : .seconds(45)
        finalizationWatchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled,
                  let self,
                  self.sessionID == expectedSessionID,
                  self.state == .finalizing || self.state == .delivering else { return }
            DictateLog.lifecycle.error("dictation finalization timed out")
            self.cancel()
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
            SessionRecoveryJournal.clear()
            pendingCopyText = nil
            // Successful insertion returns directly to the quiet, ready
            // pebble. The recorder-sized processing surface must not linger.
            deliveryNotice = nil
            feedbackMessage = ""
            noticeTask?.cancel()
            noticeTask = nil
        case .copiedForRecovery, .noTarget, .permissionMissing, .deliveryFailed:
            syncRecoveryJournal()
            deliveryNotice = .textReady(result)
            // Recovery remains visible until the user explicitly copies or
            // discards the text. It should never disappear under their cursor.
            noticeTask?.cancel()
            noticeTask = nil
        }
    }

    private func copyText(_ text: String) {
        noticeTask?.cancel()
        noticeTask = nil
        NSPasteboard.general.clearContents()
        _ = NSPasteboard.general.setString(text, forType: .string)
        recovery.clear()
        SessionRecoveryJournal.clear()
        pendingCopyText = nil
        feedbackMessage = ""
        // Copy is the end of the recovery flow. Return immediately to the
        // same quiet placeholder used before recording instead of leaving a
        // second transient overlay on screen.
        deliveryNotice = nil
    }

    private func publish() { state = machine.state }

    private func persistPartialTranscript(_ partial: String) {
        let normalized = TranscriptText.normalize(partial)
        guard !normalized.isEmpty else { return }
        SessionRecoveryJournal.save(normalized)
    }

    @discardableResult
    private func preserveLiveTextForRecovery() -> Bool {
        let candidate = TranscriptText.normalize(liveText)
        let value = candidate.isEmpty ? SessionRecoveryJournal.text : candidate
        guard let value, !value.isEmpty else { return false }
        recovery.resolve(value, outcome: .deliveryFailed)
        pendingCopyText = recovery.text
        SessionRecoveryJournal.save(value)
        return true
    }

    private func syncRecoveryJournal() {
        if let text = recovery.text {
            SessionRecoveryJournal.save(text)
        } else {
            SessionRecoveryJournal.clear()
        }
    }

    private func showRecoveryNotice(_ result: DeliveryResult) {
        pendingCopyText = recovery.text
        guard pendingCopyText != nil else { return }
        deliveryNotice = .textReady(result)
        feedbackMessage = ""
        noticeTask?.cancel()
        noticeTask = nil
    }
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
    private var intentTracker = FocusIntentTracker()
    private var activeIntent: FocusIntentCapture?

    /// Most recent mouse-down observed in ANOTHER process, with the frame of
    /// the element that held AX focus at that moment. Global monitors never
    /// observe Dictate's own windows, so overlay/retry clicks are not seen.
    private var lastExternalClick: (location: CGPoint, date: Date, focusedFrameAtClick: CGRect?, processIdentifier: pid_t?)?
    private var lastAccessibilityFocusChange: (date: Date, fingerprint: FocusTargetFingerprint?)?
    /// Installed once in init and kept for the lifetime of the app, matching
    /// AppDelegate's escape monitor. Mouse-only global monitors require no
    /// permissions, and the service lives as long as the process, so it is
    /// never removed.
    private var externalClickMonitor: Any?
    private var externalPointerTap: ExternalPointerEventTap?
    private var axObserver: AXObserver?
    private var axObserverSource: CFRunLoopSource?
    private var observedProcessIdentifier: pid_t?

    init() {
        let pointerTap = ExternalPointerEventTap { [weak self] location, sourcePID in
            guard sourcePID != ProcessInfo.processInfo.processIdentifier else { return }
            Task { @MainActor [weak self] in
                self?.recordExternalClick(at: location)
            }
        }
        if pointerTap.start() {
            externalPointerTap = pointerTap
        } else {
            externalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let location = event.cgEvent?.location else { return }
                Task { @MainActor [weak self] in self?.recordExternalClick(at: location) }
            }
        }
    }

    private func recordExternalClick(at location: CGPoint) {
        intentTracker.pointerDown(at: location)
        lastExternalClick = (
            location: location,
            date: Date(),
            focusedFrameAtClick: FocusSnapshot.frameOfSystemFocusedElement(),
            processIdentifier: NSWorkspace.shared.frontmostApplication?.processIdentifier
        )
    }

    func rememberExternalFocus() {
        let current = FocusSnapshot.capture(hitTestLocation: currentHitTestLocation)
        if current.isUsableExternalTarget {
            preservedExternalFocus = current
            if let fingerprint = current.focusFingerprint {
                intentTracker.focusChanged(to: fingerprint)
            }
            DictateLog.delivery.debug("preserved external focus target")
        } else if current.hasExternalApplication {
            preservedExternalFocus = nil
            intentTracker.invalidate()
            DictateLog.delivery.debug("cleared preserved focus: external app has no editable target")
        }
    }

    func captureFocus(source: FocusCaptureSource) -> FocusSnapshot {
        let current = FocusSnapshot.capture(hitTestLocation: currentHitTestLocation)
        let currentHasIntent = current.isUsableExternalTarget && hasPositiveFocusIntent(for: current)
        if current.hasExternalApplication && !currentHasIntent {
            preservedExternalFocus = nil
            DictateLog.delivery.debug("focus target=invalid or abandoned current target; cleared preserved target")
        }
        let selection = FocusTargetResolver.select(
            source: source,
            currentIsUsable: currentHasIntent,
            preservedIsUsable: preservedExternalFocus?.isUsableExternalTarget == true
        )
        switch selection {
        case .current:
            preservedExternalFocus = current
            activeIntent = current.focusFingerprint.map { intentTracker.begin($0) }
            observeAccessibility(for: current)
            DictateLog.delivery.debug("focus target=current source=\(source.rawValue, privacy: .public)")
            return current
        case .preserved:
            // Preserved targets are retained for diagnostics and recovery only;
            // they are never valid insertion destinations for a new session.
            intentTracker.invalidate()
            activeIntent = nil
            return current
        case .missing:
            intentTracker.invalidate()
            activeIntent = nil
            DictateLog.delivery.debug("focus target=missing source=\(source.rawValue, privacy: .public)")
            return current
        }
    }

    func insert(_ text: String, into focus: FocusSnapshot?) async -> DeliveryResult {
        let snapshot = focus ?? FocusSnapshot.capture()
        // Opaque custom editors need the most recent pointer hit to recreate
        // their guarded window target. Concrete AX editors ignore this value.
        let current = FocusSnapshot.capture(hitTestLocation: currentHitTestLocation)
        guard let activeIntent,
              let currentFingerprint = current.focusFingerprint,
              intentTracker.allows(activeIntent, current: currentFingerprint),
              current.focusFingerprint == snapshot.focusFingerprint else {
            DictateLog.delivery.debug("insert skipped: focus intent changed before delivery")
            return .noTarget
        }
        // The snapshot's own AX-based check cannot see clicks on controls
        // that never take focus: AppKit/Electron leave both the system-wide
        // AX focus and the window first responder on the old field. The
        // click tracker covers that case.
        if clickAbandonsTarget(snapshot) {
            DictateLog.delivery.debug("insert skipped: target abandoned by click away")
            return .noTarget
        }
        return await snapshot.insert(text)
    }

    /// Pure decision, no AppKit state: has an external click abandoned the
    /// captured target?
    ///
    /// - A click inside the captured editor's frame (plus 8pt margin) never
    ///   abandons the target; it is part of using that editor.
    /// - A click outside the frame DURING the recording session abandons it.
    /// - A click outside the frame shortly (≤10s) BEFORE capture abandons it
    ///   only when the element focused at click time is the captured element
    ///   (the click landed on a non-focusable control and focus never moved).
    ///   Unknown click-time focus is treated conservatively as abandonment.
    private func clickAbandonsTarget(_ snapshot: FocusSnapshot) -> Bool {
        guard let click = lastExternalClick,
              click.processIdentifier == snapshot.externalProcessIdentifier else { return false }
        let focusRestoredAfterClick = lastAccessibilityFocusChange.map {
            $0.date > click.date && $0.fingerprint == snapshot.focusFingerprint
        } ?? false
        return FocusClickIntentPolicy.abandonsTarget(
            sameProcess: true,
            clickTime: click.date.timeIntervalSinceReferenceDate,
            captureTime: snapshot.capturedAt.timeIntervalSinceReferenceDate,
            clickLocation: click.location,
            capturedFrame: snapshot.frame,
            hitTestConfirmedTarget: snapshot.wasConfirmedByHitTest(at: click.location),
            focusRestoredAfterClick: focusRestoredAfterClick
        )
    }

    private func hasPositiveFocusIntent(for snapshot: FocusSnapshot) -> Bool {
        !clickAbandonsTarget(snapshot)
    }

    private var currentHitTestLocation: CGPoint? {
        guard let click = lastExternalClick,
              click.processIdentifier == NSWorkspace.shared.frontmostApplication?.processIdentifier,
              Date().timeIntervalSince(click.date) <= 10 else { return nil }
        return click.location
    }

    /// Frame equality with a 2pt tolerance on each edge, for comparing AX
    /// geometry read at different moments.
    private static func framesNearlyEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) <= 2.0 &&
            abs(lhs.origin.y - rhs.origin.y) <= 2.0 &&
            abs(lhs.size.width - rhs.size.width) <= 2.0 &&
            abs(lhs.size.height - rhs.size.height) <= 2.0
    }

    private func observeAccessibility(for snapshot: FocusSnapshot) {
        guard let processIdentifier = snapshot.externalProcessIdentifier,
              processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        guard observedProcessIdentifier != processIdentifier else { return }
        removeAccessibilityObserver()
        guard AXIsProcessTrusted() else { return }

        let application = AXUIElementCreateApplication(processIdentifier)
        var created: AXObserver?
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard AXObserverCreate(processIdentifier, { _, _, notification, refcon in
            guard let refcon else { return }
            let service = Unmanaged<FocusSnapshotService>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated {
                service.handleAccessibilityNotification(notification)
            }
        }, &created) == .success,
              let created else { return }
        let notifications = [
            kAXFocusedUIElementChangedNotification,
            kAXFocusedWindowChangedNotification
        ]
        for notification in notifications {
            _ = AXObserverAddNotification(created, application, notification as CFString, context)
        }
        let source = AXObserverGetRunLoopSource(created)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        axObserverSource = source
        axObserver = created
        observedProcessIdentifier = processIdentifier
        DictateLog.delivery.debug("AX focus observer installed pid=\(processIdentifier, privacy: .public)")
    }

    private func removeAccessibilityObserver() {
        if let source = axObserverSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        axObserverSource = nil
        axObserver = nil
        observedProcessIdentifier = nil
    }

    private func handleAccessibilityNotification(_ notification: CFString) {
        let name = notification as String
        guard name == kAXFocusedUIElementChangedNotification || name == kAXFocusedWindowChangedNotification else { return }
        let current = FocusSnapshot.capture()
        lastAccessibilityFocusChange = (Date(), current.focusFingerprint)
        intentTracker.focusChanged(to: current.focusFingerprint)
        if current.isUsableExternalTarget { preservedExternalFocus = current }
        DictateLog.delivery.debug("AX focus intent updated notification=\(notification, privacy: .public) target=\(current.focusFingerprint != nil, privacy: .public)")
    }
}

private final class ExternalPointerEventTap: @unchecked Sendable {
    private let onMouseDown: @Sendable (CGPoint, pid_t) -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    init(onMouseDown: @escaping @Sendable (CGPoint, pid_t) -> Void) {
        self.onMouseDown = onMouseDown
    }

    func start() -> Bool {
        let mask = (CGEventMask(1) << CGEventType.leftMouseDown.rawValue) |
            (CGEventMask(1) << CGEventType.rightMouseDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<ExternalPointerEventTap>.fromOpaque(refcon).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = owner.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                    return Unmanaged.passUnretained(event)
                }
                let sourcePID = pid_t(event.getIntegerValueField(.eventSourceUnixProcessID))
                owner.onMouseDown(event.location, sourcePID)
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else { return false }
        self.tap = tap
        guard let source = CFMachPortCreateRunLoopSource(nil, tap, 0) else {
            CGEvent.tapEnable(tap: tap, enable: false)
            self.tap = nil
            return false
        }
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }
}
