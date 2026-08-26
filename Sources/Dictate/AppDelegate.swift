import AppKit
import Combine
import DictateCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var menuBar: MenuBarController?
    private var overlay: RecordingOverlayController?
    private var shortcutMonitor: ShortcutMonitor?
    private var stateCancellable: AnyCancellable?
    private var shortcutCancellable: AnyCancellable?
    private var recordingModeCancellable: AnyCancellable?
    private var readyIndicatorCancellable: AnyCancellable?
    private var readinessCancellable: AnyCancellable?
    private var noticeCancellables = Set<AnyCancellable>()
    private var escapeMonitor: Any?
    private var activeObserver: NSObjectProtocol?
    private var externalFocusObserver: NSObjectProtocol?
    private var workspaceFocusObserver: NSObjectProtocol?

    func applicationWillFinishLaunching(_ notification: Notification) {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        if let existing = Bundle.main.bundleIdentifier.flatMap({ bundleID in
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .first(where: { $0.processIdentifier != currentPID && !$0.isTerminated })
        }) {
            existing.activate(options: [.activateAllWindows])
            NSApp.terminate(nil)
        }
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        // Capture synchronously, before Dictate's own window/button becomes the
        // Accessibility focus. This is the target used when recording starts
        // from the main window instead of the global shortcut.
        model.rememberExternalFocus()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        model.applyAppearance()
        menuBar = MenuBarController(model: model)
        overlay = RecordingOverlayController(controller: model.dictation, shortcutTitle: shortcutTitle)
        shortcutMonitor = ShortcutMonitor()
        configureShortcutMonitor(
            choice: model.shortcut,
            custom: model.customShortcut,
            recordingMode: model.recordingMode
        )
        stateCancellable = model.dictation.$state.sink { [weak self] state in
            guard let self else { return }
            self.overlay?.update(state: state, notice: self.model.dictation.deliveryNotice, showReadyIndicator: self.model.showReadyIndicator)
            self.menuBar?.update(state: state)
            self.shortcutMonitor?.update(session: state)
        }
        model.dictation.$deliveryNotice.sink { [weak self] notice in
            guard let self else { return }
            self.overlay?.update(state: self.model.dictation.state, notice: notice, showReadyIndicator: self.model.showReadyIndicator)
        }.store(in: &noticeCancellables)
        readinessCancellable = model.dictation.$readiness.sink { [weak self] _ in
            guard let self else { return }
            self.overlay?.update(
                state: self.model.dictation.state,
                notice: self.model.dictation.deliveryNotice,
                showReadyIndicator: self.model.showReadyIndicator
            )
            self.menuBar?.update(state: self.model.dictation.state)
        }
        shortcutCancellable = model.$shortcut.combineLatest(model.$customShortcut).sink { [weak self] choice, custom in
            guard let self else { return }
            self.overlay?.updateShortcutTitle(self.shortcutTitle(choice: choice, custom: custom))
            self.configureShortcutMonitor(
                choice: choice,
                custom: custom,
                recordingMode: self.model.recordingMode
            )
        }
        recordingModeCancellable = model.$recordingMode.sink { [weak self] recordingMode in
            guard let self else { return }
            self.configureShortcutMonitor(
                choice: self.model.shortcut,
                custom: self.model.customShortcut,
                recordingMode: recordingMode
            )
        }
        readyIndicatorCancellable = model.$showReadyIndicator.sink { [weak self] show in
            guard let self else { return }
            self.overlay?.update(state: self.model.dictation.state, notice: self.model.dictation.deliveryNotice, showReadyIndicator: show)
        }
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            Task { @MainActor in self?.model.cancelRecording() }
        }
        localEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            Task { @MainActor [weak self] in self?.model.cancelRecording() }
            return nil
        }
        activeObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.model.permissions.refresh() }
        }
        externalFocusObserver = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.model.rememberExternalFocus() }
        }
        workspaceFocusObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.model.rememberExternalFocus() }
        }
        overlay?.update(state: model.dictation.state, notice: model.dictation.deliveryNotice, showReadyIndicator: model.showReadyIndicator)
        model.rememberExternalFocus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutMonitor?.stop()
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        if let localEscapeMonitor { NSEvent.removeMonitor(localEscapeMonitor) }
        if let activeObserver { NotificationCenter.default.removeObserver(activeObserver) }
        if let externalFocusObserver { NotificationCenter.default.removeObserver(externalFocusObserver) }
        if let workspaceFocusObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceFocusObserver) }
        readyIndicatorCancellable = nil
        readinessCancellable = nil
    }

    private func configureShortcutMonitor(
        choice: ShortcutChoice,
        custom: RecordedShortcut?,
        recordingMode: RecordingMode
    ) {
        shortcutMonitor?.start(choice: choice, custom: custom, recordingMode: recordingMode) { [weak self] action in
            guard let self else { return }
            switch action {
            case .start:
                guard self.model.dictation.state == .idle || self.model.dictation.lastFailure != nil else { return }
                self.model.startRecording(source: .globalShortcut)
            case .requestStop:
                self.model.finishRecording()
            case .none:
                break
            }
        }
        shortcutMonitor?.update(session: model.dictation.state)
    }

    private var shortcutTitle: String {
        shortcutTitle(choice: model.shortcut, custom: model.customShortcut)
    }

    private func shortcutTitle(choice: ShortcutChoice, custom: RecordedShortcut?) -> String {
        if choice == .custom, let customShortcut = custom {
            return customShortcut.displayName
        }
        return choice.title
    }

    private var localEscapeMonitor: Any?
}

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let item: NSStatusItem

    init(model: AppModel) {
        self.model = model
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        item.button?.image = Self.menuBarGlyph()
        item.button?.image?.isTemplate = true
        item.button?.toolTip = Copy.appName
        update(state: .idle)
    }

    func update(state: DictationState) {
        let menu = NSMenu()
        let stateItem = NSMenuItem(title: stateTitle(state), action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())
        let record = NSMenuItem(title: state == .idle ? Copy.startRecording : state == .finalizing || state == .delivering ? String(localized: "recording.finishing") : Copy.stopRecording, action: #selector(toggleRecording), keyEquivalent: "")
        record.target = self
        record.isEnabled = state != .finalizing
            && state != .delivering
            && (state != .idle || model.dictation.readiness == .ready)
        menu.addItem(record)
        let open = NSMenuItem(title: String(localized: "menubar.open"), action: #selector(openApp), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        let dashboard = NSMenuItem(title: Copy.dashboard, action: #selector(openDashboard), keyEquivalent: "1")
        dashboard.keyEquivalentModifierMask = [.command]
        dashboard.target = self
        menu.addItem(dashboard)
        let history = NSMenuItem(title: Copy.history, action: #selector(openHistory), keyEquivalent: "1")
        history.keyEquivalent = "2"
        history.keyEquivalentModifierMask = [.command]
        history.target = self
        menu.addItem(history)
        let dictionary = NSMenuItem(title: Copy.dictionary, action: #selector(openDictionary), keyEquivalent: "2")
        dictionary.keyEquivalent = "3"
        dictionary.keyEquivalentModifierMask = [.command]
        dictionary.target = self
        menu.addItem(dictionary)
        let statistics = NSMenuItem(title: Copy.statistics, action: #selector(openStatistics), keyEquivalent: "4")
        statistics.keyEquivalentModifierMask = [.command]
        statistics.target = self
        menu.addItem(statistics)
        let aiModels = NSMenuItem(title: Copy.aiModels, action: #selector(openAIModels), keyEquivalent: "5")
        aiModels.keyEquivalentModifierMask = [.command]
        aiModels.target = self
        menu.addItem(aiModels)
        let settings = NSMenuItem(title: Copy.settings, action: #selector(openSettings), keyEquivalent: ",")
        settings.keyEquivalentModifierMask = [.command]
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: String(localized: "menubar.quit"), action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
    }

    @objc private func toggleRecording() {
        if model.dictation.state == .idle || model.dictation.lastFailure != nil { model.startRecording(source: .menuBar) }
        else { model.finishRecording() }
    }

    @objc private func openApp() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    @objc private func openDashboard() { open(section: .dashboard) }
    @objc private func openHistory() { open(section: .history) }
    @objc private func openDictionary() { open(section: .dictionary) }
    @objc private func openStatistics() { open(section: .statistics) }
    @objc private func openAIModels() { open(section: .aiModels) }
    @objc private func openSettings() { open(section: .settings) }

    private func open(section: AppSection) {
        model.section = section
        openApp()
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    private func stateTitle(_ state: DictationState) -> String {
        switch state {
        case .idle:
            switch model.dictation.readiness {
            case .settingUp: return String(localized: "navigation.settingUp")
            case .modelLoaded:
                return String.localizedStringWithFormat(
                    String(localized: "recording.modelLoaded"),
                    model.transcriptionProvider.readinessTitle
                )
            case .ready: return String(localized: "menubar.ready")
            case .unavailable: return String(localized: "navigation.setupFailed")
            }
        case .preparing: return Copy.preparing
        case .listening: return Copy.listening
        case .transcribing: return Copy.transcribing
        case .finalizing: return String(localized: "recording.finishing")
        case .delivering: return Copy.inserting
        case .failed: return Copy.recordingFailed
        }
    }

    private static func menuBarGlyph() -> NSImage? {
        let candidates = [
            Bundle.main.url(forResource: "MenuBarGlyph", withExtension: "svg"),
            Bundle.main.resourceURL?.appendingPathComponent("Dictate_Dictate.bundle/MenuBarGlyph.svg")
        ]
        guard let url = candidates.compactMap({ $0 }).first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: 18, height: 18)
        return image
    }
}

@MainActor
final class RecordingOverlayController {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }

    private let controller: DictationController
    private let panel: Panel
    private var shortcutTitle: String
    private var anchoredCenterX: CGFloat?
    private var anchoredScreen: NSScreen?
    private var anchoredBottomY: CGFloat?

    init(controller: DictationController, shortcutTitle: String) {
        self.controller = controller
        self.shortcutTitle = shortcutTitle
        panel = Panel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: DesignSystem.Layout.overlayHostWidth,
                height: DesignSystem.Layout.overlayHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.animationBehavior = .none
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: RecordingOverlayView(controller: controller, shortcutTitle: shortcutTitle))
    }

    func updateShortcutTitle(_ title: String) {
        shortcutTitle = title
        panel.contentView = NSHostingView(rootView: RecordingOverlayView(controller: controller, shortcutTitle: title))
    }

    func update(state: DictationState, notice: DeliveryNotice?, showReadyIndicator: Bool) {
        if state == .idle,
           notice == nil,
           controller.readiness == .ready,
           !showReadyIndicator {
            panel.orderOut(nil)
            anchoredCenterX = nil
            anchoredScreen = nil
            anchoredBottomY = nil
            return
        }
        position()
        panel.orderFrontRegardless()
    }

    private func position() {
        if anchoredScreen == nil {
            // The mouse may be anywhere when a global shortcut is released.
            // Anchoring to it made the pebble jump between displays. Use the
            // main display once per visible lifetime instead.
            anchoredScreen = NSScreen.main ?? NSScreen.screens.first
        }
        guard let screen = anchoredScreen else { return }
        let frame = screen.visibleFrame
        if anchoredCenterX == nil {
            anchoredCenterX = frame.midX
        }
        if anchoredBottomY == nil { anchoredBottomY = frame.minY + DesignSystem.Layout.overlayBottomInset }
        let size = NSSize(
            width: DesignSystem.Layout.overlayHostWidth,
            height: DesignSystem.Layout.overlayHeight
        )
        // The transparent host panel never resizes. The visible capsule morphs
        // inside it, so AppKit cannot shift the window between state updates.
        let origin = NSPoint(
            x: (anchoredCenterX ?? frame.midX) - size.width / 2,
            y: anchoredBottomY ?? frame.minY + DesignSystem.Layout.overlayBottomInset
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true, animate: false)
    }
}
