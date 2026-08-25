import AppKit
import SwiftUI

enum BrandMarkVariant {
    case color
    case monochrome
}

/// Brand artwork decoded once from the SwiftPM resource bundle. `NSImage` is
/// not `Sendable`, so the caches are isolated to the main actor — the same
/// pattern the rest of the UI layer uses — instead of living in unguarded
/// global state.
@MainActor
private enum BrandAsset {
    /// Full-color app icon. This is the exact same SVG the build script
    /// compiles into AppIcon.icns for the Dock, so the in-app mark and the
    /// Dock icon are pixel-identical.
    static let colorMark: NSImage? = load("AppIcon", asTemplate: false)

    /// Menu-bar glyph: the same mark authored as a monochrome mask, tinted at
    /// render time so it stays legible in both light and dark appearance.
    static let monochromeGlyph: NSImage? = load("MenuBarGlyph", asTemplate: true)

    private static func load(_ name: String, asTemplate: Bool) -> NSImage? {
        guard let url = appResourceURL(name),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = asTemplate
        return image
    }

    private static func appResourceURL(_ name: String) -> URL? {
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: "svg"),
            Bundle.main.resourceURL?.appendingPathComponent("Dictate_Dictate.bundle").appendingPathComponent("\(name).svg")
        ]
        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}

struct BrandMark: View {
    let size: CGFloat
    var variant: BrandMarkVariant = .color

    var body: some View {
        Group {
            switch variant {
            case .monochrome:
                if let glyph = BrandAsset.monochromeGlyph {
                    monochromeGlyphView(glyph)
                } else {
                    fallbackCanvasMark
                }
            case .color:
                if let mark = BrandAsset.colorMark {
                    colorMarkView(mark)
                } else {
                    fallbackCanvasMark
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func colorMarkView(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .renderingMode(.original)
            .frame(width: size, height: size)
            // The SVG's rounded square uses a 224/1024 corner radius; scale it
            // with the rendered size so the clip always hugs the artwork.
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
    }

    private func monochromeGlyphView(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .renderingMode(.template)
            .foregroundStyle(DesignSystem.ColorToken.primaryText)
            .frame(width: size, height: size)
    }

    /// Hand-drawn approximation kept only as a safety net: if the bundle
    /// assets ever fail to decode, the brand area still renders something
    /// meaningful instead of an empty frame.
    private var fallbackCanvasMark: some View {
        Canvas { context, canvasSize in
            let unit = min(canvasSize.width, canvasSize.height)
            let isMono = variant == .monochrome
            let markColor = isMono ? DesignSystem.ColorToken.primaryText : Color(red: 247 / 255, green: 246 / 255, blue: 242 / 255)
            let accentColor = isMono ? DesignSystem.ColorToken.primaryText : Color(red: 115 / 255, green: 144 / 255, blue: 255 / 255)

            if !isMono {
                context.fill(
                    Path(roundedRect: CGRect(origin: .zero, size: canvasSize), cornerRadius: unit * 0.225),
                    with: .color(Color(red: 21 / 255, green: 21 / 255, blue: 18 / 255))
                )
            }

            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: unit * x / 1024, y: unit * y / 1024)
            }

            var sentence = Path()
            sentence.move(to: point(724, 294))
            sentence.addLine(to: point(466, 294))
            sentence.addCurve(to: point(270, 458), control1: point(346, 294), control2: point(270, 360))
            sentence.addCurve(to: point(466, 622), control1: point(270, 556), control2: point(346, 622))
            sentence.addLine(to: point(520, 622))
            sentence.addLine(to: point(520, 746))
            sentence.move(to: point(650, 294))
            sentence.addLine(to: point(650, 746))
            context.stroke(
                sentence,
                with: .color(markColor),
                style: StrokeStyle(lineWidth: unit * 72 / 1024, lineCap: .round, lineJoin: .round)
            )
            context.fill(
                Path(ellipseIn: CGRect(
                    x: unit * 376 / 1024,
                    y: unit * 420 / 1024,
                    width: unit * 76 / 1024,
                    height: unit * 76 / 1024
                )),
                with: .color(accentColor)
            )
        }
        .frame(width: size, height: size)
    }
}

struct BrandTitle: View {
    var body: some View {
        HStack(spacing: 8) {
            BrandMark(size: 22)
            Text(Copy.appName)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(DesignSystem.ColorToken.primaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.appName)
    }
}
