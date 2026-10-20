import SwiftUI

struct CardView: View {
    let card: Card
    var width: CGFloat = 64
    var dimmed = false
    var glow = false

    private var height: CGFloat { width * 1.42 }
    private var color: Color { card.suit.isRed ? Theme.cardRed : Theme.cardInk }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
                .fill(Theme.cardFace)
                .shadow(color: .black.opacity(0.45), radius: width * 0.08, y: width * 0.05)
            RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
                .strokeBorder(glow ? Theme.gold : Theme.cardEdge, lineWidth: glow ? 3 : 0.75)

            VStack(spacing: -2) {
                Text(card.rankLabel).font(.system(size: width * 0.31, weight: .heavy).width(.condensed))
                Text(card.suit.symbol).font(.system(size: width * 0.22))
            }
            .foregroundStyle(color)
            .padding(.leading, width * 0.09)
            .padding(.top, width * 0.07)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text(card.suit.symbol)
                .font(.system(size: width * 0.55))
                .foregroundStyle(color)
                .offset(x: width * 0.10, y: width * 0.18)
        }
        .frame(width: width, height: height)
        .overlay(
            RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
                .fill(Color.black.opacity(dimmed ? 0.5 : 0))
        )
        .shadow(color: glow ? Theme.gold.opacity(0.6) : .clear, radius: 10)
        .accessibilityLabel(L("w.card.a11y", card.rankLabel, card.suit.name))
    }
}

/// Spatele cărții: roșu, cu un model geometric de romburi (desen propriu).
struct CardBackView: View {
    var width: CGFloat = 30
    var emblem: String = "♠"
    var body: some View {
        let r = width * 0.14
        ZStack {
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(LinearGradient(colors: [Theme.accent, Theme.accentDk],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            DiamondLattice()
                .stroke(Color.white.opacity(0.22), lineWidth: max(0.5, width * 0.012))
                .padding(width * 0.1)
                .clipShape(RoundedRectangle(cornerRadius: r * 0.6, style: .continuous))
            RoundedRectangle(cornerRadius: r * 0.6, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: max(0.5, width * 0.02))
                .padding(width * 0.1)
            if width >= 24 {
                Text(emblem)
                    .font(.system(size: width * 0.34, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: width * 0.48, height: width * 0.48)
                    .background(Circle().fill(Theme.accentDk))
                    .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: max(0.5, width * 0.015)))
            }
        }
        .frame(width: width, height: width * 1.42)
        .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
    }
}

private struct DiamondLattice: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step = max(rect.width / 5, 3)
        var x = -rect.height
        while x < rect.width + rect.height {
            p.move(to: CGPoint(x: x, y: rect.minY))
            p.addLine(to: CGPoint(x: x + rect.height, y: rect.maxY))
            p.move(to: CGPoint(x: x + rect.height, y: rect.minY))
            p.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += step
        }
        return p
    }
}

struct AvatarView: View {
    let name: String
    let index: Int
    var size: CGFloat = 44
    private var fill: Color { Theme.avatarColors[index % Theme.avatarColors.count] }
    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.46, weight: .black).width(.compressed))
            .foregroundStyle(index % Theme.avatarColors.count == 2 || index == 0 ? Color.black : .white)
            .frame(width: size, height: size)
            .background(Circle().fill(fill))
            .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
    }
}
