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
            .preferredColorScheme(.light)
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
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    logo.padding(.top, 24)

                    VStack(alignment: .leading, spacing: 18) {
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

                    VStack(spacing: 12) {
                        Button("Joc nou") { playing = true }
                            .buttonStyle(PrimaryButtonStyle())
                        Button("Reguli") { showRules = true }
                            .buttonStyle(SecondaryButtonStyle())
                    }
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

    private var logo: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.primary, Theme.primaryDk], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 112, height: 112)
                    .shadow(color: Theme.primary.opacity(0.35), radius: 16, y: 8)
                HStack(spacing: -18) {
                    CardView(card: Card(suit: .spades, rank: 14), width: 46).rotationEffect(.degrees(-12))
                    CardView(card: Card(suit: .hearts, rank: 13), width: 46).rotationEffect(.degrees(10)).offset(y: 4)
                }
            }
            Text("Whist").font(Theme.font(38, .heavy)).foregroundStyle(Theme.ink)
            Text("Jocul românesc de levate").font(Theme.font(16, .medium)).foregroundStyle(Theme.muted)
        }
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
            Text(value).font(Theme.font(22, .bold)).foregroundStyle(Theme.primary)
            Text(title).font(Theme.font(12, .medium)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .panel(padding: 14)
    }

    private func label(_ s: String) -> some View {
        Text(s).font(Theme.font(16, .semibold)).foregroundStyle(Theme.ink)
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
                        .foregroundStyle(on ? .white : Theme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? Theme.primary : Theme.soft))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
