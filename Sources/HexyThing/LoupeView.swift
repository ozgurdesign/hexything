import AppKit
import HexyCore
import SwiftUI

final class LoupeModel: ObservableObject {
    @Published var capture: Capture?
    @Published var match: ColourMatch?
    /// ⌥ held: bare triplets read as HSL.
    @Published var optionHeld = false
}

extension NSColor {
    convenience init(_ c: RGBA) {
        self.init(srgbRed: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255, blue: CGFloat(c.b) / 255, alpha: c.a)
    }
}

struct LoupeView: View {
    @ObservedObject var model: LoupeModel

    static let size = CGSize(width: 240, height: 124)
    /// Fraction of the captured strip shown magnified: 80 × 20 pt of 320 × 80 pt, about 3× at 240 × 60.
    private static let zoomFraction = CGSize(width: 0.25, height: 0.25)

    var body: some View {
        VStack(spacing: 0) {
            magnified
                .frame(width: Self.size.width, height: 60)
                .clipped()
                .background(Color(nsColor: .textBackgroundColor))
            Divider()
            footer
                .padding(.horizontal, 12)
                .frame(height: 63)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5))
    }

    @ViewBuilder private var magnified: some View {
        if let capture = model.capture {
            GeometryReader { geo in
                let f = Self.zoomFraction
                // Full image drawn at 1/zoomFraction scale, offset so the cursor sits in the centre.
                let fullW = geo.size.width / f.width
                let fullH = geo.size.height / f.height
                let cx = capture.cursor.x * fullW
                let cy = (1 - capture.cursor.y) * fullH
                ZStack(alignment: .topLeading) {
                    Image(decorative: capture.image, scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: fullW, height: fullH)
                    if let match = model.match {
                        Rectangle()
                            .fill(Color(nsColor: NSColor(match.colour)))
                            .frame(width: match.box.width * fullW, height: 3)
                            .offset(x: match.box.minX * fullW, y: (1 - match.box.minY) * fullH)
                    }
                }
                .offset(x: geo.size.width / 2 - cx, y: geo.size.height / 2 - cy)
            }
        }
    }

    @ViewBuilder private var footer: some View {
        HStack(spacing: 10) {
            if let match = model.match {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: NSColor(match.colour)))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5))
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(match.text)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(hint(for: match)).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary, style: StrokeStyle(lineWidth: 1, dash: [3]))
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("No colour found").font(.system(size: 14)).foregroundStyle(.secondary)
                    Text("Esc to cancel").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private func hint(for match: ColourMatch) -> String {
        guard match.isBare else { return "Click to save · Esc" }
        return model.optionHeld ? "Click to save · ⌥ for RGB · Esc" : "Click to save · ⌥ for HSL · Esc"
    }
}
