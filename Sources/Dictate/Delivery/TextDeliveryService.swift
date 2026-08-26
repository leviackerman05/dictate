@preconcurrency import ApplicationServices
import AppKit
import CoreGraphics
import DictateCore

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
    /// Some custom-rendered editors expose a focused AXWindow but no text
    /// children at all. In that narrow case we can still deliver the normal
    /// paste command, provided the same app/window remains active.
    private let isWindowPasteTarget: Bool
    private let frontmostApplication: NSRunningApplication?
    private let processIdentifier: pid_t?
    /// Captured editor's frame in Quartz global screen coordinates (top-left
    /// origin) — the same space CGEvent locations use. Nil when unavailable.
    let frame: CGRect?
    /// Wall-clock moment the snapshot was taken; compared against external
    /// click times by the click-abandonment policy.
    let capturedAt: Date
    private let hitTestLocation: CGPoint?
    private let hitTestConfirmedTarget: Bool

    private init(
        focusedElement: AXUIElement?,
        isWindowPasteTarget: Bool,
        frontmostApplication: NSRunningApplication?,
        processIdentifier: pid_t?,
        frame: CGRect?,
        capturedAt: Date,
        hitTestLocation: CGPoint?,
        hitTestConfirmedTarget: Bool
    ) {
        self.focusedElement = focusedElement
        self.isWindowPasteTarget = isWindowPasteTarget
        self.frontmostApplication = frontmostApplication
        self.processIdentifier = processIdentifier
        self.frame = frame
        self.capturedAt = capturedAt
        self.hitTestLocation = hitTestLocation
        self.hitTestConfirmedTarget = hitTestConfirmedTarget
    }

    static func capture(hitTestLocation: CGPoint? = nil) -> FocusSnapshot {
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
        // Regular applications own focus through NSWorkspace's frontmost app.
        // Accessory applications such as Raycast are different: their key panel
        // can own the system-wide focused AX element while NSWorkspace continues
        // to report the regular app behind the panel as frontmost. Resolve that
        // genuine focus owner from the AX element's PID, but only for an
        // accessory app that currently exposes a focused window.
        let externalFocusOwner: NSRunningApplication? = {
            if let frontmost,
               isExternal(frontmost),
               frontmost.isActive,
               Self.element(processIdentifier: systemElementPID, belongsTo: frontmost) {
                return frontmost
            }
            guard let systemElementPID,
                  let accessory = NSRunningApplication(processIdentifier: systemElementPID),
                  isExternal(accessory),
                  accessory.activationPolicy == .accessory,
                  Self.hasFocusedWindow(accessory) else { return nil }
            return accessory
        }()
        // Only the system-wide focused element is authoritative. Asking an
        // application for AXFocusedUIElement can return its last first
        // responder even after the cursor has left that field.
        let rawElement: AXUIElement? = externalFocusOwner.flatMap { application -> AXUIElement? in
            guard let systemElement,
                  Self.element(processIdentifier: systemElementPID, belongsTo: application),
                  Self.isInFocusedWindow(systemElement, of: application) else { return nil }
            return systemElement
        }
        // The system-wide focused element can be the WINDOW itself (Zed's agent
        // chat, Raycast) rather than the text field inside it. Resolve the real
        // editable target through the shared capture/delivery resolver so both
        // sides agree on identity — but only when the system element passed the
        // PID + focused-window preconditions above (rawElement != nil).
        let element: AXUIElement? = {
            guard let rawElement, let application = externalFocusOwner else { return nil }
            return Self.resolvedTextElement(
                systemElement: rawElement,
                application: application,
                hitTestLocation: hitTestLocation
            )
        }()
        let elementPID = element.flatMap { element in
            var pid: pid_t = 0
            return AXUIElementGetPid(element, &pid) == .success ? pid : nil
        }
        // Use only the focus that exists at the moment recording starts. Do
        // not fall back to a previously focused app: that could insert into an
        // old field when the user currently has no editable cursor.
        let targetApp = externalFocusOwner
        let targetPID = targetApp?.processIdentifier
        let storedElement: AXUIElement? = elementPID.flatMap { pid -> AXUIElement? in
            guard let targetApp,
                  Self.element(processIdentifier: pid, belongsTo: targetApp) else { return nil }
            return element
        }
        let windowPasteTarget = storedElement == nil && externalFocusOwner.map { application in
            Self.canUseWindowPasteTarget(
                systemElement: systemElement,
                application: application,
                hitTestLocation: hitTestLocation
            )
        } == true
        let frame = storedElement.flatMap(Self.frame(of:)) ?? (windowPasteTarget ? systemElement.flatMap(Self.frame(of:)) : nil)
        let snapshot = FocusSnapshot(
            focusedElement: storedElement,
            isWindowPasteTarget: windowPasteTarget,
            frontmostApplication: targetApp,
            processIdentifier: targetPID,
            frame: frame,
            capturedAt: Date(),
            hitTestLocation: hitTestLocation,
            hitTestConfirmedTarget: hitTestLocation != nil && element != nil
        )
        let rawRole = role(of: systemElement) ?? "none"
        let resolvedRole = role(of: element) ?? "none"
        let frontmostBundle = frontmost?.bundleIdentifier ?? "none"
        let targetBundle = targetApp?.bundleIdentifier ?? "none"
        let isEditable = element.map(EditableElementClassifier.isEditable) == true
        let windowState: (hasFocusedWindow: Bool, relation: String) = {
            guard let targetApp else { return (false, "missing") }
            let applicationElement = AXUIElementCreateApplication(targetApp.processIdentifier)
            let focusedWindow = Self.elementAttribute(applicationElement, kAXFocusedWindowAttribute)
                ?? Self.elementAttribute(applicationElement, kAXMainWindowAttribute)
            let elementWindow = element.flatMap(Self.owningWindow(of:))
            guard let focusedWindow, let elementWindow else { return (false, "missing") }
            return (true, CFEqual(focusedWindow, elementWindow) ? "match" : "mismatch")
        }()
        let frontmostIsActive = frontmost?.isActive ?? false
        let frameDescription = frame.map { "\($0.origin.x),\($0.origin.y) \($0.size.width)x\($0.size.height)" } ?? "none"
        DictateLog.delivery.info(
            "focus capture trusted=\(AXIsProcessTrusted(), privacy: .public) systemRole=\(rawRole, privacy: .public) resolvedRole=\(resolvedRole, privacy: .public) systemPID=\(systemElementPID ?? 0, privacy: .public) elementPID=\(elementPID ?? 0, privacy: .public) frontmostBundle=\(frontmostBundle, privacy: .public) targetBundle=\(targetBundle, privacy: .public) isEditable=\(isEditable, privacy: .public) windowPaste=\(windowPasteTarget, privacy: .public) hasFocusedWindow=\(windowState.hasFocusedWindow, privacy: .public) frontmostIsActive=\(frontmostIsActive, privacy: .public) windowRelation=\(windowState.relation, privacy: .public) frame=\(frameDescription, privacy: .public)"
        )
        if element == nil || !isEditable {
            DictateLog.delivery.info("focus capture: no editable target")
            // Full AX tree dumps are intentionally opt-in. Traversing hundreds
            // of remote accessibility nodes on the main run loop made ordinary
            // focus changes visibly stall the recorder after long sessions.
            if ProcessInfo.processInfo.environment["DICTATE_AX_DIAGNOSTICS"] == "1",
               let systemElement {
                for line in Self.describeTree(root: systemElement, maxDepth: 3, maxNodes: 40) {
                    DictateLog.delivery.info("\(line, privacy: .public)")
                }
            }
        }
        return snapshot
    }

    var isValidExternalTarget: Bool {
        guard let processIdentifier,
              processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let application = frontmostApplication,
              !application.isTerminated,
              application.processIdentifier == processIdentifier,
              application.bundleIdentifier != Bundle.main.bundleIdentifier else { return false }
        if isWindowPasteTarget { return true }
        guard let focusedElement,
              let elementPID = Self.pid(of: focusedElement),
              Self.element(processIdentifier: elementPID, belongsTo: application) else { return false }
        return true
    }

    var isUsableExternalTarget: Bool {
        isValidExternalTarget && (isWindowPasteTarget || focusedElement.map(EditableElementClassifier.isEditable) == true)
    }

    var focusFingerprint: FocusTargetFingerprint? {
        guard isUsableExternalTarget,
              let processIdentifier else { return nil }
        if isWindowPasteTarget {
            return FocusTargetFingerprint(
                processIdentifier: processIdentifier,
                bundleIdentifier: frontmostApplication?.bundleIdentifier,
                role: "AXWindowPasteTarget",
                subrole: nil,
                frame: frame
            )
        }
        guard let focusedElement else { return nil }
        return FocusTargetFingerprint(
            processIdentifier: processIdentifier,
            bundleIdentifier: frontmostApplication?.bundleIdentifier,
            role: Self.role(of: focusedElement) ?? "unknown",
            subrole: Self.stringAttribute(kAXSubroleAttribute as CFString, of: focusedElement),
            frame: frame
        )
    }

    var externalProcessIdentifier: pid_t? { processIdentifier }

    func wasConfirmedByHitTest(at location: CGPoint) -> Bool {
        guard hitTestConfirmedTarget, let hitTestLocation else { return false }
        return abs(hitTestLocation.x - location.x) <= 2 &&
            abs(hitTestLocation.y - location.y) <= 2
    }

    var hasExternalApplication: Bool {
        frontmostApplication != nil && processIdentifier != nil
    }

    func insert(_ text: String) async -> DeliveryResult {
        // Without Accessibility trust macOS withholds the focused AX element.
        // Do not prompt from a background delivery attempt: return a recoverable
        // result and let the user request the optional permission explicitly.
        guard AXIsProcessTrusted() else {
            DictateLog.delivery.info("insert skipped: Accessibility trust missing")
            return .permissionMissing
        }

        guard isValidExternalTarget else {
            DictateLog.delivery.info("insert skipped: no valid external focus target")
            return .noTarget
        }

        if isWindowPasteTarget {
            DictateLog.delivery.info("trying guarded window paste delivery")
            return await pasteIntoFocusedApplication(text, focusedElement: nil)
                ? .insertedViaPaste
                : .deliveryFailed
        }

        guard let focusedElement else { return .noTarget }

        guard EditableElementClassifier.isEditable(focusedElement) else {
            let focusedRole = role(of: focusedElement) ?? "none"
            DictateLog.delivery.info("insert skipped: focused role is not text input role=\(focusedRole, privacy: .public)")
            return .noTarget
        }

        // A snapshot is only an insertion permission, never a reservation of
        // an editor. The user may move focus while speaking; in that case the
        // transcript must remain recoverable instead of being pasted into the
        // old field.
        guard isCurrentlyFocusedExternalTarget(focusedElement) else {
            DictateLog.delivery.info("insert skipped: captured editor is no longer the current focus")
            return .noTarget
        }

        let focusedRole = role(of: focusedElement) ?? "none"
        let strategy = TextDeliveryStrategyPolicy.strategy(
            isWebBacked: Self.isWebBacked(focusedElement),
            isElectronApplication: Self.isElectronApplication(frontmostApplication)
        )
        let prefersPaste = strategy == .pasteFirst

        // Web content-editables and Electron controls can expose a stale or
        // whole-document AXSelectedTextRange even while the visible caret is at
        // the end. Writing AXSelectedText then replaces the previous sentence.
        // Their native Command-V path uses the real DOM/editor selection and
        // emits the input events the application expects.
        if prefersPaste {
            DictateLog.delivery.info("trying guarded paste-first delivery role=\(focusedRole, privacy: .public)")
            if await pasteIntoFocusedApplication(text, focusedElement: focusedElement) {
                DictateLog.delivery.info("insert succeeded through paste-first delivery")
                return .insertedViaPaste
            }
        }

        // Prefer the narrow AXSelectedText write when the target exposes a
        // readable caret. Unlike rewriting AXValue, this changes only the
        // selection and cannot pull adjacent accessibility labels into the
        // draft. Its success is trusted only when a changed caret/text state
        // can be observed; custom editors then fall through to Command-V.
        DictateLog.delivery.info("trying selected-text AX delivery role=\(focusedRole, privacy: .public)")
        if insertViaAccessibility(text, focusedElement: focusedElement) {
            DictateLog.delivery.info("insert succeeded through selected-text AX")
            return .insertedViaAccessibility
        }

        // Electron, browser and custom-rendered editors commonly accept AX
        // writes and silently discard them. A temporary, restored pasteboard
        // lets those apps process their normal paste command instead.
        DictateLog.delivery.info("trying exact paste delivery role=\(focusedRole, privacy: .public)")
        if !prefersPaste, await pasteIntoFocusedApplication(text, focusedElement: focusedElement) {
            DictateLog.delivery.info("insert succeeded through exact paste")
            return .insertedViaPaste
        }

        // Failure here means delivery stopped before a paste event could be
        // dispatched to a valid editable target, so recovery is appropriate.
        DictateLog.delivery.error("Could not dispatch paste to focused editor")
        return .deliveryFailed
    }

    private static func isWebBacked(_ element: AXUIElement) -> Bool {
        var candidate: AXUIElement? = element
        for _ in 0..<16 {
            guard let current = candidate else { return false }
            if role(of: current) == "AXWebArea" { return true }
            candidate = elementAttribute(current, kAXParentAttribute)
        }
        return false
    }

    private static func isElectronApplication(_ application: NSRunningApplication?) -> Bool {
        guard let bundleURL = application?.bundleURL else { return false }
        let framework = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Frameworks", isDirectory: true)
            .appendingPathComponent("Electron Framework.framework", isDirectory: true)
        return FileManager.default.fileExists(atPath: framework.path)
    }

    private func insertViaAccessibility(_ text: String, focusedElement: AXUIElement) -> Bool {
        guard isCurrentlyFocusedExternalTarget(focusedElement) else { return false }
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            &settable
        ) == .success,
              settable.boolValue,
              let before = Self.textState(of: focusedElement),
              before.selectedRange != nil else {
            return false
        }
        guard AXUIElementSetAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            text as CFString
        ) == .success,
              let after = Self.textState(of: focusedElement),
              Self.provesInsertion(before: before, after: after, insertedText: text) else {
            return false
        }
        return true
    }

    private static func resolveTextInput(from element: AXUIElement) -> AXUIElement? {
        if EditableElementClassifier.isEditable(element) { return element }

        // Walk up to 14 parents so deeply nested custom hierarchies (Zed,
        // Raycast) still reach their editable ancestor — mirrors the spirit of
        // the 12-step walk in owningWindow(of:).
        var candidate: AXUIElement? = element
        for _ in 0..<14 {
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

    /// Shared capture/delivery resolver: turns the system-wide focused element
    /// into the real editable target. Zed, Raycast and other custom UIs report
    /// the WINDOW as AXFocusedUIElement while the caret sits in a text field
    /// inside it, so discovery continues from the window scope when the element
    /// itself is not an editor.
    ///
    /// Tiers:
    /// 1. The system element (or an ancestor ≤14 up) is already editable.
    /// 2. The system element lies at/inside window scope: ask the application
    ///    for its own AXFocusedUIElement and accept it if editable and its PID
    ///    belongs to that application.
    /// 3. Bounded breadth-first descent from the window for editable nodes,
    ///    preferring ones whose kAXFocusedAttribute reads back true. Ambiguous
    ///    multi-editor windows resolve to nil rather than guessing.
    private static func resolvedTextElement(
        systemElement: AXUIElement?,
        application: NSRunningApplication,
        hitTestLocation: CGPoint? = nil
    ) -> AXUIElement? {
        guard let systemElement else { return nil }

        // A recent pointer hit is stronger evidence than a system-wide AX
        // element, which Electron/WebKit can leave on an old first responder.
        // Custom UI frameworks can also return a wrapper/static node for
        // AXUIElementCopyElementAtPosition while the system-wide focused element
        // is the real editor. In that contradictory case, accept the system
        // editor only when its own frame proves that the click landed inside it.
        // This preserves the click-away guard: a click on blank space or another
        // control can never revive a stale first responder.
        if let hitTestLocation {
            if let hit = element(at: hitTestLocation),
               let hitPID = pid(of: hit),
               element(processIdentifier: hitPID, belongsTo: application) {
                if let resolved = resolveTextInput(from: hit),
                   EditableElementClassifier.isEditable(resolved) {
                    let resolvedRole = role(of: resolved) ?? "none"
                    DictateLog.delivery.info("focus discovery: pointer hit resolved editable role=\(resolvedRole, privacy: .public)")
                    return resolved
                }
                let candidates = editableDescendants(from: hit, maxDepth: 6, maxNodes: 180)
                if let focused = candidates.first(where: { focusedAttribute(of: $0) == true }) {
                    return focused
                }
                if candidates.count == 1 { return candidates[0] }

                if let systemEditor = resolveTextInput(from: systemElement),
                   EditableElementClassifier.isEditable(systemEditor),
                   let systemFrame = frame(of: systemEditor),
                   systemFrame.insetBy(dx: -8, dy: -8).contains(hitTestLocation) {
                    DictateLog.delivery.info("focus discovery: wrapper hit confirmed by focused editor frame")
                    return systemEditor
                }
                return nil
            }

            // Some Electron overlays do not participate in system-wide AX hit
            // testing at all. A directly focused editor with a containing frame
            // is still positive evidence; without that geometry we stay
            // conservative and return no target.
            if let systemEditor = resolveTextInput(from: systemElement),
               EditableElementClassifier.isEditable(systemEditor),
               let systemFrame = frame(of: systemEditor),
               systemFrame.insetBy(dx: -8, dy: -8).contains(hitTestLocation) {
                DictateLog.delivery.info("focus discovery: unavailable hit confirmed by focused editor frame")
                return systemEditor
            }
            return nil
        }

        // With no recent click, the system-wide focused element is the
        // authoritative keyboard-focus signal.
        if let element = resolveTextInput(from: systemElement),
           EditableElementClassifier.isEditable(element) {
            return element
        }

        // Window scope: the system element is itself a window, or one of its
        // ancestors (≤14 up) is. Tiers 2 and 3 only make sense inside window
        // scope — the focused "element" here is a container, not an app.
        var windowElement: AXUIElement?
        var candidate: AXUIElement? = systemElement
        for _ in 0..<14 {
            guard let current = candidate else { break }
            if role(of: current) == kAXWindowRole {
                windowElement = current
                break
            }
            candidate = elementAttribute(current, kAXParentAttribute)
        }
        guard let windowElement else { return nil }

        // Tier 2: the application's own AXFocusedUIElement is frequently more
        // precise than the system-wide one. Only accept an editable result whose
        // PID belongs to the application, so a stale first responder in another
        // process or window can never win.
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        if let appFocused = elementAttribute(applicationElement, kAXFocusedUIElementAttribute),
           let resolved = resolveTextInput(from: appFocused),
           EditableElementClassifier.isEditable(resolved),
           let resolvedPID = pid(of: resolved),
           element(processIdentifier: resolvedPID, belongsTo: application) {
            DictateLog.delivery.info("focus discovery: app-focused element role=\(role(of: resolved) ?? "none", privacy: .public)")
            return resolved
        }

        // Tier 3: bounded breadth-first descent through the window's children.
        // Zed's editor exposes enormous AX trees, so every budget is hard:
        // depth ≤8, ≤600 nodes visited, ≤80 children examined per node.
        var editableCandidates: [AXUIElement] = []
        var focusedEditable: [AXUIElement] = []
        var queue: [(element: AXUIElement, depth: Int)] = [(windowElement, 0)]
        var head = 0
        var visited = 0
        while head < queue.count && visited < 600 {
            let (node, depth) = queue[head]
            head += 1
            visited += 1
            if EditableElementClassifier.isEditable(node) {
                editableCandidates.append(node)
                if focusedAttribute(of: node) == true {
                    focusedEditable.append(node)
                }
            }
            guard depth < 8 else { continue }
            var examined = 0
            for child in children(of: node) {
                guard examined < 80 else { break }
                examined += 1
                queue.append((child, depth + 1))
            }
        }
        DictateLog.delivery.info("focus discovery: descent found focusedEditable=\(focusedEditable.count, privacy: .public) editables=\(editableCandidates.count, privacy: .public)")

        if let first = focusedEditable.first { return first }
        // A single editable is a safe bet; several without a focused marker are
        // ambiguous and must stay unresolved.
        if editableCandidates.count == 1 { return editableCandidates[0] }
        return nil
    }

    private static func element(at location: CGPoint) -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var result: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(location.x), Float(location.y), &result) == .success else {
            return nil
        }
        return result
    }

    /// Generic fallback for editors whose accessibility bridge stops at the
    /// window (for example a GPU-rendered editor). It is deliberately *not*
    /// used for AXGroup/AXWebArea focus: those are the stale-container shapes
    /// produced by browsers when an old input remains first responder.
    private static func canUseWindowPasteTarget(
        systemElement: AXUIElement?,
        application: NSRunningApplication,
        hitTestLocation: CGPoint?
    ) -> Bool {
        guard let systemElement,
              role(of: systemElement) == kAXWindowRole,
              let systemPID = pid(of: systemElement),
              element(processIdentifier: systemPID, belongsTo: application),
              let hitTestLocation,
              let hit = element(at: hitTestLocation),
              let hitPID = pid(of: hit),
              element(processIdentifier: hitPID, belongsTo: application),
              let windowFrame = frame(of: systemElement),
              windowFrame.contains(hitTestLocation),
              // Exclude title-bar/chrome clicks. The remaining window content
              // is the only target surface custom editors give macOS.
              hitTestLocation.y >= windowFrame.minY + 30 else { return false }

        let controlRoles: Set<String> = [
            kAXButtonRole, kAXCheckBoxRole, kAXRadioButtonRole, kAXPopUpButtonRole,
            kAXMenuButtonRole, kAXMenuItemRole, "AXLink", kAXSliderRole,
            kAXTabGroupRole, kAXToolbarRole
        ]
        if let hitRole = role(of: hit), controlRoles.contains(hitRole) { return false }

        // If the window exposes a real editor, the exact-element path must be
        // used. Window-paste is reserved for genuinely opaque AX trees.
        guard editableDescendants(from: systemElement, maxDepth: 8, maxNodes: 600).isEmpty else {
            return false
        }
        DictateLog.delivery.info("focus discovery: using guarded opaque-window paste target")
        return true
    }

    private static func editableDescendants(from root: AXUIElement, maxDepth: Int, maxNodes: Int) -> [AXUIElement] {
        var result: [AXUIElement] = []
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var index = 0
        while index < queue.count && index < maxNodes {
            let (element, depth) = queue[index]
            index += 1
            if EditableElementClassifier.isEditable(element) { result.append(element) }
            guard depth < maxDepth else { continue }
            for child in children(of: element).prefix(60) {
                queue.append((child, depth + 1))
            }
        }
        return result
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

    /// Frame of the system-wide focused element, in Quartz global screen
    /// coordinates (top-left origin). The external click tracker uses this to
    /// learn which element held AX focus at the moment of a mouse-down.
    static func frameOfSystemFocusedElement() -> CGRect? {
        guard let element = systemFocusedElement() else { return nil }
        return frame(of: element)
    }

    /// Reads kAXPosition/kAXSize as CGPoint/CGSize. AX geometry lives in
    /// global screen coordinates with a top-left origin — the same space as
    /// CGEvent locations, so the two are directly comparable.
    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              let positionValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let sizeValue,
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(positionValue, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeDowncast(sizeValue, to: AXValue.self), .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }

    private func pasteIntoFocusedApplication(_ text: String, focusedElement: AXUIElement?) async -> Bool {
        guard let application = frontmostApplication,
              let processIdentifier,
              !application.isTerminated,
              Self.isCurrentFocusOwner(application, expectedProcessIdentifier: processIdentifier) else {
            DictateLog.delivery.info("paste skipped: captured application is no longer active")
            return false
        }

        // Never activate the captured application here. Doing so can restore a
        // stale first responder and paste into a field after the user has moved
        // to the Desktop, another window, or another control. Delivery is valid
        // only while the exact editor captured at shortcut-down is still the
        // system's current focused editor.
        let targetStillCurrent = focusedElement.map {
            Self.currentFocusedElementMatches(
                $0,
                in: application,
                capturedFrame: frame,
                hitTestLocation: hitTestLocation
            )
        } ?? Self.currentWindowPasteTargetMatches(in: application, capturedFrame: frame)
        guard targetStillCurrent else {
            DictateLog.delivery.info("paste skipped: captured editor is no longer focused")
            return false
        }

        let before = focusedElement.flatMap(Self.textState(of:))
        let pasteboardSnapshot = PasteboardSnapshot.capture()
        guard copyToPasteboard(text) else { return false }
        let temporaryChangeCount = NSPasteboard.general.changeCount
        defer { pasteboardSnapshot.restoreIfUnchanged(expectedChangeCount: temporaryChangeCount) }
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            return false
        }
        down.flags = .maskCommand
        up.flags = .maskCommand

        // The AX lookups and pasteboard write above take real time during
        // which the user can switch apps. Re-check frontmost state right
        // before dispatch so the paste can never land after focus moved.
        guard Self.isCurrentFocusOwner(application, expectedProcessIdentifier: processIdentifier) else {
            DictateLog.delivery.info("paste skipped: captured application lost frontmost before dispatch")
            return false
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)

        do {
            try await Task.sleep(nanoseconds: 350_000_000)
        } catch {
            return false
        }

        // The event was dispatched only after two exact-focus checks. From
        // here, an unreadable AX mutation is not a failure: Zed, Raycast and
        // Electron often hide their text value/range even though the paste
        // landed. Reporting recovery after dispatch can make the user paste a
        // duplicate. Keep mutation inspection as diagnostics, but treat a
        // successfully posted command as delivery.
        if let focusedElement,
           let before,
           let after = Self.textState(of: focusedElement),
           Self.provesInsertion(before: before, after: after, insertedText: text) {
            DictateLog.delivery.debug("paste mutation verified")
        } else {
            DictateLog.delivery.debug("paste dispatched; target does not expose mutation proof")
        }
        return true
    }

    private static func currentWindowPasteTargetMatches(
        in application: NSRunningApplication,
        capturedFrame: CGRect?
    ) -> Bool {
        guard let systemElement = systemFocusedElement(),
              role(of: systemElement) == kAXWindowRole,
              let systemPID = pid(of: systemElement),
              element(processIdentifier: systemPID, belongsTo: application),
              let capturedFrame,
              let currentFrame = frame(of: systemElement),
              framesOverlapSignificantly(currentFrame, capturedFrame),
              editableDescendants(from: systemElement, maxDepth: 8, maxNodes: 600).isEmpty else {
            return false
        }
        return true
    }

    private func isCurrentlyFocusedExternalTarget(_ focusedElement: AXUIElement) -> Bool {
        guard let application = frontmostApplication,
              let processIdentifier,
              !application.isTerminated,
              Self.isCurrentFocusOwner(application, expectedProcessIdentifier: processIdentifier) else {
            return false
        }
        return Self.currentFocusedElementMatches(
            focusedElement,
            in: application,
            capturedFrame: frame,
            hitTestLocation: hitTestLocation
        )
    }

    private static func currentFocusedElementMatches(
        _ focusedElement: AXUIElement,
        in application: NSRunningApplication,
        capturedFrame: CGRect?,
        hitTestLocation: CGPoint?
    ) -> Bool {
        guard let systemElement = systemFocusedElement(),
              let systemElementPID = pid(of: systemElement),
              element(processIdentifier: systemElementPID, belongsTo: application),
              isInFocusedWindow(systemElement, of: application),
              let currentElement = resolvedTextElement(
                systemElement: systemElement,
                application: application,
                hitTestLocation: hitTestLocation
              ),
              let currentElementPID = pid(of: currentElement),
              element(processIdentifier: currentElementPID, belongsTo: application),
              EditableElementClassifier.isEditable(currentElement) else {
            return false
        }
        if CFEqual(currentElement, focusedElement) {
            return true
        }

        // Custom UI frameworks (Raycast, Zed) can recreate AX element proxy
        // objects between queries, so CFEqual can return false even when the
        // same visual field is still focused. Screen position is the stable
        // identity signal there: accept when the current element still
        // overlaps the frame captured at recording start. A non-overlapping
        // frame means focus genuinely moved — that safety property must be
        // preserved.
        guard let capturedFrame, let currentFrame = frame(of: currentElement) else {
            return false
        }
        return framesOverlapSignificantly(currentFrame, capturedFrame)
    }

    /// True when the two frames intersect and the intersection covers at
    /// least half of the smaller frame's area. Zero-area frames are rejected:
    /// they carry no usable position signal and would zero the denominator.
    private static func framesOverlapSignificantly(_ a: CGRect, _ b: CGRect) -> Bool {
        guard a.width > 0, a.height > 0, b.width > 0, b.height > 0 else { return false }
        let intersection = a.intersection(b)
        guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { return false }
        let intersectionArea = intersection.width * intersection.height
        let minArea = min(a.width * a.height, b.width * b.height)
        return intersectionArea / minArea >= 0.5
    }

    private static func pid(of element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(element, &pid) == .success ? pid : nil
    }

    private struct TextState {
        let value: String?
        let selectedRange: NSRange?
        let characterCount: Int?
        let selectedMarkerHash: CFHashCode?
    }

    private static func textState(of element: AXUIElement) -> TextState? {
        var value: CFTypeRef?
        let string: String? = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success
            ? value as? String
            : nil
        let range = selectedRange(of: element)
        let characterCount = integerAttribute(kAXNumberOfCharactersAttribute as CFString, of: element)
        let markerHash = attributeHash("AXSelectedTextMarkerRange" as CFString, of: element)
        guard string != nil || range != nil || characterCount != nil || markerHash != nil else { return nil }
        return TextState(
            value: string,
            selectedRange: range,
            characterCount: characterCount,
            selectedMarkerHash: markerHash
        )
    }

    private static func integerAttribute(_ attribute: CFString, of element: AXUIElement) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return (value as? NSNumber)?.intValue
    }

    private static func attributeHash(_ attribute: CFString, of element: AXUIElement) -> CFHashCode? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value else { return nil }
        return CFHash(value)
    }

    private static func selectedRange(of element: AXUIElement) -> NSRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(unsafeDowncast(value, to: AXValue.self), .cfRange, &range) else { return nil }
        return NSRange(location: range.location, length: range.length)
    }

    private static func provesInsertion(before: TextState, after: TextState, insertedText: String) -> Bool {
        let insertedLength = (insertedText as NSString).length
        if let beforeValue = before.value,
           let afterValue = after.value,
           beforeValue != afterValue,
           let range = before.selectedRange,
           range.location >= 0,
           range.length >= 0,
           range.location <= (beforeValue as NSString).length,
           range.location + range.length <= (beforeValue as NSString).length {
            let expected = (beforeValue as NSString).replacingCharacters(in: range, with: insertedText)
            if afterValue == expected { return true }
        }
        if let beforeValue = before.value,
           let afterValue = after.value,
           beforeValue != afterValue,
           afterValue.contains(insertedText) {
            return true
        }
        if let beforeCount = before.characterCount,
           let afterCount = after.characterCount,
           let range = before.selectedRange,
           afterCount == beforeCount - range.length + insertedLength {
            return true
        }
        if let beforeRange = before.selectedRange,
           let afterRange = after.selectedRange,
           beforeRange != afterRange,
           afterRange.length == 0,
           afterRange.location == beforeRange.location + insertedLength {
            return true
        }
        if let beforeMarker = before.selectedMarkerHash,
           let afterMarker = after.selectedMarkerHash,
           beforeMarker != afterMarker {
            return true
        }
        return false
    }

    private static func systemFocusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused,
              CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(focused, to: AXUIElement.self)
    }

    /// True when this application owns the keyboard/accessibility focus now.
    /// Regular apps must still be the active NSWorkspace frontmost app. An
    /// accessory app is accepted only while the system-wide focused element
    /// belongs to it and it exposes a focused AX window; this is the macOS shape
    /// used by Raycast's non-activating command panel.
    private static func isCurrentFocusOwner(
        _ application: NSRunningApplication,
        expectedProcessIdentifier: pid_t
    ) -> Bool {
        guard !application.isTerminated,
              application.processIdentifier == expectedProcessIdentifier else { return false }

        if application.isActive,
           NSWorkspace.shared.frontmostApplication?.processIdentifier == expectedProcessIdentifier {
            return true
        }

        guard application.activationPolicy == .accessory,
              hasFocusedWindow(application),
              let systemElement = systemFocusedElement(),
              let systemPID = pid(of: systemElement),
              element(processIdentifier: systemPID, belongsTo: application) else {
            return false
        }
        return true
    }

    private static func hasFocusedWindow(_ application: NSRunningApplication) -> Bool {
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        return elementAttribute(applicationElement, kAXFocusedWindowAttribute) != nil
            || elementAttribute(applicationElement, kAXMainWindowAttribute) != nil
    }

    private static func stringAttribute(_ attribute: CFString, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    /// Advisory check only: window membership can never be the reason to
    /// reject a same-PID element. Custom UIs (e.g. Zed's agent chat panel)
    /// can expose a focused window and an element owning window that are
    /// different AX proxy objects even when the element is visibly inside
    /// the focused UI, and custom frameworks can recreate proxies between
    /// queries. Missing attributes on either side also cannot disprove
    /// membership. PID + editable + frame-overlap + click-abandonment are
    /// the real guards; this check exists only to log surprises.
    private static func isInFocusedWindow(_ element: AXUIElement, of application: NSRunningApplication) -> Bool {
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let focusedWindow = elementAttribute(applicationElement, kAXFocusedWindowAttribute)
            ?? elementAttribute(applicationElement, kAXMainWindowAttribute) else { return true }
        guard let elementWindow = owningWindow(of: element) else { return true }
        if CFEqual(focusedWindow, elementWindow) { return true }

        // Both windows exist but are different objects. Tolerate the
        // mismatch: the frame-overlap check upstream is what actually proves
        // the element is still on screen where it was captured.
        let elementWindowRole = role(of: elementWindow) ?? "unknown"
        var message = "focus window mismatch tolerated element=\(elementWindowRole)"
        if let focusedTitle = windowTitle(of: focusedWindow),
           let elementTitle = windowTitle(of: elementWindow) {
            message += " focusedWindowTitle=\(focusedTitle) elementWindowTitle=\(elementTitle)"
        }
        DictateLog.delivery.info("\(message, privacy: .public)")
        return true
    }

    private static func windowTitle(of window: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func owningWindow(of element: AXUIElement) -> AXUIElement? {
        if let window = elementAttribute(element, kAXWindowAttribute) { return window }

        var candidate: AXUIElement? = element
        for _ in 0..<12 {
            guard let current = candidate else { return nil }
            if role(of: current) == kAXWindowRole { return current }
            candidate = elementAttribute(current, kAXParentAttribute)
        }
        return nil
    }

    private static func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    /// kAXFocusedAttribute read as Bool?. Nil when the attribute is absent or
    /// not a boolean; custom UIs may bridge it as NSNumber instead of CFBoolean.
    private static func focusedAttribute(of element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedAttribute as CFString, &value) == .success,
              let value else { return nil }
        if CFGetTypeID(value) == CFBooleanGetTypeID() {
            return CFBooleanGetValue(unsafeDowncast(value, to: CFBoolean.self))
        }
        return (value as? NSNumber)?.boolValue
    }

    /// Children of an element via kAXChildrenAttribute. Attribute errors,
    /// non-array values, and non-element entries count as absent — custom AX
    /// trees are inconsistent and must never crash the capture path.
    private static func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == CFArrayGetTypeID() else { return [] }
        let array = unsafeDowncast(value, to: CFArray.self)
        let count = CFArrayGetCount(array)
        var result: [AXUIElement] = []
        result.reserveCapacity(min(count, 80))
        for index in 0..<count {
            guard let pointer = CFArrayGetValueAtIndex(array, index) else { continue }
            let item = Unmanaged<CFTypeRef>.fromOpaque(pointer).takeUnretainedValue()
            guard CFGetTypeID(item) == AXUIElementGetTypeID() else { continue }
            result.append(unsafeDowncast(item, to: AXUIElement.self))
        }
        return result
    }

    /// Bounded diagnostic dump of an AX subtree: DFS, two-space indentation per
    /// level, capped at maxDepth levels and maxNodes lines so a pathological
    /// tree (Zed's editor) can never stall a failing capture.
    private static func describeTree(root: AXUIElement, maxDepth: Int = 5, maxNodes: Int = 250) -> [String] {
        var lines: [String] = []
        var visited = 0

        func visit(_ element: AXUIElement, depth: Int) {
            guard visited < maxNodes else { return }
            visited += 1

            var subroleValue: CFTypeRef?
            let subrole = (AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleValue) == .success
                ? (subroleValue as? String) : nil) ?? "none"
            let roleString = role(of: element) ?? "unknown"
            let editable = EditableElementClassifier.isEditable(element) ? "1" : "0"
            let focused = focusedAttribute(of: element).map { $0 ? "1" : "0" } ?? "-"
            let pidString = pid(of: element).map { "\($0)" } ?? "-"
            let frameDescription = frame(of: element).map {
                "\($0.origin.x),\($0.origin.y) \($0.size.width)x\($0.size.height)"
            } ?? "none"

            let indent = String(repeating: "  ", count: depth)
            lines.append("\(indent)role=\(roleString) sub=\(subrole) editable=\(editable) focused=\(focused) pid=\(pidString) frame=\(frameDescription)")

            guard depth < maxDepth else { return }
            for child in children(of: element) {
                guard visited < maxNodes else { return }
                visit(child, depth: depth + 1)
            }
        }

        visit(root, depth: 0)
        return lines
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

    /// Accessibility elements exposed by WebKit/Electron may be owned by a
    /// helper process rather than the frontmost application's main process.
    /// Treat a helper with the same bundle family as part of that application,
    /// while still rejecting a stale element from an unrelated/background app.
    private static func element(processIdentifier: pid_t?, belongsTo application: NSRunningApplication) -> Bool {
        guard let processIdentifier,
              processIdentifier != ProcessInfo.processInfo.processIdentifier else { return false }
        if processIdentifier == application.processIdentifier { return true }

        guard let elementApplication = NSRunningApplication(processIdentifier: processIdentifier),
              !elementApplication.isTerminated,
              let applicationBundle = application.bundleIdentifier?.lowercased(),
              let elementBundle = elementApplication.bundleIdentifier?.lowercased() else { return false }
        return elementBundle == applicationBundle ||
            elementBundle.hasPrefix(applicationBundle + ".") ||
            applicationBundle.hasPrefix(elementBundle + ".")
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
        guard PasteboardRestorationPolicy.shouldRestore(
            temporaryChangeCount: expectedChangeCount,
            currentChangeCount: pasteboard.changeCount
        ) else {
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
        "AXSearchField",
        // Additional role strings reported by custom or cross-platform UIs
        // (Zed, Electron, and friends) not covered by the standard constants
        // above.
        "AXTextField",
        "AXTextArea",
        "AXComboBox",
        "AXMultilineTextArea",
        "NSTextView",
        "textbox",
        "textarea"
    ]

    static func isEditable(_ element: AXUIElement) -> Bool {
        guard let role = role(of: element) else { return false }
        if editableRoles.contains(role) { return true }

        // Never infer editability from a readable selected-range attribute on
        // generic containers. Chromium/WebKit expose that attribute on whole
        // AXWebArea/AXGroup trees, and AppKit can expose it on buttons and
        // windows. Treating those containers as fields gives them a full-window
        // frame and makes a click on blank space look like an active caret.
        let structuralRoles: Set<String> = [
            kAXApplicationRole,
            kAXWindowRole,
            kAXGroupRole,
            kAXScrollAreaRole,
            kAXButtonRole,
            kAXStaticTextRole,
            "AXWebArea",
            "AXToolbar",
            "AXSplitGroup",
            "AXSheet",
            "AXDialog"
        ]
        if structuralRoles.contains(role) { return false }

        // A custom role is accepted only when it exposes a text mutation
        // surface. Readability alone is deliberately insufficient: it is
        // inherited by many read-only accessibility proxies.
        return isSettable(kAXSelectedTextAttribute as CFString, on: element) ||
            isSettable(kAXValueAttribute as CFString, on: element)
    }

    private static func isSettable(_ attribute: CFString, on element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute, &settable) == .success && settable.boolValue
    }

    static func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
