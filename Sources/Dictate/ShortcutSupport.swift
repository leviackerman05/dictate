import AppKit
import ApplicationServices
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
    private var isPressed = false
    private var recordingMode: RecordingMode = .holdToTalk
    private var currentCustom: RecordedShortcut?
    private var onStart: (() -> Void)?
    private var onFinish: (() -> Void)?

    func start(choice: ShortcutChoice, custom: RecordedShortcut?, recordingMode: RecordingMode, onStart: @escaping () -> Void, onFinish: @escaping () -> Void) {
        stop()
        self.onStart = onStart
        self.onFinish = onFinish
        self.recordingMode = recordingMode
        self.currentCustom = custom
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .keyUp]
        let tap = ShortcutEventTap(choice: choice, custom: custom) { [weak self] type, keyCode, flags in
            Task { @MainActor in self?.handle(type: type, keyCode: keyCode, flags: flags) }
        }
        if tap.start() {
            eventTap = tap
        } else {
            // Event taps are the preferred path because they can consume the
            // Fn/globe event before macOS opens the emoji picker. Keep the
            // AppKit monitors as a fallback when Input Monitoring is not yet
            // available.
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
                Task { @MainActor in self?.handle(event, choice: choice, custom: custom) }
            }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                Task { @MainActor in self?.handle(event, choice: choice, custom: custom) }
                return event
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
        isPressed = false
    }

    private func handle(_ event: NSEvent, choice: ShortcutChoice, custom: RecordedShortcut?) {
        let matches: Bool
        switch choice {
        case .rightOption: matches = event.type == .flagsChanged && event.keyCode == 61 && event.modifierFlags.contains(.option)
        case .rightCommand: matches = event.type == .flagsChanged && event.keyCode == 54 && event.modifierFlags.contains(.command)
        case .fn: matches = event.type == .flagsChanged && event.keyCode == 63 && event.modifierFlags.contains(.function)
        case .custom:
            guard let custom else { return }
            matches = event.keyCode == custom.keyCode && (event.type == .keyDown || event.type == .keyUp) && UInt64(event.modifierFlags.rawValue) & custom.modifiers == custom.modifiers
        }
        guard matches else {
            if choice != .custom, recordingMode == .holdToTalk, event.type == .flagsChanged, isPressed, !modifierStillDown(choice, flags: event.modifierFlags) {
                finishIfNeeded()
            }
            return
        }

        if choice == .custom {
            if event.type == .keyDown && !isPressed {
                isPressed = true
                onStart?()
            } else if event.type == .keyUp && recordingMode == .holdToTalk {
                finishIfNeeded()
            }
        } else if event.type == .flagsChanged {
            if !isPressed {
                isPressed = true
                onStart?()
            } else if !event.modifierFlags.contains(flag(for: choice)) && recordingMode == .holdToTalk {
                finishIfNeeded()
            }
        }
    }

    private func modifierStillDown(_ choice: ShortcutChoice, flags: NSEvent.ModifierFlags) -> Bool {
        flags.contains(flag(for: choice))
    }

    private func flag(for choice: ShortcutChoice) -> NSEvent.ModifierFlags {
        switch choice {
        case .rightOption: return .option
        case .rightCommand: return .command
        case .fn, .custom: return .function
        }
    }

    private func finishIfNeeded() {
        guard isPressed else { return }
        isPressed = false
        onFinish?()
    }

    private func handle(type: UInt32, keyCode: UInt16, flags: UInt64) {
        let flags = CGEventFlags(rawValue: flags)
        let isDown = flags.contains(.maskSecondaryFn) || flags.contains(.maskAlternate) || flags.contains(.maskCommand)
        switch currentChoice {
        case .rightOption:
            guard type == CGEventType.flagsChanged.rawValue, keyCode == 61 else { return }
            if isDown && !isPressed { isPressed = true; onStart?() }
            else if !isDown && isPressed && recordingMode == .holdToTalk { finishIfNeeded() }
        case .rightCommand:
            guard type == CGEventType.flagsChanged.rawValue, keyCode == 54 else { return }
            if isDown && !isPressed { isPressed = true; onStart?() }
            else if !isDown && isPressed && recordingMode == .holdToTalk { finishIfNeeded() }
        case .fn:
            guard type == CGEventType.flagsChanged.rawValue, keyCode == 63 else { return }
            let fnDown = flags.contains(.maskSecondaryFn)
            if fnDown && !isPressed { isPressed = true; onStart?() }
            else if !fnDown && isPressed && recordingMode == .holdToTalk { finishIfNeeded() }
        case .custom:
            guard let custom = currentCustom, keyCode == custom.keyCode else { return }
            if type == CGEventType.keyDown.rawValue && !isPressed { isPressed = true; onStart?() }
            else if type == CGEventType.keyUp.rawValue && recordingMode == .holdToTalk { finishIfNeeded() }
        }
    }

    private var currentChoice: ShortcutChoice {
        // The event tap only handles the currently installed configuration;
        // the fallback AppKit path still receives the explicit values.
        eventTap?.choice ?? .rightOption
    }
}

private final class ShortcutEventTap: @unchecked Sendable {
    let choice: ShortcutChoice
    let custom: RecordedShortcut?
    private let onEvent: @Sendable (UInt32, UInt16, UInt64) -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    init(choice: ShortcutChoice, custom: RecordedShortcut?, onEvent: @escaping @Sendable (UInt32, UInt16, UInt64) -> Void) {
        self.choice = choice
        self.custom = custom
        self.onEvent = onEvent
    }

    func start() -> Bool {
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
                guard owner.matches(type: type, event: event) else { return Unmanaged.passUnretained(event) }
                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                owner.onEvent(type.rawValue, keyCode, event.flags.rawValue)
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
    }

    private func matches(type: CGEventType, event: CGEvent) -> Bool {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        switch choice {
        case .rightOption: return type == .flagsChanged && keyCode == 61
        case .rightCommand: return type == .flagsChanged && keyCode == 54
        case .fn: return type == .flagsChanged && keyCode == 63
        case .custom:
            guard let custom, keyCode == custom.keyCode, type == .keyDown || type == .keyUp else { return false }
            return UInt64(event.flags.rawValue) & custom.modifiers == custom.modifiers
        }
    }
}
