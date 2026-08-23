@preconcurrency import ApplicationServices
import AppKit
import CoreGraphics

enum DeliveryResult: Equatable, Sendable {
    case insertedViaAccessibility
    case insertedViaPaste
    case copiedForRecovery
    case noTarget
    case permissionMissing
    case deliveryFailed

    var isRecoveryRequired: Bool {
        switch self {
        case .insertedViaAccessibility, .insertedViaPaste: return false
        case .copiedForRecovery, .noTarget, .permissionMissing, .deliveryFailed: return true
        }
    }
}

@MainActor
final class FocusSnapshot {
    private let focusedElement: AXUIElement?
    private let frontmostApplication: NSRunningApplication?
    private let processIdentifier: pid_t?

    private init(focusedElement: AXUIElement?, frontmostApplication: NSRunningApplication?, processIdentifier: pid_t?) {
        self.focusedElement = focusedElement
        self.frontmostApplication = frontmostApplication
        self.processIdentifier = processIdentifier
    }

    static func capture() -> FocusSnapshot {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused)
        let systemElement = error == .success && focused.map({ CFGetTypeID($0) == AXUIElementGetTypeID() }) == true
            ? unsafeDowncast(focused!, to: AXUIElement.self)
            : nil
        let frontmost = NSWorkspace.shared.frontmostApplication
        let systemElementPID = systemElement.flatMap { element in
            var pid: pid_t = 0
            return AXUIElementGetPid(element, &pid) == .success ? pid : nil
        }
        // The system-wide focused element can remain pointed at the last text
        // editor after Finder/Desktop becomes frontmost. Accept it only when
        // its process is the actual frontmost application; otherwise resolve
        // focus from the frontmost app itself. If Dictate is frontmost, leave
        // the current snapshot empty and let the service use the focus captured
        // immediately before Dictate activated.
        let externalFrontmost = frontmost.flatMap { isExternal($0) ? $0 : nil }
        let rawElement: AXUIElement?
        if let externalFrontmost {
            if let systemElement,
               systemElementPID == externalFrontmost.processIdentifier {
                rawElement = systemElement
            } else {
                rawElement = focusedElement(in: externalFrontmost.processIdentifier)
            }
        } else {
            rawElement = nil
        }
        let element = rawElement.flatMap { resolveTextInput(from: $0) } ?? rawElement
        let elementPID = element.flatMap { element in
            var pid: pid_t = 0
            return AXUIElementGetPid(element, &pid) == .success ? pid : nil
        } ?? (rawElement == nil ? nil : externalFrontmost?.processIdentifier)
        // Use only the focus that exists at the moment recording starts. Do
        // not fall back to a previously focused app: that could insert into an
        // old field when the user currently has no editable cursor.
        let targetPID = elementPID ?? externalFrontmost?.processIdentifier
        let targetApp = targetPID.flatMap { NSRunningApplication(processIdentifier: $0) }
        let snapshot = FocusSnapshot(
            focusedElement: elementPID.flatMap { pid in isExternalPID(pid) ? element : nil },
            frontmostApplication: targetApp.flatMap { isExternal($0) ? $0 : nil },
            processIdentifier: targetPID.flatMap { isExternalPID($0) ? $0 : nil }
        )
        let rawRole = role(of: systemElement) ?? "none"
        let resolvedRole = role(of: element) ?? "none"
        let frontmostBundle = frontmost?.bundleIdentifier ?? "none"
        let targetBundle = targetApp?.bundleIdentifier ?? "none"
        DictateLog.delivery.debug(
            "focus capture trusted=\(AXIsProcessTrusted(), privacy: .public) systemRole=\(rawRole, privacy: .public) resolvedRole=\(resolvedRole, privacy: .public) systemPID=\(systemElementPID ?? 0, privacy: .public) elementPID=\(elementPID ?? 0, privacy: .public) frontmostBundle=\(frontmostBundle, privacy: .public) targetBundle=\(targetBundle, privacy: .public)"
        )
        return snapshot
    }

    var isValidExternalTarget: Bool {
        guard let processIdentifier,
              processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let application = frontmostApplication,
              !application.isTerminated,
              application.processIdentifier == processIdentifier,
              application.bundleIdentifier != Bundle.main.bundleIdentifier,
              let focusedElement,
              Self.pid(of: focusedElement) == processIdentifier else { return false }
        return true
    }

    var isUsableExternalTarget: Bool {
        isValidExternalTarget && focusedElement.map(EditableElementClassifier.isEditable) == true
    }

    var hasExternalApplication: Bool {
        frontmostApplication != nil && processIdentifier != nil
    }

    func insert(_ text: String) async -> DeliveryResult {
        // Without Accessibility trust macOS withholds the focused AX element,
        // so checking the snapshot first incorrectly reports "no target" and
        // never asks for the permission required to discover that target.
        guard AXIsProcessTrusted() else {
            DictateLog.delivery.debug("insert skipped: Accessibility trust missing")
            requestAccessibilityIfNeeded()
            return .permissionMissing
        }

        guard isValidExternalTarget, let focusedElement else {
            DictateLog.delivery.debug("insert skipped: no valid external focus target")
            return .noTarget
        }

        guard EditableElementClassifier.isEditable(focusedElement) else {
            let focusedRole = role(of: focusedElement) ?? "none"
            DictateLog.delivery.debug("insert skipped: focused role is not text input role=\(focusedRole, privacy: .public)")
            return .noTarget
        }

        // AXValue is not guaranteed to be the editor's literal text. Web and
        // Electron apps can include adjacent accessibility labels such as
        // "Edit message" in that value. Rewriting it can leak those labels into
        // the draft. A temporary, restored pasteboard inserts exactly the
        // transcript and also lets framework-backed editors update their model.
        let focusedRole = role(of: focusedElement) ?? "none"
        DictateLog.delivery.debug("trying exact paste delivery role=\(focusedRole, privacy: .public)")
        if await pasteIntoFocusedApplication(text, focusedElement: focusedElement) {
            DictateLog.delivery.debug("insert succeeded through exact paste")
            return .insertedViaPaste
        }

        // Failure here means delivery stopped before a paste event could be
        // dispatched to a valid editable target, so recovery is appropriate.
        DictateLog.delivery.error("Could not dispatch paste to focused editor")
        return .deliveryFailed
    }

    private func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private static func resolveTextInput(from element: AXUIElement) -> AXUIElement? {
        if EditableElementClassifier.isEditable(element) { return element }
        if let descendant = focusedEditableDescendant(in: element) { return descendant }

        var candidate: AXUIElement? = element
        for _ in 0..<6 {
            guard let current = candidate else { return nil }
            if EditableElementClassifier.isEditable(current) { return current }

            var parentValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentValue) == .success,
                  let parentValue,
                  CFGetTypeID(parentValue) == AXUIElementGetTypeID() else {
                return nil
            }
            candidate = unsafeDowncast(parentValue, to: AXUIElement.self)
        }
        return nil
    }

    private static func focusedEditableDescendant(in root: AXUIElement) -> AXUIElement? {
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var visited = 0

        while !queue.isEmpty, visited < 80 {
            let (element, depth) = queue.removeFirst()
            visited += 1
            guard depth < 6 else { continue }

            var childrenValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
                  let children = childrenValue as? [AXUIElement] else { continue }

            for child in children {
                if EditableElementClassifier.isFocused(child),
                   EditableElementClassifier.isEditable(child) {
                    return child
                }
                queue.append((child, depth + 1))
            }
        }
        return nil
    }

    private static func focusedElement(in processIdentifier: pid_t) -> AXUIElement? {
        let application = AXUIElementCreateApplication(processIdentifier)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused,
              CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeDowncast(focused, to: AXUIElement.self)
    }

    private static func role(of element: AXUIElement?) -> String? {
        guard let element else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func role(of element: AXUIElement?) -> String? {
        Self.role(of: element)
    }

    private func pasteIntoFocusedApplication(_ text: String, focusedElement: AXUIElement) async -> Bool {
        guard let application = frontmostApplication,
              let processIdentifier,
              !application.isTerminated else { return false }
        let pasteboardSnapshot = PasteboardSnapshot.capture()
        guard copyToPasteboard(text) else { return false }
        let temporaryChangeCount = NSPasteboard.general.changeCount
        defer { pasteboardSnapshot.restoreIfUnchanged(expectedChangeCount: temporaryChangeCount) }
        application.activate(options: [.activateAllWindows])

        do {
            try await Task.sleep(nanoseconds: 150_000_000)
        } catch {
            return false
        }

        // Re-resolve focus after activation. A stored AXUIElement can remain
        // alive while the application has moved focus to another control.
        let activeElement = Self.focusedElement(in: processIdentifier)
            .flatMap { Self.resolveTextInput(from: $0) }
            ?? focusedElement
        guard Self.pid(of: activeElement) == processIdentifier,
              EditableElementClassifier.isEditable(activeElement) else {
            return false
        }
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            return false
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)

        // Once a valid editable target is active and both Command-V events have
        // been posted, AXValue is not a reliable validator: framework-backed
        // editors may normalize or decorate it. Treat the dispatched paste as
        // successful so an already-inserted transcript never also shows the
        // Copy recovery UI.
        do {
            try await Task.sleep(nanoseconds: 250_000_000)
        } catch {
            return false
        }
        return true
    }

    private static func pid(of element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(element, &pid) == .success ? pid : nil
    }

    @discardableResult
    private func copyToPasteboard(_ text: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(text, forType: .string)
    }

    private static func isExternal(_ application: NSRunningApplication) -> Bool {
        application.processIdentifier != ProcessInfo.processInfo.processIdentifier &&
            application.bundleIdentifier != Bundle.main.bundleIdentifier &&
            !application.isTerminated
    }

    private static func isExternalPID(_ pid: pid_t) -> Bool {
        pid != ProcessInfo.processInfo.processIdentifier
    }
}

