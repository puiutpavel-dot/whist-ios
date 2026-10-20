import SwiftUI

@main
struct CardGamesApp: App {
    init() {
        if AppShots.shot == 1 { WhistShots.prepareHomeStats() }
        if WhistShots.isStress { AppShots.runStress() }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let shot = AppShots.shot, shot >= 2 {
                    AppShots.screen(for: shot)
                } else {
                    HubView()
                }
            }
            .preferredColorScheme(.dark)
            .tint(Theme.gold)
        }
    }
}

// MARK: - Meniul principal

enum CardGame: String, Hashable, CaseIterable, Identifiable {
    case whist, remi, rentz
    var id: String { rawValue }
}

struct HubView: View {
    @State private var path: [CardGame] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.backdrop
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("hub.title")).font(Theme.display(46)).foregroundStyle(Theme.ink)
                            Text(L("hub.subtitle")).font(Theme.font(15, .semibold)).foregroundStyle(Theme.muted)
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 4)

                        ForEach(CardGame.allCases) { g in
                            Button { path.append(g) } label: { GameTile(game: g) }
                                .buttonStyle(TileButtonStyle())
                        }

                        Text(L("hub.footer"))
                            .font(Theme.font(12, .medium)).foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                            .padding(.top, 6).padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle(L("hub.back"))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CardGame.self) { g in
                Group {
                    switch g {
                    case .whist: WhistHomeView()
                    case .remi: RemiMenuView()
                    case .rentz: RentzMenuView()
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
            }
        }
    }
}

private struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}

/// Cartea fiecărui joc din meniu: culoare proprie, desen propriu, nume și o descriere scurtă.
private struct GameTile: View {
    let game: CardGame

    private var colors: [Color] {
        switch game {
        case .whist: return [Theme.accent, Theme.accentDk, Color(hex: 0x3A0209)]
        case .remi: return [Color(hex: 0x0F6B45), Color(hex: 0x074029), Color(hex: 0x03190F)]
        case .rentz: return [Theme.violet, Color(hex: 0x3B2E9E), Color(hex: 0x17123F)]
        }
    }
    private var title: String {
        switch game { case .whist: return "WHIST"; case .remi: return "REMI"; case .rentz: return "RENȚ" }
    }
    private var desc: String { L("hub.\(game.rawValue).desc") }
    private var players: String {
        switch game { case .whist, .rentz: return "3–6"; case .remi: return "2–4" }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .topTrailing, endPoint: .bottomLeading))
            art
                .frame(width: 150, height: 150)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 6).padding(.top, 14)
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: title).font(Theme.display(48)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
                Text(desc).font(Theme.font(14, .semibold)).foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 230, alignment: .leading)
                HStack(spacing: 8) {
                    Label(L("hub.play"), systemImage: "play.fill")
                        .font(Theme.font(14, .bold)).foregroundStyle(Theme.onPrimary)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(Theme.primary))
                    Label(players, systemImage: "person.2.fill")
                        .font(Theme.font(13, .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Capsule().fill(.black.opacity(0.25)))
                }
                .padding(.top, 4)
            }
            .padding(18)
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }

    @ViewBuilder
    private var art: some View {
        switch game {
        case .whist:
            ZStack {
                ForEach(0..<5) { i in
                    CardBackView(width: 50)
                        .rotationEffect(.degrees(Double(i - 2) * 16), anchor: .bottom)
                        .offset(y: -20)
                }
                CardView(card: Card(suit: .spades, rank: 14), width: 48)
                    .rotationEffect(.degrees(-8)).offset(x: -14, y: 34)
                CardView(card: Card(suit: .hearts, rank: 13), width: 48)
                    .rotationEffect(.degrees(9)).offset(x: 18, y: 38)
            }
        case .remi:
            VStack(spacing: 8) {
                HStack(spacing: 3) {
                    ForEach(Array([(TileColor.blue, 11), (.blue, 12), (.blue, 13)].enumerated()), id: \.offset) { i, t in
                        TileView(tile: Tile(id: -10 - i, color: t.0, number: t.1), size: .hand)
                    }
                }
                HStack(spacing: 3) {
                    TileView(tile: Tile(id: -20, color: .red, number: 7), size: .hand)
                    TileView(tile: Tile(id: -21, color: nil, number: 0), size: .hand)
                    TileView(tile: Tile(id: -22, color: .black, number: 7), size: .hand)
                }
            }
            .rotationEffect(.degrees(-6))
        case .rentz:
            ZStack {
                ForEach(Array([Suit.hearts, .clubs, .spades].enumerated()), id: \.offset) { i, s in
                    VStack(spacing: -46) {
                        ForEach([12, 11, 10], id: \.self) { r in CardView(card: Card(suit: s, rank: r), width: 38) }
                    }
                    .offset(x: CGFloat(i - 1) * 42)
                }
            }
        }
    }
}
