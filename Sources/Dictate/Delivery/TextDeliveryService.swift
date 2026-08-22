@preconcurrency import ApplicationServices
import AppKit
import CoreGraphics

enum DeliveryResult: Equatable, Sendable {
    case inserted
    case copiedOnly
    case failed
}

@MainActor
final class FocusSnapshot {
    private let focusedElement: AXUIElement?
    private let frontmostApplication: NSRunningApplication?

    private init(focusedElement: AXUIElement?, frontmostApplication: NSRunningApplication?) {
        self.focusedElement = focusedElement
        self.frontmostApplication = frontmostApplication
    }

    static func capture() -> FocusSnapshot {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused)
        var element: AXUIElement?
        if error == .success, let focused { element = unsafeDowncast(focused, to: AXUIElement.self) }
        return FocusSnapshot(focusedElement: element, frontmostApplication: NSWorkspace.shared.frontmostApplication)
    }

    func insert(_ text: String) -> DeliveryResult {
        if let focusedElement,
           AXUIElementSetAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success {
            return .inserted
        }
        return pasteboardFallback(text)
    }

    func copyOnly(_ text: String) -> DeliveryResult {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        return .copiedOnly
    }

    private func pasteboardFallback(_ text: String) -> DeliveryResult {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        frontmostApplication?.activate(options: [])

        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            snapshot.restore()
            return .failed
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            snapshot.restore()
        }
        return .inserted
    }
}

private struct PasteboardSnapshot: Sendable {
    private let items: [[String: Data]]

    init(pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type.rawValue, data)
            })
        }
    }

    func restore() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let restored = items.map { values -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in values { item.setData(data, forType: NSPasteboard.PasteboardType(type)) }
            return item
        }
        pasteboard.writeObjects(restored)
    }
}
