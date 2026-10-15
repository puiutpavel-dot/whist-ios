import SwiftUI

struct CardView: View {
    let card: Card
    var width: CGFloat = 64
    var dimmed = false
    var glow = false

    private var height: CGFloat { width * 1.42 }
    private var color: Color { card.suit.isRed ? Theme.red : Theme.ink }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.16, style: .continuous)
                .fill(Theme.surface)
                .shadow(color: Theme.primaryDk.opacity(0.16), radius: width * 0.08, y: width * 0.04)
            RoundedRectangle(cornerRadius: width * 0.16, style: .continuous)
                .strokeBorder(glow ? Theme.gold : Theme.line, lineWidth: glow ? 3 : 1)

            VStack(spacing: -2) {
                Text(card.rankLabel).font(Theme.font(width * 0.30, .bold))
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
            RoundedRectangle(cornerRadius: width * 0.16, style: .continuous)
                .fill(Color.white.opacity(dimmed ? 0.55 : 0))
        )
        .accessibilityLabel("\(card.rankLabel) de \(card.suit.name)")
    }
}

struct CardBackView: View {
    var width: CGFloat = 30
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.18, style: .continuous)
                .fill(LinearGradient(colors: [Theme.primary, Theme.primaryDk], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
                .padding(width * 0.1)
            Text("♦").font(.system(size: width * 0.4)).foregroundStyle(.white.opacity(0.7))
        }
        .frame(width: width, height: width * 1.42)
        .shadow(color: Theme.primaryDk.opacity(0.2), radius: 3, y: 2)
    }
}

struct AvatarView: View {
    let name: String
    let index: Int
    var size: CGFloat = 44
    var body: some View {
        Text(String(name.prefix(1)))
            .font(Theme.font(size * 0.45, .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Theme.avatarColors[index % Theme.avatarColors.count]))
    }
}
