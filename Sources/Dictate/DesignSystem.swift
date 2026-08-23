import SwiftUI

enum DesignSystem {
    enum ColorToken {
        static let canvas = Color(red: 0xF3 / 255, green: 0xF6 / 255, blue: 0xF5 / 255)
        static let surface = Color(red: 0xFC / 255, green: 0xFD / 255, blue: 0xFC / 255)
        static let ink = Color(red: 0x18 / 255, green: 0x20 / 255, blue: 0x1E / 255)
        static let mutedInk = Color(red: 0x68 / 255, green: 0x72 / 255, blue: 0x6F / 255)
        static let hairline = Color(red: 0xD6 / 255, green: 0xDD / 255, blue: 0xDA / 255)
        static let action = Color(red: 0x24 / 255, green: 0x5E / 255, blue: 0x52 / 255)
        static let recording = Color(red: 0xE0 / 255, green: 0x5A / 255, blue: 0x47 / 255)
    }

    enum Layout {
        static let hairline = 1.0
        static let sidebarWidth = 220.0
        static let overlayWidth = 196.0
        static let overlayHeight = 38.0
        static let mainMinWidth = 820.0
        static let mainMinHeight = 520.0
        static let historySearchWidth = 220.0
        static let dictionaryColumnMinWidth = 300.0
        static let dictionaryColumnIdealWidth = 340.0
        static let dictionaryColumnMaxWidth = 380.0
        static let onboardingWidth = 520.0
        static let onboardingHeight = 460.0
        static let settingsWidth = 620.0
        static let settingsHeight = 560.0
        static let shortcutRecorderHeight = 32.0
        static let breathLineHeight = 12.0
        static let breathLineWidth = 1.5
        static let breathLineActiveHeight = 2.0
        static let transcriptMeasure = 560.0
        static let radiusField = 6.0
        static let radiusSurface = 10.0
        static let radiusOverlay = 16.0
        static let space1 = 4.0
        static let space2 = 8.0
        static let space3 = 12.0
        static let space4 = 16.0
        static let space6 = 24.0
        static let space8 = 32.0
        static let space12 = 48.0
    }

    enum Motion {
        static let start = 0.16
        static let settle = 0.42
        static let feedback = 0.16
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
                .stroke(isFocused ? DesignSystem.ColorToken.action : .clear, lineWidth: DesignSystem.Layout.hairline)
        }
    }
}
