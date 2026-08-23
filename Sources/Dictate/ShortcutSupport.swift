import AppKit
import ApplicationServices
import DictateCore
import SwiftUI

enum ShortcutChoice: String, CaseIterable, Codable, Identifiable {
    case rightOption
    case fn
    case rightCommand
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rightOption: return String(localized: "shortcut.rightOption")
        case .fn: return String(localized: "shortcut.fn")
        case .rightCommand: return String(localized: "shortcut.rightCommand")
        case .custom: return String(localized: "shortcut.custom")
        }
    }
}

struct RecordedShortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt64

    var displayName: String { "Key \(keyCode)" }

    var isSafe: Bool {
        let hasModifier = modifiers & UInt64(NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue) != 0
        return hasModifier && keyCode != 53 && keyCode != 36 && keyCode != 49
    }
}

@MainActor
struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: RecordedShortcut?

    @MainActor
    final class Coordinator {
        var binding: Binding<RecordedShortcut?>?

        func record(_ value: RecordedShortcut) {
            guard value.isSafe else { return }
            binding?.wrappedValue = value
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        context.coordinator.binding = $shortcut
        view.onRecord = { value in context.coordinator.record(value) }
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        context.coordinator.binding = $shortcut
        nsView.value = shortcut
    }
}

@MainActor
final class RecorderView: NSView {
    var onRecord: ((RecordedShortcut) -> Void)?
    var value: RecordedShortcut? { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let text = value?.displayName ?? String(localized: "shortcut.recordPrompt")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]
        (text as NSString).draw(in: bounds.insetBy(dx: DesignSystem.Layout.space3, dy: DesignSystem.Layout.space2), withAttributes: attributes)
        NSColor.separatorColor.setStroke()
        NSBezierPath(roundedRect: bounds, xRadius: DesignSystem.Layout.radiusField, yRadius: DesignSystem.Layout.radiusField).stroke()
    }

    override func keyDown(with event: NSEvent) {
        let value = RecordedShortcut(keyCode: event.keyCode, modifiers: UInt64(event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue))
        if value.isSafe { onRecord?(value) }
    }
}

@MainActor
final class ShortcutMonitor {
    private var eventTap: ShortcutEventTap?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var inbox: ShortcutEventInbox?
    private var reducer = ShortcutGestureReducer()
    private var choice: ShortcutChoice = .rightOption
    private var custom: RecordedShortcut?
    private var recordingMode: ShortcutGestureMode = .holdToTalk
    private var onAction: ((ShortcutGestureAction) -> Void)?
    private var modifierIsDown = false

    func start(
        choice: ShortcutChoice,
        custom: RecordedShortcut?,
        recordingMode: RecordingMode,
        onAction: @escaping (ShortcutGestureAction) -> Void
    ) {
        stop()
        self.choice = choice
        self.custom = custom
        self.recordingMode = recordingMode.gestureMode
        self.onAction = onAction
        modifierIsDown = false
        let inbox = ShortcutEventInbox { [weak self] in
            Task { @MainActor [weak self] in self?.drainInbox() }
        }
        self.inbox = inbox
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .keyUp]
        let tap = ShortcutEventTap(choice: choice, custom: custom) { type, keyCode, flags, isRepeat, isDown in
            if type == CGEventType.tapDisabledByTimeout.rawValue || type == CGEventType.tapDisabledByUserInput.rawValue {
                return
            }
            inbox.enqueue(ShortcutPlatformEvent(type: type, keyCode: keyCode, flags: flags, isRepeat: isRepeat, isDown: isDown))
        }
        if tap.start() {
            eventTap = tap
        } else {
            // Event taps are the preferred path because they can consume the
            // Fn/globe event before macOS opens the emoji picker. Keep the
            // AppKit monitors as a fallback when Input Monitoring is not yet
            // available.
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self, inbox, choice, custom] event in
                guard let self, let platform = self.platformEvent(event, choice: choice, custom: custom) else { return }
                inbox.enqueue(platform)
            }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self, inbox, choice, custom] event in
                guard let self, let platform = self.platformEvent(event, choice: choice, custom: custom) else { return event }
                inbox.enqueue(platform)
                return nil
            }
        }
    }

    func stop() {
        eventTap?.stop()
        eventTap = nil
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        inbox = nil
        reducer = ShortcutGestureReducer()
        modifierIsDown = false
    }

    func update(session: DictationState) {
        sessionPhase = phase(for: session)
    }

    private var sessionPhase: ShortcutSessionPhase = .idle

    private func drainInbox() {
        guard let inbox else { return }
        let events = inbox.takeAll()
        for event in events { handle(event) }
    }

    private func handle(_ event: ShortcutPlatformEvent) {
        let input: ShortcutGestureInput
        if event.isRepeat || event.type == CGEventType.keyDown.rawValue && event.isRepeat {
            input = .keyRepeat
        } else if event.type == CGEventType.keyUp.rawValue || event.isFlagsChanged && !event.isDown {
            input = .physicalUp
        } else {
            input = .physicalDown
        }
        let action = reducer.reduce(input, mode: recordingMode, session: sessionPhase)
        guard action != .none else { return }
        DictateLog.lifecycle.debug("shortcut event input=\(String(describing: input), privacy: .public) phase=\(String(describing: self.sessionPhase), privacy: .public) action=\(String(describing: action), privacy: .public)")
        onAction?(action)
    }

    private func platformEvent(_ event: NSEvent, choice: ShortcutChoice, custom: RecordedShortcut?) -> ShortcutPlatformEvent? {
        let type: UInt32
        switch event.type {
        case .flagsChanged: type = CGEventType.flagsChanged.rawValue
        case .keyDown: type = CGEventType.keyDown.rawValue
        case .keyUp: type = CGEventType.keyUp.rawValue
        default: return nil
        }

        let keyCode = event.keyCode
        switch choice {
        case .rightOption where event.type == .flagsChanged && keyCode == 61:
                return ShortcutPlatformEvent(type: type, keyCode: keyCode, flags: event.cgEvent?.flags.rawValue ?? 0, isRepeat: false, isDown: nextModifierState())
        case .rightCommand where event.type == .flagsChanged && keyCode == 54:
            return ShortcutPlatformEvent(type: type, keyCode: keyCode, flags: event.cgEvent?.flags.rawValue ?? 0, isRepeat: false, isDown: nextModifierState())
        case .fn where event.type == .flagsChanged && keyCode == 63:
            return ShortcutPlatformEvent(type: type, keyCode: keyCode, flags: event.cgEvent?.flags.rawValue ?? 0, isRepeat: false, isDown: nextModifierState())
        case .custom:
            guard let custom, keyCode == custom.keyCode else { return nil }
            if event.type == .keyDown && UInt64(event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue) & custom.modifiers != custom.modifiers {
                return nil
            }
            return ShortcutPlatformEvent(type: type, keyCode: keyCode, flags: event.cgEvent?.flags.rawValue ?? UInt64(event.modifierFlags.rawValue), isRepeat: event.isARepeat, isDown: event.type == .keyDown)
        default:
            return nil
        }
    }

    private func nextModifierState() -> Bool {
        modifierIsDown.toggle()
        return modifierIsDown
    }

    private func phase(for state: DictationState) -> ShortcutSessionPhase {
        switch state {
        case .idle, .failed: return .idle
        case .preparing: return .preparing
        case .listening, .transcribing: return .recording
        case .finalizing, .delivering: return .finalizing
        }
    }
}

