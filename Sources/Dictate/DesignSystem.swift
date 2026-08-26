import AppKit
import SwiftUI

enum DesignSystem {
    enum ColorToken {
        // Color Index is authored as a paired light/dark system. The dynamic
        // NSColor keeps the tokens semantic while allowing the existing views
        // to follow the app's persisted appearance without scattering RGB values.
        static let background = adaptive(light: (0xF7, 0xF6, 0xF2), dark: (0x15, 0x15, 0x12))
        static let surface = adaptive(light: (0xFF, 0xFF, 0xFF), dark: (0x20, 0x20, 0x1D))
        static let raisedSurface = adaptive(light: (0xFB, 0xFA, 0xF7), dark: (0x29, 0x29, 0x25))
        static let primaryText = adaptive(light: (0x11, 0x11, 0x0F), dark: (0xF3, 0xF0, 0xE7))
        static let secondaryText = adaptive(light: (0x68, 0x68, 0x61), dark: (0xAA, 0xA7, 0x9D))
        static let disabledText = adaptive(light: (0xA7, 0xA6, 0x9F), dark: (0x6E, 0x6D, 0x65))
        static let inverseText = adaptive(light: (0xFF, 0xFF, 0xFF), dark: (0x11, 0x11, 0x0F))
        static let border = adaptive(light: (0xDD, 0xDC, 0xD5), dark: (0x3A, 0x3A, 0x34))
        static let focusRing = adaptive(light: (0x31, 0x55, 0xD9), dark: (0x73, 0x90, 0xFF))
        static let action = adaptive(light: (0x31, 0x55, 0xD9), dark: (0x73, 0x90, 0xFF))
        static let listening = adaptive(light: (0x31, 0x55, 0xD9), dark: (0x73, 0x90, 0xFF))
        static let success = adaptive(light: (0x4E, 0x7C, 0x62), dark: (0x69, 0xB7, 0x83))
        static let warning = adaptive(light: (0xE5, 0xAA, 0x2F), dark: (0xF0, 0xBE, 0x4F))
        static let failure = adaptive(light: (0xC9, 0x4B, 0x43), dark: (0xF0, 0x6A, 0x5E))
        static let overlay = adaptive(light: (0xFF, 0xFF, 0xFF), dark: (0x20, 0x20, 0x1D))
        static let sidebarBackground = adaptive(light: (0xF0, 0xF1, 0xF6), dark: (0x17, 0x18, 0x1D))
        static let cardBackground = adaptive(light: (0xFF, 0xFF, 0xFF), dark: (0x20, 0x21, 0x27))
        static let sidebarSelection = adaptive(light: (0xE1, 0xDE, 0xFF), dark: (0x3B, 0x35, 0x63))
        static let accentViolet = adaptive(light: (0x5D, 0x50, 0xD8), dark: (0xA0, 0x8C, 0xFF))
        static let accentBlue = adaptive(light: (0x2E, 0x73, 0xE6), dark: (0x75, 0xA5, 0xFF))
        static let amberIndex = adaptive(light: (0xE5, 0xAA, 0x2F), dark: (0xF0, 0xBE, 0x4F))
        static let mossIndex = adaptive(light: (0x4E, 0x7C, 0x62), dark: (0x69, 0xB7, 0x83))
        static let coralIndex = adaptive(light: (0xC9, 0x4B, 0x43), dark: (0xF0, 0x6A, 0x5E))

        // Compatibility aliases for the repaired non-UI code and small views.
        static let canvas = background
        static let ink = primaryText
        static let mutedInk = secondaryText
        static let hairline = border
        static let recording = failure

        private static func adaptive(light: (Int, Int, Int), dark: (Int, Int, Int)) -> Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                let rgb = isDark ? dark : light
                return NSColor(
                    calibratedRed: CGFloat(rgb.0) / 255,
                    green: CGFloat(rgb.1) / 255,
                    blue: CGFloat(rgb.2) / 255,
                    alpha: 1
                )
            })
        }
    }

    enum Layout {
        static let hairline = 1.0
        static let topBarHeight = 52.0
        static let mainMinWidth = 1180.0
        static let mainMinHeight = 580.0
        static let mainIdealWidth = 1280.0
        static let mainIdealHeight = 680.0
        static let sidebarWidth = 224.0
        static let historySearchWidth = 220.0
        static let dictionaryListWidth = 365.0
        static let dictionaryColumnMinWidth = 340.0
        static let dictionaryColumnIdealWidth = 380.0
        static let dictionaryColumnMaxWidth = 430.0
        static let onboardingWidth = 560.0
        static let onboardingHeight = 620.0
        static let settingsWidth = 1040.0
        static let settingsHeight = 620.0
        static let shortcutRecorderHeight = 32.0
        static let breathLineHeight = 12.0
        static let breathLineWidth = 1.5
        static let breathLineActiveHeight = 2.0
        // The ready indicator stays deliberately tiny during everyday work.
        // Active, processing, and recovery states expand to the full pebble.
        static let overlayReadyWidth = 38.0
        static let overlayReadyHeight = 18.0
        static let overlayWidth = 62.0
        static let overlaySetupWidth = 146.0
        static let overlayLoadedWidth = 152.0
        static let overlayHostWidth = 152.0
        static let overlayHeight = 22.0
        static let overlayBottomInset = 22.0
        static let radiusField = 8.0
        static let radiusSurface = 12.0
        static let radiusOverlay = 18.0
        static let radiusOverlayReady = 9.0
        static let radiusOverlayCompact = 11.0
        static let radiusOverlayButton = 6.0
        static let space1 = 4.0
        static let space2 = 8.0
        static let space3 = 12.0
        static let space4 = 16.0
        static let space6 = 24.0
        static let space8 = 32.0
        static let space12 = 48.0
        static let transcriptMeasure = 660.0
    }

    enum Motion {
        static let directFeedback = 0.14
        static let stateMorph = 0.22
        static let feedback = directFeedback
        static let start = directFeedback
        static let settle = stateMorph
        static let breathLineSampleInterval = 1.0 / 30.0
        static let breathBaseAmplitude = 1.5
        static let breathLevelAmplitude = 5.0
        static let breathWaveLength = 24.0
        static let breathPhaseSpeed = 4.0
        static let breathSampleStep = 4.0
    }

    enum Shadow {
        static let overlayRadius = 24.0
        static let overlayOpacity = 0.16
        static let overlayY = 8.0
    }
}

extension View {
    func dsFocusRing(_ isFocused: Bool) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusField)
                .stroke(isFocused ? DesignSystem.ColorToken.focusRing : .clear, lineWidth: DesignSystem.Layout.hairline)
        }
    }

    func dsPanel(cornerRadius: CGFloat = DesignSystem.Layout.radiusSurface) -> some View {
        background(DesignSystem.ColorToken.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DesignSystem.ColorToken.border, lineWidth: DesignSystem.Layout.hairline)
            }
    }
}