private struct PasteboardSnapshot {
    private struct Item {
        let values: [(NSPasteboard.PasteboardType, Data)]
    }

    private let items: [Item]

    static func capture() -> PasteboardSnapshot {
        let pasteboard = NSPasteboard.general
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            Item(values: item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            })
        }
        return PasteboardSnapshot(items: items)
    }

    func restoreIfUnchanged(expectedChangeCount: Int) {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount == expectedChangeCount else {
            DictateLog.delivery.debug("pasteboard changed during fallback; leaving user content untouched")
            return
        }

        pasteboard.clearContents()
        let restored = items.map { item -> NSPasteboardItem in
            let pasteboardItem = NSPasteboardItem()
            for (type, data) in item.values {
                pasteboardItem.setData(data, forType: type)
            }
            return pasteboardItem
        }
        if !restored.isEmpty {
            pasteboard.writeObjects(restored)
        }
    }
}

private enum EditableElementClassifier {
    private static let editableRoles: Set<String> = [
        kAXTextFieldRole,
        kAXTextAreaRole,
        kAXComboBoxRole,
        "AXTextView",
        "AXSearchField"
    ]

    static func isEditable(_ element: AXUIElement) -> Bool {
        guard let role = role(of: element) else { return false }
        if editableRoles.contains(role) { return true }

        // Web contenteditable controls commonly expose a web-area role and a
        // selected range rather than a settable AXValue.
        guard role == "AXWebArea" || role == "AXGroup" else { return false }
        var selectedRange: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange) == .success
    }

    static func isFocused(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedAttribute as CFString, &value) == .success else {
            return false
        }
        return (value as? Bool) == true
    }

    static func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