private final class ShortcutEventTap: @unchecked Sendable {
    let choice: ShortcutChoice
    let custom: RecordedShortcut?
    private let onEvent: @Sendable (UInt32, UInt16, UInt64, Bool, Bool) -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var modifierIsDown = false

    init(choice: ShortcutChoice, custom: RecordedShortcut?, onEvent: @escaping @Sendable (UInt32, UInt16, UInt64, Bool, Bool) -> Void) {
        self.choice = choice
        self.custom = custom
        self.onEvent = onEvent
    }

    func start() -> Bool {
        modifierIsDown = false
        let flagsMask = CGEventMask(1) << CGEventType.flagsChanged.rawValue
        let keyboardMask = CGEventMask(1) << CGEventType.keyDown.rawValue
        let keyUpMask = CGEventMask(1) << CGEventType.keyUp.rawValue
        let eventMask = flagsMask | keyboardMask | keyUpMask
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<ShortcutEventTap>.fromOpaque(refcon).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = owner.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                    return Unmanaged.passUnretained(event)
                }
                guard owner.matches(type: type, event: event) else { return Unmanaged.passUnretained(event) }
                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                let isDown: Bool
                if type == .flagsChanged {
                    isDown = owner.nextModifierState()
                } else {
                    isDown = type == .keyDown
                }
                owner.onEvent(type.rawValue, keyCode, event.flags.rawValue, event.getIntegerValueField(.keyboardEventAutorepeat) != 0, isDown)
                return nil
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

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        source = nil
        tap = nil
        modifierIsDown = false
    }

    private func nextModifierState() -> Bool {
        modifierIsDown.toggle()
        return modifierIsDown
    }

    private func matches(type: CGEventType, event: CGEvent) -> Bool {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        switch choice {
        case .rightOption: return type == .flagsChanged && keyCode == 61
        case .rightCommand: return type == .flagsChanged && keyCode == 54
        case .fn: return type == .flagsChanged && keyCode == 63
        case .custom:
            guard let custom, keyCode == custom.keyCode, type == .keyDown || type == .keyUp else { return false }
            if type == .keyUp { return true }
            return UInt64(event.flags.rawValue) & custom.modifiers == custom.modifiers
        }
    }
}

private struct ShortcutPlatformEvent: Sendable {
    let type: UInt32
    let keyCode: UInt16
    let flags: UInt64
    let isRepeat: Bool
    let isDown: Bool

    var isFlagsChanged: Bool { type == CGEventType.flagsChanged.rawValue }
}

private final class ShortcutEventInbox: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [ShortcutPlatformEvent] = []
    private var drainScheduled = false
    private let scheduleDrain: @Sendable () -> Void

    init(scheduleDrain: @escaping @Sendable () -> Void) {
        self.scheduleDrain = scheduleDrain
    }

    func enqueue(_ event: ShortcutPlatformEvent) {
        lock.lock()
        events.append(event)
        let shouldSchedule = !drainScheduled
        drainScheduled = true
        lock.unlock()
        if shouldSchedule { scheduleDrain() }
    }

    func takeAll() -> [ShortcutPlatformEvent] {
        lock.lock()
        let result = events
        events.removeAll(keepingCapacity: true)
        drainScheduled = false
        lock.unlock()
        return result
    }
}
