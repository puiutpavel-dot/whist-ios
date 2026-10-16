import SwiftUI

@main
struct WhistApp: App {
    init() {
        if ScreenshotMode.shot == 1 { ScreenshotMode.prepareHomeStats() }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let shot = ScreenshotMode.shot, shot >= 2 {
                    GameView(engine: ScreenshotMode.engine(for: shot), showScores: shot == 5)
                } else {
                    HomeView()
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

struct HomeView: View {
    @AppStorage("players") private var playerCount = 4
    @AppStorage("format") private var formatRaw = GameFormat.oneEightOne.rawValue
    @AppStorage("streakBonus") private var streakBonus = true
    @AppStorage("forehead") private var forehead = true
    @AppStorage("speed") private var speed = 1.0
    @AppStorage("gamesPlayed") private var gamesPlayed = 0
    @AppStorage("gamesWon") private var gamesWon = 0
    @AppStorage("bestScore") private var bestScore = 0

    @State private var playing = false
    @State private var showRules = false

    private var settings: GameSettings {
        GameSettings(playerCount: playerCount,
                     format: GameFormat(rawValue: formatRaw) ?? .oneEightOne,
                     streakBonus: streakBonus,
                     forehead: forehead,
                     speed: speed)
    }

    var body: some View {
        ZStack {
            Theme.backdrop
            ScrollView {
                VStack(spacing: 20) {
                    hero.padding(.top, 8)

                    VStack(spacing: 12) {
                        Button("Joc nou") { playing = true }
                            .buttonStyle(PrimaryButtonStyle())
                        Button("Reguli") { showRules = true }
                            .buttonStyle(SecondaryButtonStyle())
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        Text("SETĂRI MASĂ").font(Theme.display(22)).foregroundStyle(Theme.ink)
                        label("Jucători")
                        Pills(options: [3, 4, 5, 6], selection: $playerCount) { "\($0)" }
                        Text("Tu + \(playerCount - 1) adversari · \(GameSettings.handSizes(players: playerCount, format: settings.format).count) mâini")
                            .font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)

                        Divider().overlay(Theme.line)

                        label("Format")
                        Pills(options: GameFormat.allCases.map(\.rawValue), selection: $formatRaw) { $0 }
                        Text(settings.format.subtitle)
                            .font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)

                        Divider().overlay(Theme.line)

                        Toggle(isOn: $streakBonus) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Premii pentru serii").font(Theme.font(16, .semibold)).foregroundStyle(Theme.ink)
                                Text("±10 puncte la 5 contracte reușite / ratate la rând")
                                    .font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
                            }
                        }
                        .tint(Theme.primary)

                        Divider().overlay(Theme.line)

                        Toggle(isOn: $forehead) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Cartea pe frunte").font(Theme.font(16, .semibold)).foregroundStyle(Theme.ink)
                                Text("Ultima serie de mâini de o carte: nu-ți vezi cartea, le vezi pe ale celorlalți")
                                    .font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
                            }
                        }
                        .tint(Theme.primary)

                        Divider().overlay(Theme.line)

                        label("Viteza adversarilor")
                        Pills(options: [0.6, 1.0, 1.8], selection: $speed) {
                            $0 < 0.9 ? "Lent" : ($0 < 1.5 ? "Normal" : "Rapid")
                        }
                    }
                    .panel(padding: 20)

                    stats
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
        }
        .fullScreenCover(isPresented: $playing) {
            GameView(settings: settings) { result in
                gamesPlayed += 1
                if result.won { gamesWon += 1 }
                bestScore = max(bestScore, result.score)
            }
        }
        .sheet(isPresented: $showRules) { RulesView() }
    }

    /// Banner roșu cu evantai de cărți (desen propriu) și titlu condensat.
    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [Theme.accent, Theme.accentDk, Color(hex: 0x3A0209)],
                                     startPoint: .topTrailing, endPoint: .bottomLeading))
            // evantai de cărți în dreapta
            ZStack {
                ForEach(0..<7) { i in
                    CardBackView(width: 66)
                        .rotationEffect(.degrees(Double(i - 3) * 17), anchor: .bottom)
                        .offset(y: -34)
                }
                CardView(card: Card(suit: .spades, rank: 14), width: 60)
                    .rotationEffect(.degrees(-8)).offset(x: -20, y: 46)
                CardView(card: Card(suit: .hearts, rank: 13), width: 60)
                    .rotationEffect(.degrees(9)).offset(x: 22, y: 50)
            }
            .frame(width: 190, height: 200)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 4).padding(.top, 18)
            .opacity(0.95)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    GoldTag(text: "1-8-1")
                    GoldTag(text: "8-1-8")
                }
                Text("WHIST").font(Theme.display(64)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                Text("Jocul românesc de levate").font(Theme.font(15, .semibold)).foregroundStyle(.white.opacity(0.85))
            }
            .padding(20)
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var stats: some View {
        HStack(spacing: 12) {
            stat("\(gamesPlayed)", "Jocuri")
            stat("\(gamesWon)", "Victorii")
            stat("\(bestScore)", "Record")
        }
    }

    private func stat(_ value: String, _ title: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(Theme.display(30)).foregroundStyle(Theme.ink)
            Text(title.uppercased()).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .panel(padding: 14)
    }

    private func label(_ s: String) -> some View {
        Text(s.uppercased()).font(.system(size: 12, weight: .heavy)).kerning(0.6).foregroundStyle(Theme.muted)
    }
}

struct Pills<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let title: (T) -> String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { opt in
                let on = opt == selection
                Button {
                    withAnimation(.spring(response: 0.3)) { selection = opt }
                    Haptics.tap()
                } label: {
                    Text(title(opt))
                        .font(Theme.font(16, .bold))
                        .foregroundStyle(on ? Theme.onPrimary : Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(on ? Theme.primary : Theme.soft))
                        .overlay(Capsule().strokeBorder(on ? .clear : Theme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
