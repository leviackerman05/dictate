import CoreGraphics
import Foundation

/// Privacy-safe identity for the editor the user intended to receive text.
/// It deliberately contains no title, URL, document text, or transcript.
public struct FocusTargetFingerprint: Equatable, Sendable {
    public let processIdentifier: Int32
    public let bundleIdentifier: String?
    public let role: String
    public let subrole: String?
    public let frame: CGRect?

    public init(
        processIdentifier: Int32,
        bundleIdentifier: String?,
        role: String,
        subrole: String?,
        frame: CGRect?
    ) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.role = role
        self.subrole = subrole
        self.frame = frame
    }

    public static func == (lhs: FocusTargetFingerprint, rhs: FocusTargetFingerprint) -> Bool {
        lhs.processIdentifier == rhs.processIdentifier &&
            lhs.bundleIdentifier == rhs.bundleIdentifier &&
            lhs.role == rhs.role &&
            lhs.subrole == rhs.subrole &&
            framesEqual(lhs.frame, rhs.frame)
    }

    private static func framesEqual(_ lhs: CGRect?, _ rhs: CGRect?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case let (left?, right?):
            return abs(left.origin.x - right.origin.x) <= 2 &&
                abs(left.origin.y - right.origin.y) <= 2 &&
                abs(left.size.width - right.size.width) <= 2 &&
                abs(left.size.height - right.size.height) <= 2
        default: return false
        }
    }
}

public struct FocusIntentCapture: Equatable, Sendable {
    public let generation: UInt64
    public let fingerprint: FocusTargetFingerprint

    public init(generation: UInt64, fingerprint: FocusTargetFingerprint) {
        self.generation = generation
        self.fingerprint = fingerprint
    }
}

/// Pure policy for deciding whether a pointer event proves that the captured
/// editor was abandoned. Missing AX geometry is not itself abandonment when
/// the same recent pointer hit positively resolved the editable target.
public enum FocusClickIntentPolicy {
    public static func abandonsTarget(
        sameProcess: Bool,
        clickTime: TimeInterval,
        captureTime: TimeInterval,
        clickLocation: CGPoint,
        capturedFrame: CGRect?,
        hitTestConfirmedTarget: Bool,
        focusRestoredAfterClick: Bool,
        preCaptureWindow: TimeInterval = 10,
        margin: CGFloat = 8
    ) -> Bool {
        guard sameProcess else { return false }

        let clickOccurredAfterCapture = clickTime > captureTime
        if !clickOccurredAfterCapture, captureTime - clickTime > preCaptureWindow {
            return false
        }
        if focusRestoredAfterClick { return false }
        if !clickOccurredAfterCapture, hitTestConfirmedTarget { return false }
        if let capturedFrame,
           capturedFrame.insetBy(dx: -margin, dy: -margin).contains(clickLocation) {
            return false
        }
        return true
    }
}

/// Small, deterministic state machine used by AppKit focus delivery.
/// Accessibility callbacks and pointer events can arrive in either order, so
/// delivery requires both the same generation and the same target identity.
public struct FocusIntentTracker: Sendable {
    private var generation: UInt64 = 0
    private var current: FocusTargetFingerprint?
    private var abandoned = false

    public init() {}

    public mutating func begin(_ fingerprint: FocusTargetFingerprint) -> FocusIntentCapture {
        generation &+= 1
        current = fingerprint
        abandoned = false
        return FocusIntentCapture(generation: generation, fingerprint: fingerprint)
    }

    public mutating func focusChanged(to fingerprint: FocusTargetFingerprint?) {
        guard fingerprint != current else { return }
        generation &+= 1
        current = fingerprint
        abandoned = fingerprint == nil
    }

    public mutating func pointerDown(at location: CGPoint, margin: CGFloat = 8) {
        guard let frame = current?.frame else {
            invalidate()
            return
        }
        guard frame.insetBy(dx: -margin, dy: -margin).contains(location) else {
            invalidate()
            return
        }
    }

    public mutating func invalidate() {
        generation &+= 1
        current = nil
        abandoned = true
    }

    public func allows(_ capture: FocusIntentCapture, current fingerprint: FocusTargetFingerprint?) -> Bool {
        guard !abandoned,
              capture.generation == generation,
              capture.fingerprint == current,
              capture.fingerprint == fingerprint else { return false }
        return true
    }
}
