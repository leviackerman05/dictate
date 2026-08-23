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
        menuBar = MenuBarController(model: model)
        overlay = RecordingOverlayController(controller: model.dictation)
        shortcutMonitor = ShortcutMonitor()
        installShortcutMonitor()
        stateCancellable = model.dictation.$state.sink { [weak self] state in
            self?.overlay?.update(state: state, notice: self?.model.dictation.deliveryNotice)
            self?.menuBar?.update(state: state)
            self?.shortcutMonitor?.update(session: state)
        }
        model.dictation.$deliveryNotice.sink { [weak self] notice in
            self?.overlay?.update(state: self?.model.dictation.state ?? .idle, notice: notice)
        }.store(in: &noticeCancellables)
        shortcutCancellable = model.$shortcut.combineLatest(model.$customShortcut).sink { [weak self] _, _ in
            self?.installShortcutMonitor()
        }
        recordingModeCancellable = model.$recordingMode.sink { [weak self] _ in
            self?.installShortcutMonitor()
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
        model.rememberExternalFocus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutMonitor?.stop()
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        if let localEscapeMonitor { NSEvent.removeMonitor(localEscapeMonitor) }
        if let activeObserver { NotificationCenter.default.removeObserver(activeObserver) }
        if let externalFocusObserver { NotificationCenter.default.removeObserver(externalFocusObserver) }
        if let workspaceFocusObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceFocusObserver) }
    }

    private func installShortcutMonitor() {
        shortcutMonitor?.start(choice: model.shortcut, custom: model.customShortcut, recordingMode: model.recordingMode) { [weak self] action in
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
        item.button?.image = NSImage(systemSymbolName: "text.cursor", accessibilityDescription: Copy.appName)
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
        record.isEnabled = state != .finalizing && state != .delivering
        menu.addItem(record)
        let open = NSMenuItem(title: String(localized: "menubar.open"), action: #selector(openApp), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
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

    @objc private func quitApp() { NSApp.terminate(nil) }

    private func stateTitle(_ state: DictationState) -> String {
        switch state {
        case .idle: return String(localized: "menubar.ready")
        case .preparing: return Copy.preparing
        case .listening: return Copy.listening
        case .transcribing: return Copy.transcribing
        case .finalizing: return String(localized: "recording.finishing")
        case .delivering: return Copy.inserting
        case .failed: return Copy.recordingFailed
        }
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

    init(controller: DictationController) {
        self.controller = controller
        panel = Panel(contentRect: NSRect(x: 0, y: 0, width: DesignSystem.Layout.overlayWidth, height: DesignSystem.Layout.overlayHeight), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: RecordingOverlayView(controller: controller))
    }

    func update(state: DictationState, notice: DeliveryNotice?) {
        if state == .idle, notice == nil {
            panel.orderOut(nil)
            return
        }
        position()
        panel.orderFrontRegardless()
    }

    private func position() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: frame.midX - panel.frame.width / 2,
            y: frame.minY + DesignSystem.Layout.space8
        ))
    }
}
