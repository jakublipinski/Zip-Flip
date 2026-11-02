import SwiftUI

/// Brand values shared by every screen. See README.md decision 17.
enum Design {
    /// The app's tint and the icon's field colour.
    static let teal = Color(red: 0x6E / 255, green: 0xB6 / 255, blue: 0xCF / 255)
    /// Text on a teal button.
    static let onTeal = Color(red: 0x0B / 255, green: 0x1A / 255, blue: 0x20 / 255)
    /// Cards and grey buttons.
    static let fill = Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255)
    /// Dark glyph on the icon.
    static let glyph = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x13 / 255)
}

/// The icon glyph as a SwiftUI view: two cards, the top one caught mid-turn.
/// Same geometry as tools/makeicon.swift, in a 100-unit box.
struct FlipGlyph: View {
    var color: Color = Design.teal
    var background: Color = .black

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 100
            ZStack {
                RoundedRectangle(cornerRadius: 7 * s, style: .continuous)
                    .fill(color)
                    .frame(width: 52 * s, height: 38 * s)
                    .position(x: 50 * s, y: 55 * s)
                RoundedRectangle(cornerRadius: 7 * s, style: .continuous)
                    .fill(color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7 * s, style: .continuous)
                            .stroke(background, lineWidth: 4 * s)
                    )
                    .frame(width: 52 * s, height: 38 * s)
                    .position(x: 50 * s, y: 46 * s)
                    .rotationEffect(.degrees(-14), anchor: UnitPoint(x: 0.5, y: 0.46))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
