import SwiftUI
import MarblezzzCore

enum BoardTheme: String, CaseIterable, Identifiable {
    case original, walnut, coastal
    var id: String { rawValue }
    var name: String { switch self { case .original: "Original maple"; case .walnut: "Midnight walnut"; case .coastal: "Coastal oak" } }
    var productID: String? { switch self { case .original: nil; case .walnut: ProductID.walnut; case .coastal: ProductID.coastal } }
    var wood: UIColor {
        switch self { case .original: UIColor(hex: 0xCFA66D); case .walnut: UIColor(hex: 0x705442); case .coastal: UIColor(hex: 0xD9CEC0) }
    }
    var woodDark: UIColor {
        switch self { case .original: UIColor(hex: 0x9B7144); case .walnut: UIColor(hex: 0x342922); case .coastal: UIColor(hex: 0xA79D8E) }
    }
    var cardBack: Color { switch self { case .original: Palette.pine; case .walnut: Color(hex: 0x40334F); case .coastal: Color(hex: 0x3F7382) } }
}

enum Palette {
    static let background = Color(hex: 0xF5F1E8)
    static let pine = Color(hex: 0x273F36)
    static let secondary = Color(hex: 0x5D6D61)
    static let cream = Color(hex: 0xFFFCF4)
    static let gold = Color(hex: 0xB38745)
}

extension Seat {
    var uiColor: UIColor {
        switch self { case .red: UIColor(hex: 0xB94044); case .yellow: UIColor(hex: 0xE8B938); case .green: UIColor(hex: 0x397559); case .blue: UIColor(hex: 0x3D77B7) }
    }
    var color: Color { Color(uiColor: uiColor) }
    var glyph: String { ["◆", "✦", "♣", "▲"][rawValue] }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha: 1)
    }
}
extension Color { init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) } }

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17)
            .foregroundStyle(Palette.cream).background(Palette.pine.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct CardFace: View {
    let card: Card
    var selected = false
    var playable = true
    @ScaledMetric(relativeTo: .title2) private var rankSize: CGFloat = 27
    @ScaledMetric(relativeTo: .title2) private var suitSize: CGFloat = 21
    @ScaledMetric(relativeTo: .title2) private var cardWidth: CGFloat = 53
    @ScaledMetric(relativeTo: .title2) private var cardHeight: CGFloat = 77
    var body: some View {
        VStack(spacing: 2) {
            Text(card.rankLabel).font(.system(size: rankSize, weight: .semibold, design: .serif))
            Text(card.suit.symbol).font(.system(size: suitSize))
        }
        .foregroundStyle(playable ? (card.suit.isRed ? Seat.red.color : Palette.pine) : Palette.secondary)
        .frame(width: cardWidth, height: cardHeight)
        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected ? Palette.gold : Palette.pine.opacity(0.13), lineWidth: selected ? 3 : 1))
        .shadow(color: .black.opacity(selected ? 0.13 : 0.05), radius: selected ? 7 : 3, y: 3)
        .offset(y: selected ? -5 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.label), \(card.rule)\(playable ? "" : ", not playable")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
