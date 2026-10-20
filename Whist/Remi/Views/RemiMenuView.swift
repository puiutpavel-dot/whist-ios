import SwiftUI

struct RemiMenuView: View {
    @AppStorage("playerCount") private var playerCount = 4
    @AppStorage("handsToPlay") private var handsToPlay = 3
    @AppStorage("playerName") private var playerName = ""
    @State private var engine: RemiEngine?
    @State private var showRules = false

    var body: some View {
        ZStack {
            RemiTheme.background.ignoresSafeArea()
            RadialGradient(colors: [RemiTheme.crimsonDark.opacity(0.55), .clear],
                           center: .top, startRadius: 10, endRadius: 460)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 26) {
                    hero
                    settings
                    VStack(spacing: 12) {
                        Button {
                            engine = RemiEngine(playerCount: playerCount, hands: handsToPlay, playerName: playerName)
                        } label: {
                            Label(L("menu.play"), systemImage: "play.fill")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Capsule().fill(RemiTheme.crimsonGradient))
                                .overlay(Capsule().strokeBorder(RemiTheme.gold.opacity(0.6)))
                                .foregroundStyle(.white)
                                .shadow(color: RemiTheme.crimson.opacity(0.5), radius: 14, y: 6)
                        }
                        Button { showRules = true } label: {
                            Label(L("menu.rules"), systemImage: "book.closed.fill")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Capsule().fill(RemiTheme.panelLight))
                                .foregroundStyle(RemiTheme.gold)
                        }
                    }
                }
                .padding(24)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: Binding(
            get: { engine.map { RemiEngineBox(engine: $0) } },
            set: { if $0 == nil { engine?.stop(); engine = nil } }
        )) { box in
            RemiGameView(engine: box.engine)
        }
        .sheet(isPresented: $showRules) { RemiRulesView() }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                ForEach(Array(heroTiles.enumerated()), id: \.offset) { i, tile in
                    TileView(tile: tile, size: .hand)
                        .scaleEffect(1.35)
                        .rotationEffect(.degrees(Double(i - 2) * 11), anchor: .bottom)
                        .offset(x: CGFloat(i - 2) * 30, y: abs(CGFloat(i - 2)) * 7)
                }
            }
            .frame(height: 110)
            .padding(.top, 30)

            VStack(spacing: 2) {
                Text(verbatim: "Remi")
                    .font(.system(size: 54, weight: .black, design: .serif))
                    .foregroundStyle(
                        LinearGradient(colors: [RemiTheme.gold, Color(red: 0.85, green: 0.55, blue: 0.2)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                Text(verbatim: "E T A L A T")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Text(L("menu.tagline"))
                .font(.footnote)
                .foregroundStyle(RemiTheme.textDim)
        }
    }

    private var heroTiles: [Tile] {
        [Tile(id: -1, color: .blue, number: 11),
         Tile(id: -2, color: .blue, number: 12),
         Tile(id: -3, color: nil, number: 0),
         Tile(id: -4, color: .red, number: 1),
         Tile(id: -5, color: .yellow, number: 1)]
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("menu.yourName")).sectionLabel()
                TextField(L("name.you"), text: $playerName)
                    .textInputAutocapitalization(.words)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(RemiTheme.panelLight))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(L("menu.players")).sectionLabel()
                Picker(L("menu.players"), selection: $playerCount) {
                    Text(verbatim: "2").tag(2)
                    Text(verbatim: "3").tag(3)
                    Text(verbatim: "4").tag(4)
                }
                .pickerStyle(.segmented)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(L("menu.hands")).sectionLabel()
                Picker(L("menu.hands"), selection: $handsToPlay) {
                    Text(verbatim: "1").tag(1)
                    Text(verbatim: "3").tag(3)
                    Text(verbatim: "5").tag(5)
                    Text(verbatim: "10").tag(10)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(RemiTheme.panel))
    }
}

private struct RemiEngineBox: Identifiable {
    let engine: RemiEngine
    var id: ObjectIdentifier { ObjectIdentifier(engine) }
}

private extension Text {
    func sectionLabel() -> some View {
        self.font(.system(size: 11, weight: .heavy))
            .tracking(1.5)
            .foregroundStyle(RemiTheme.gold)
    }
}
