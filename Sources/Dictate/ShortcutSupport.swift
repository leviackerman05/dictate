import AppKit
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
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isPressed = false
    private var onStart: (() -> Void)?
    private var onFinish: (() -> Void)?

    func start(choice: ShortcutChoice, custom: RecordedShortcut?, onStart: @escaping () -> Void, onFinish: @escaping () -> Void) {
        stop()
        self.onStart = onStart
        self.onFinish = onFinish
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .keyUp]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.handle(event, choice: choice, custom: custom) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.handle(event, choice: choice, custom: custom) }
            return event
        }
    }

    func stop() {
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
            if choice != .custom, event.type == .flagsChanged, isPressed, !modifierStillDown(choice, flags: event.modifierFlags) {
                finishIfNeeded()
            }
            return
        }

        if choice == .custom {
            if event.type == .keyDown && !isPressed {
                isPressed = true
                onStart?()
            } else if event.type == .keyUp {
                finishIfNeeded()
            }
        } else if event.type == .flagsChanged {
            if !isPressed {
                isPressed = true
                onStart?()
            } else if !event.modifierFlags.contains(flag(for: choice)) {
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
}
