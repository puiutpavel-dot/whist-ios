import SwiftUI

enum TileSize {
    case hand, table, mini

    var width: CGFloat { switch self { case .hand: 40; case .table: 27; case .mini: 22 } }
    var height: CGFloat { switch self { case .hand: 56; case .table: 38; case .mini: 31 } }
    var font: CGFloat { switch self { case .hand: 23; case .table: 16; case .mini: 13 } }
    var corner: CGFloat { switch self { case .hand: 7; case .table: 5; case .mini: 4 } }
    var dot: CGFloat { switch self { case .hand: 6; case .table: 4; case .mini: 3 } }
}

/// O piesă de fildeș cu numărul colorat sau fața de Joker.
struct TileView: View {
    let tile: Tile
    var size: TileSize = .hand
    var selected = false
    var faded = false
    var marked = false   // ex. loc de Joker înlocuit / Joker re-folosit

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                .fill(LinearGradient(colors: [RemiTheme.ivory, RemiTheme.ivoryShade], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                .strokeBorder(Color.black.opacity(0.18), lineWidth: 0.6)
            // Bordura de jos dă impresia de grosime.
            RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                .fill(Color.black.opacity(0.08))
                .frame(height: size.height * 0.12)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(1)

            if tile.isJoker {
                JokerFace(size: size)
            } else {
                VStack(spacing: size == .hand ? 3 : 1) {
                    Text(verbatim: "\(tile.number)")
                        .font(.system(size: size.font, weight: .heavy, design: .rounded))
                        .foregroundStyle(RemiTheme.tileColor(tile.color))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Circle()
                        .fill(RemiTheme.tileColor(tile.color))
                        .frame(width: size.dot, height: size.dot)
                }
                .offset(y: -size.height * 0.04)
            }
            if marked {
                RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                    .strokeBorder(RemiTheme.crimson.opacity(0.8), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay(
            RoundedRectangle(cornerRadius: size.corner + 1, style: .continuous)
                .strokeBorder(RemiTheme.gold, lineWidth: selected ? 2.5 : 0)
        )
        .shadow(color: selected ? RemiTheme.gold.opacity(0.6) : .black.opacity(0.45),
                radius: selected ? 6 : 1.5, y: selected ? 0 : 1.5)
        .offset(y: selected ? -8 : 0)
        .opacity(faded ? 0.45 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selected)
        .accessibilityLabel(tile.label)
    }
}

struct JokerFace: View {
    let size: TileSize
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "face.smiling.inverse")
                .font(.system(size: size.font * 0.95, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [RemiTheme.crimson, Color(red: 0.95, green: 0.55, blue: 0.0)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            if size != .mini {
                Text(L("tile.jokerFace"))
                    .font(.system(size: size.font * 0.32, weight: .black, design: .rounded))
                    .foregroundStyle(RemiTheme.crimsonDark)
                    .padding(.top, 1)
            }
        }
    }
}

/// Spatele unei piese (grămada).
struct TileBack: View {
    var size: TileSize = .table
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                .fill(RemiTheme.crimsonGradient)
            RoundedRectangle(cornerRadius: size.corner - 1, style: .continuous)
                .strokeBorder(RemiTheme.gold.opacity(0.7), lineWidth: 1)
                .padding(2.5)
            Image(systemName: "suit.diamond.fill")
                .font(.system(size: size.font * 0.7))
                .foregroundStyle(RemiTheme.gold.opacity(0.85))
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1.5)
    }
}
