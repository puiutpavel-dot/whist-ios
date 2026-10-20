import SwiftUI

/// Paleta: sală de joc întunecată, accente roșu-carmin și auriu, masă cu postav verde, piese de fildeș.
enum RemiTheme {
    static let background = Color(red: 0.055, green: 0.055, blue: 0.07)
    static let panel = Color(red: 0.11, green: 0.11, blue: 0.135)
    static let panelLight = Color(red: 0.17, green: 0.17, blue: 0.20)
    static let crimson = Color(red: 0.82, green: 0.04, blue: 0.15)
    static let crimsonDark = Color(red: 0.52, green: 0.02, blue: 0.09)
    static let gold = Color(red: 0.95, green: 0.78, blue: 0.38)
    static let feltLight = Color(red: 0.06, green: 0.42, blue: 0.27)
    static let feltDark = Color(red: 0.02, green: 0.20, blue: 0.13)
    static let ivory = Color(red: 0.99, green: 0.97, blue: 0.91)
    static let ivoryShade = Color(red: 0.87, green: 0.83, blue: 0.73)
    static let woodLight = Color(red: 0.36, green: 0.20, blue: 0.11)
    static let woodDark = Color(red: 0.19, green: 0.10, blue: 0.05)
    static let textDim = Color.white.opacity(0.6)

    static func tileColor(_ c: TileColor?) -> Color {
        switch c {
        case .red: return Color(red: 0.84, green: 0.11, blue: 0.13)
        case .yellow: return Color(red: 0.90, green: 0.58, blue: 0.0)
        case .blue: return Color(red: 0.10, green: 0.36, blue: 0.78)
        case .black: return Color(red: 0.10, green: 0.10, blue: 0.11)
        case nil: return crimson
        }
    }

    static let felt = RadialGradient(colors: [feltLight, feltDark], center: .center, startRadius: 20, endRadius: 420)
    static let crimsonGradient = LinearGradient(colors: [crimson, crimsonDark], startPoint: .top, endPoint: .bottom)
    static let wood = LinearGradient(colors: [woodLight, woodDark], startPoint: .top, endPoint: .bottom)
}

/// Aranjează elementele pe rânduri, trecând pe rândul următor când nu mai e loc.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > bounds.width {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

struct PillButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(prominent ? Color.white : RemiTheme.gold)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(prominent ? AnyShapeStyle(RemiTheme.crimsonGradient) : AnyShapeStyle(RemiTheme.panelLight))
            )
            .overlay(Capsule().strokeBorder(prominent ? RemiTheme.gold.opacity(0.5) : Color.white.opacity(0.08)))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
