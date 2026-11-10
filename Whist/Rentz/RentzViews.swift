import SwiftUI

extension Theme {
    /// Culoarea Renț-ului în meniu și pe masă.
    static let violet = Color(hex: 0x7B6CF6)
}

// MARK: - Meniu

struct RentzMenuView: View {
    @AppStorage("rentz.players") private var playerCount = 4
    @AppStorage("speed") private var speed = 1.0
    @AppStorage("rentz.games") private var gamesPlayed = 0
    @AppStorage("rentz.wins") private var gamesWon = 0
    @AppStorage("rentz.best") private var bestScore = 0
    @AppStorage("rentz.name") private var playerName = ""
    @AppStorage("rentz.scoring") private var styleRaw = RentzScoring.Style.classic.rawValue
    @AppStorage("rentz.eighth") private var eighthRaw = RentzGame.whist.rawValue
    @State private var playing = false
    @State private var showRules = false

    var body: some View {
        ZStack {
            Theme.backdrop
            ScrollView {
                VStack(spacing: 20) {
                    hero.padding(.top, 8)
                    VStack(spacing: 12) {
                        Button(L("w.menu.new")) { playing = true }.buttonStyle(PrimaryButtonStyle())
                        Button(L("w.menu.rules")) { showRules = true }.buttonStyle(SecondaryButtonStyle())
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        Text(L("w.menu.settings")).font(Theme.display(22)).foregroundStyle(Theme.ink)
                        label(L("r.menu.name"))
                        TextField(L("name.you"), text: $playerName)
                            .font(Theme.font(17, .semibold)).foregroundStyle(Theme.ink)
                            .textInputAutocapitalization(.words).autocorrectionDisabled()
                            .submitLabel(.done)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.soft))
                        Divider().overlay(Theme.line)
                        label(L("w.menu.players"))
                        Pills(options: [3, 4, 5, 6], selection: $playerCount) { "\($0)" }
                        Text(L("r.menu.deckLine", playerCount, playerCount * 8, rankName(Deck.lowestRank(players: playerCount)),
                               playerCount * 8))
                            .font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Divider().overlay(Theme.line)
                        label(L("r.menu.scoring"))
                        Pills(options: RentzScoring.Style.allCases.map(\.rawValue), selection: $styleRaw) {
                            L("r.scoring.\($0)")
                        }
                        Text(scoring.games.first!.short(scoring))
                            .font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
                        Divider().overlay(Theme.line)
                        label(L("r.menu.eighth"))
                        Pills(options: [RentzGame.whist.rawValue, RentzGame.totalsPlus.rawValue], selection: $eighthRaw) {
                            L("r.game.\($0)")
                        }
                        Text((RentzGame(rawValue: eighthRaw) ?? .whist).short(scoring))
                            .font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
                        Divider().overlay(Theme.line)
                        label(L("w.menu.speed"))
                        Pills(options: [0.6, 1.0, 1.8], selection: $speed) {
                            $0 < 0.9 ? L("w.speed.slow") : ($0 < 1.5 ? L("w.speed.normal") : L("w.speed.fast"))
                        }
                    }
                    .panel(padding: 20)
                    HStack(spacing: 12) {
                        stat("\(gamesPlayed)", L("w.stat.games"))
                        stat("\(gamesWon)", L("w.stat.wins"))
                        stat("\(bestScore)", L("w.stat.best"))
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
        }
        .fullScreenCover(isPresented: $playing) {
            RentzGameView(players: playerCount, speed: speed, name: playerName, scoring: scoring) { won, score in
                gamesPlayed += 1
                if won { gamesWon += 1 }
                bestScore = max(bestScore, score)
            }
        }
        .sheet(isPresented: $showRules) { RentzRulesView(scoring: scoring) }
    }

    private var scoring: RentzScoring {
        RentzScoring(style: RentzScoring.Style(rawValue: styleRaw) ?? .classic,
                     eighth: RentzGame(rawValue: eighthRaw) == .totalsPlus ? .totalsPlus : .whist)
    }

    private func rankName(_ r: Int) -> String {
        switch r { case 11: return "J"; case 12: return "Q"; case 13: return "K"; case 14: return "A"; default: return "\(r)" }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [Theme.violet, Color(hex: 0x3B2E9E), Color(hex: 0x17123F)],
                                     startPoint: .topTrailing, endPoint: .bottomLeading))
            ZStack {
                ForEach(Array([Suit.spades, .hearts, .clubs, .diamonds].enumerated()), id: \.offset) { i, s in
                    VStack(spacing: -40) {
                        ForEach([12, 11, 10], id: \.self) { r in
                            CardView(card: Card(suit: s, rank: r), width: 40)
                        }
                    }
                    .offset(x: CGFloat(i) * 44 - 66)
                }
            }
            .frame(width: 190, height: 200)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 6).padding(.top, 22)
            VStack(alignment: .leading, spacing: 6) {
                GoldTag(text: L("r.menu.eightGames"))
                Text(verbatim: "RENȚ").font(Theme.display(64)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                Text(L("r.menu.tagline")).font(Theme.font(15, .semibold)).foregroundStyle(.white.opacity(0.85))
            }
            .padding(20)
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func stat(_ value: String, _ title: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(Theme.display(30)).foregroundStyle(Theme.ink)
            Text(title.uppercased()).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.muted)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .panel(padding: 14)
    }

    private func label(_ s: String) -> some View {
        Text(s.uppercased()).font(.system(size: 12, weight: .heavy)).kerning(0.6).foregroundStyle(Theme.muted)
    }
}

// MARK: - Masa

struct RentzGameView: View {
    @StateObject private var engine: RentzEngine
    @Environment(\.dismiss) private var dismiss
    let onFinish: (Bool, Int) -> Void
    @State private var showScores = false
    @State private var confirmQuit = false
    @State private var reported = false

    init(players: Int, speed: Double, name: String = "", scoring: RentzScoring = RentzScoring(),
         onFinish: @escaping (Bool, Int) -> Void) {
        _engine = StateObject(wrappedValue: RentzEngine(players: players, speed: speed, name: name, scoring: scoring))
        self.onFinish = onFinish
    }

    init(engine: RentzEngine, showScores: Bool = false) {
        _engine = StateObject(wrappedValue: engine)
        _showScores = State(initialValue: showScores)
        _reported = State(initialValue: true)
        onFinish = { _, _ in }
    }

    var body: some View {
        ZStack {
            Theme.backdrop
            GeometryReader { geo in
                let compact = geo.size.height < 720
                VStack(spacing: compact ? 7 : 11) {
                    topBar
                    opponents
                    gameBanner
                    center
                    Spacer(minLength: 0)
                    myStatus
                    RentzHandView(engine: engine)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
                .environment(\.compactLayout, compact)
            }
            if engine.phase == .dealEnd || engine.phase == .gameOver {
                Color.black.opacity(0.6).ignoresSafeArea().transition(.opacity)
                RentzSummaryView(engine: engine,
                                 onNext: { withAnimation(.spring) { engine.nextDeal() } },
                                 onScores: { showScores = true },
                                 onExit: { dismiss() })
                    .padding(20)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: engine.phase)
        .sheet(isPresented: $showScores) { RentzScoreboardView(engine: engine) }
        .confirmationDialog(L("w.quit.title"), isPresented: $confirmQuit, titleVisibility: .visible) {
            Button(L("w.quit.yes"), role: .destructive) { engine.stop(); dismiss() }
            Button(L("w.quit.no"), role: .cancel) {}
        }
        .onChange(of: engine.phase) { _, p in
            guard p == .gameOver, !reported else { return }
            reported = true
            let best = engine.players.map(\.score).max() ?? 0
            let mine = engine.players[engine.human].score
            onFinish(mine == best, mine)
        }
        .onDisappear { engine.stop() }
    }

    private var topBar: some View {
        HStack {
            IconButton(system: "xmark") {
                if engine.phase == .gameOver { dismiss() } else { confirmQuit = true }
            }
            Spacer()
            VStack(spacing: 2) {
                Text(L("r.deal.title", engine.dealIndex + 1, engine.totalDeals))
                    .font(Theme.display(24)).foregroundStyle(Theme.ink)
                Text(L("r.deal.chooser", engine.players[engine.chooser].name))
                    .font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
            }
            Spacer()
            IconButton(system: "list.number") { showScores = true }
                .accessibilityLabel(L("w.scores"))
        }
        .padding(.top, 4)
    }

    private var opponents: some View {
        HStack(spacing: 6) {
            ForEach(engine.players.dropFirst()) { p in
                RentzOpponentChip(player: p, engine: engine)
            }
        }
    }

    @ViewBuilder
    private var gameBanner: some View {
        if let g = engine.game {
            HStack(spacing: 10) {
                Image(systemName: g.icon).font(.system(size: 18, weight: .bold))
                    .foregroundStyle(g.isPositive ? Theme.green : Theme.red)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.soft))
                VStack(alignment: .leading, spacing: 1) {
                    Text(g.name.uppercased()).font(Theme.display(20)).foregroundStyle(Theme.ink)
                    Text(g.short).font(Theme.font(12, .medium)).foregroundStyle(Theme.muted).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        }
    }

    @ViewBuilder
    private var center: some View {
        if engine.phase == .choosing && engine.chooser == engine.human {
            RentzChoosePanel(engine: engine)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if engine.game == .rentz {
            RentzLayoutView(engine: engine)
        } else {
            RentzTrickTable(engine: engine)
        }
    }

    private var myStatus: some View {
        let me = engine.players[engine.human]
        return HStack(spacing: 10) {
            AvatarView(name: me.name, index: 0, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(me.name).font(Theme.font(16, .bold)).foregroundStyle(Theme.ink)
                Text(statusLine(me)).font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(me.score)").font(Theme.font(22, .heavy)).foregroundStyle(Theme.primary)
                Text(L("w.points")).font(Theme.font(11, .medium)).foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 4)
    }

    private func statusLine(_ me: RentzPlayer) -> String {
        guard let g = engine.game else {
            return engine.chooser == engine.human ? L("r.status.choose") : L("r.status.waitChoose", engine.players[engine.chooser].name)
        }
        if g == .rentz {
            if let place = me.place { return L("r.status.place", place) }
            return L("r.status.cardsLeft", me.hand.count)
        }
        return L("r.status.tricks", me.tricks, me.dealPoints)
    }
}

struct RentzOpponentChip: View {
    let player: RentzPlayer
    @ObservedObject var engine: RentzEngine
    @Environment(\.compactLayout) private var compact

    var body: some View {
        let isTurn = player.id == engine.current && engine.phase == .playing
            || (engine.phase == .choosing && player.id == engine.chooser)
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                AvatarView(name: player.name, index: player.id, size: 36)
                    .overlay(Circle().strokeBorder(Theme.gold, lineWidth: isTurn ? 3 : 0).padding(-4))
                if player.id == engine.chooser {
                    Image(systemName: "star.fill").font(.system(size: 9, weight: .black)).foregroundStyle(.black)
                        .frame(width: 16, height: 16).background(Circle().fill(Theme.gold)).offset(x: 6, y: -4)
                }
            }
            .padding(.top, 4)
            Text(verbatim: player.name).font(Theme.font(13, .bold)).foregroundStyle(Theme.ink).lineLimit(1)
            Text(verbatim: detail)
                .font(Theme.font(12, .bold)).foregroundStyle(player.dealPoints < 0 ? Theme.red : player.dealPoints > 0 ? Theme.green : Theme.muted)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Capsule().fill(Theme.soft))
            Text(L("w.pts.short", player.score)).font(Theme.font(11, .semibold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 5 : 8)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isTurn ? Theme.raised : Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(isTurn ? Theme.gold : Theme.line, lineWidth: isTurn ? 1.5 : 1))
    }

    private var detail: String {
        if engine.game == .rentz {
            if let p = player.place { return "#\(p)" }
            return "🃏 \(player.hand.count)"
        }
        if engine.game == nil { return "–" }
        return player.dealPoints == 0 ? "\(player.tricks)" : (player.dealPoints > 0 ? "+\(player.dealPoints)" : "\(player.dealPoints)")
    }
}

// MARK: - Alegerea jocului

struct RentzChoosePanel: View {
    @ObservedObject var engine: RentzEngine
    @Environment(\.compactLayout) private var compact

    var body: some View {
        let open = Set(engine.available(for: engine.human))
        let tip = RentzBot.chooseGameTip(engine: engine)
        VStack(spacing: compact ? 8 : 10) {
            Text(L("r.choose.title")).font(Theme.display(24)).foregroundStyle(Theme.ink)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(engine.games) { g in
                    let ok = open.contains(g)
                    Button {
                        Haptics.tap()
                        withAnimation(.spring) { engine.humanChoose(g) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: g.icon).font(.system(size: 14, weight: .bold))
                                .foregroundStyle(ok ? (g.isPositive ? Theme.green : Theme.red) : Theme.muted)
                                .frame(width: 18)
                            Text(g.name).font(Theme.font(14, .bold))
                                .foregroundStyle(ok ? Theme.ink : Theme.muted)
                                .strikethrough(!ok, color: Theme.muted)
                                .lineLimit(1).minimumScaleFactor(0.75)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: compact ? 36 : 42)
                        .background(Capsule().fill(ok ? Theme.raised : Theme.bg))
                        .overlay(Capsule().strokeBorder(tip == g ? Theme.gold : Theme.line, lineWidth: tip == g ? 2.5 : 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(!ok)
                }
            }
            if let tip {
                CoachTip(title: L("r.choose.tip", tip.name.uppercased()), text: L("r.choose.tipText"))
            }
        }
        .frame(maxWidth: .infinity)
        .panel(padding: compact ? 12 : 14)
    }
}

extension RentzBot {
    /// Sugestia pentru alegerea jocului (fără zgomotul aleator al adversarilor).
    static func chooseGameTip(engine e: RentzEngine) -> RentzGame? {
        guard e.phase == .choosing, e.chooser == e.human else { return nil }
        let hand = e.players[e.human].hand
        return e.available(for: e.human).max {
            expectedValue($0, hand: hand, engine: e) < expectedValue($1, hand: hand, engine: e)
        }
    }
}

// MARK: - Levata

struct RentzTrickTable: View {
    @ObservedObject var engine: RentzEngine
    @Environment(\.compactLayout) private var compact

    var body: some View {
        GeometryReader { geo in
            let n = CGFloat(engine.n)
            let cardW = max(10, min(64, (geo.size.width - 24 - (n - 1) * 6) / n))
            ZStack {
                if engine.trick.isEmpty {
                    VStack(spacing: 6) {
                        Text(headline).font(Theme.font(18, .bold)).foregroundStyle(Theme.ink)
                        if let g = engine.game, engine.phase == .playing {
                            Text(g.short).font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
                        }
                    }
                    .multilineTextAlignment(.center).padding(.horizontal, 12)
                } else {
                    HStack(spacing: 6) {
                        ForEach(engine.trick) { pc in
                            VStack(spacing: 6) {
                                CardView(card: pc.card, width: cardW, glow: pc.player == engine.trickWinner)
                                Text(engine.players[pc.player].name)
                                    .font(Theme.font(12, .semibold))
                                    .foregroundStyle(pc.player == engine.trickWinner ? Theme.ink : Theme.muted)
                                    .lineLimit(1)
                            }
                            .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
                        }
                    }
                }
                if let w = engine.trickWinner {
                    VStack {
                        Spacer()
                        Text(w == engine.human ? L("w.trick.you") : L("w.trick.other", engine.players[w].name))
                            .font(Theme.font(14, .bold))
                            .foregroundStyle(w == engine.human ? Theme.onPrimary : .white)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Capsule().fill(w == engine.human ? Theme.primary : Theme.accent))
                    }
                    .padding(.bottom, 10)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: compact ? 150 : 190)
        .background(TableFelt())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: engine.trick.count)
    }

    private var headline: String {
        let p = engine.players[engine.current]
        switch engine.phase {
        case .choosing: return L("r.status.waitChoose", engine.players[engine.chooser].name)
        case .playing: return p.isHuman ? (engine.trick.isEmpty ? L("w.turn.lead") : L("w.turn.you")) : L("w.turn.playing", p.name)
        default: return ""
        }
    }
}

// MARK: - Renț: cărțile puse pe masă

struct RentzLayoutView: View {
    @ObservedObject var engine: RentzEngine
    @Environment(\.compactLayout) private var compact

    var body: some View {
        let ranks = Array(engine.low...14)
        VStack(spacing: compact ? 4 : 6) {
            ForEach([Suit.spades, .hearts, .clubs, .diamonds], id: \.self) { s in
                HStack(spacing: 2) {
                    Text(s.symbol).font(.system(size: 16, weight: .bold))
                        .foregroundStyle(s.isRed ? Theme.red : Theme.ink).frame(width: 18)
                    ForEach(ranks, id: \.self) { r in
                        let on = engine.rows[s].map { r >= $0.low && r <= $0.high } ?? false
                        Text(Card(suit: s, rank: r).rankLabel)
                            .font(.system(size: 12, weight: .heavy).width(.condensed))
                            .foregroundStyle(on ? (s.isRed ? Theme.cardRed : Theme.cardInk) : Theme.muted.opacity(0.5))
                            .frame(maxWidth: .infinity, minHeight: compact ? 24 : 30)
                            .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(on ? Theme.cardFace : Theme.soft.opacity(0.5)))
                            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(r == 11 ? Theme.gold.opacity(on ? 0 : 0.6) : .clear, lineWidth: 1))
                    }
                }
            }
            Text(engine.lastEvent ?? headline)
                .font(Theme.font(13, .semibold)).foregroundStyle(Theme.ink.opacity(0.85))
                .lineLimit(1).minimumScaleFactor(0.8)
                .padding(.top, 2)
        }
        .padding(10)
        .frame(height: compact ? 150 : 190)
        .background(TableFelt())
        .animation(.spring(response: 0.3), value: engine.rows)
    }

    private var headline: String {
        let p = engine.players[engine.current]
        return p.isHuman ? L("w.turn.you") : L("w.turn.playing", p.name)
    }
}

// MARK: - Mâna

struct RentzHandView: View {
    @ObservedObject var engine: RentzEngine
    @Environment(\.compactLayout) private var compact
    private var maxCardW: CGFloat { compact ? 60 : 74 }

    var body: some View {
        GeometryReader { geo in
            let hand = engine.players[engine.human].hand
            let count = max(hand.count, 1)
            let cardW: CGFloat = min(maxCardW, geo.size.width / 4.6)
            let natural = CGFloat(count) * cardW + CGFloat(count - 1) * 6
            let spacing = natural > geo.size.width
                ? (geo.size.width - CGFloat(count) * cardW) / CGFloat(max(count - 1, 1)) : 6
            let myTurn = engine.phase == .playing && engine.current == engine.human
            let legal = Set(engine.legalCards(for: engine.human))
            HStack(spacing: spacing) {
                ForEach(hand) { card in
                    let canPlay = myTurn && legal.contains(card)
                    let danger = engine.game.map { RentzBot.danger(card, game: $0) > 0 } ?? false
                    CardView(card: card, width: cardW, dimmed: myTurn && !canPlay)
                        .overlay(alignment: .bottom) {
                            if danger && engine.phase == .playing {
                                Capsule().fill(Theme.red).frame(width: cardW * 0.4, height: 3).offset(y: -4)
                            }
                        }
                        .offset(y: canPlay ? -12 : 0)
                        .onTapGesture { engine.humanPlay(card) }
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                                removal: .scale(scale: 0.5).combined(with: .opacity)))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: myTurn)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hand.count)
        }
        .frame(height: maxCardW * 1.42 + 16)
    }
}

// MARK: - Rezumat

struct RentzSummaryView: View {
    @ObservedObject var engine: RentzEngine
    let onNext: () -> Void
    let onScores: () -> Void
    let onExit: () -> Void

    var body: some View {
        let over = engine.phase == .gameOver
        let rec = engine.history.last
        VStack(spacing: 16) {
            if over {
                let best = engine.players.map(\.score).max() ?? 0
                let won = engine.players[engine.human].score == best
                Image(systemName: won ? "trophy.fill" : "flag.checkered")
                    .font(.system(size: 42, weight: .bold)).foregroundStyle(won ? Theme.gold : Theme.primary)
                Text(won ? L("w.won") : L("w.gameOver")).font(Theme.display(40)).foregroundStyle(Theme.ink)
            } else if let rec {
                Image(systemName: rec.game.icon).font(.system(size: 30, weight: .bold))
                    .foregroundStyle(rec.game.isPositive ? Theme.green : Theme.red)
                Text(rec.game.name.uppercased()).font(Theme.display(34)).foregroundStyle(Theme.ink)
                Text(L("r.summary.sub", rec.id + 1, engine.players[rec.chooser].name))
                    .font(Theme.font(14, .medium)).foregroundStyle(Theme.muted)
            }
            VStack(spacing: 8) {
                let order = over ? engine.players.sorted { $0.score > $1.score }.map(\.id) : engine.players.map(\.id)
                ForEach(Array(order.enumerated()), id: \.element) { pos, i in
                    let p = engine.players[i]
                    HStack(spacing: 10) {
                        if over { Text("\(pos + 1)").font(Theme.font(15, .bold)).foregroundStyle(Theme.muted).frame(width: 18) }
                        AvatarView(name: p.name, index: p.id, size: 30)
                        Text(p.name).font(Theme.font(16, .semibold)).foregroundStyle(Theme.ink)
                        Spacer()
                        if !over, let d = rec?.deltas[i] {
                            Text(d > 0 ? "+\(d)" : "\(d)").font(Theme.font(15, .bold))
                                .foregroundStyle(d > 0 ? Theme.green : d < 0 ? Theme.red : Theme.muted)
                        }
                        Text("\(p.score)").font(Theme.font(17, .heavy)).foregroundStyle(Theme.primary)
                            .frame(minWidth: 52, alignment: .trailing)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.isHuman ? Theme.soft : Theme.bg))
                }
            }
            VStack(spacing: 10) {
                if over { Button(L("w.backToMenu"), action: onExit).buttonStyle(PrimaryButtonStyle()) }
                else { Button(L("r.nextDeal"), action: onNext).buttonStyle(PrimaryButtonStyle()) }
                Button(L("w.scores"), action: onScores).buttonStyle(SecondaryButtonStyle())
            }
        }
        .panel(padding: 22)
        .frame(maxWidth: 440)
    }
}

// MARK: - Tabela de scor: cine ce joc a ales, cu punctele fiecăruia

struct RentzScoreboardView: View {
    @ObservedObject var engine: RentzEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Jocurile alese de fiecare
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(engine.players) { p in
                            HStack(spacing: 6) {
                                Text(p.name).font(Theme.font(14, .bold)).foregroundStyle(Theme.ink)
                                    .frame(width: 64, alignment: .leading).lineLimit(1)
                                ForEach(engine.games) { g in
                                    Image(systemName: g.icon).font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(p.chosen.contains(g) ? Color.black : Theme.muted)
                                        .frame(maxWidth: .infinity, minHeight: 26)
                                        .background(RoundedRectangle(cornerRadius: 6).fill(p.chosen.contains(g) ? Theme.gold : Theme.soft))
                                }
                            }
                        }
                    }
                    .panel(padding: 12)

                    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                        GridRow {
                            head(L("r.sb.game"))
                            ForEach(engine.players) { p in head(p.name) }
                        }
                        ForEach(engine.history) { r in
                            GridRow {
                                Text(r.game.name).font(Theme.font(12, .bold)).foregroundStyle(Theme.ink)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                                    .frame(width: 96, height: 32, alignment: .leading).padding(.leading, 6)
                                    .background(r.id.isMultiple(of: 2) ? Theme.surface : Theme.bg)
                                ForEach(engine.players) { p in
                                    let d = r.deltas[p.id]
                                    Text(d == 0 ? "·" : (d > 0 ? "+\(d)" : "\(d)"))
                                        .font(Theme.font(13, p.id == r.chooser ? .heavy : .medium))
                                        .foregroundStyle(d > 0 ? Theme.green : d < 0 ? Theme.red : Theme.muted)
                                        .frame(maxWidth: .infinity, minHeight: 32)
                                        .background(r.id.isMultiple(of: 2) ? Theme.surface : Theme.bg)
                                }
                            }
                        }
                        GridRow {
                            Text(L("r.sb.total")).font(Theme.font(13, .heavy)).foregroundStyle(Theme.ink)
                                .frame(width: 96, height: 36, alignment: .leading).padding(.leading, 6)
                            ForEach(engine.players) { p in
                                Text("\(p.score)").font(Theme.font(14, .heavy)).foregroundStyle(Theme.primary)
                                    .frame(maxWidth: .infinity, minHeight: 36)
                            }
                        }
                        .background(Theme.soft)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle(L("w.scores"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("w.done")) { dismiss() }.font(Theme.font(17, .bold))
                }
            }
        }
    }

    private func head(_ s: String) -> some View {
        Text(s.uppercased()).font(.system(size: 12, weight: .heavy)).foregroundStyle(.white).lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(Theme.violet)
    }
}

// MARK: - Reguli

struct RentzRulesView: View {
    @Environment(\.dismiss) private var dismiss
    var scoring = RentzScore.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    rule("person.3.fill", L("r.rules.basics.t"), L("r.rules.basics.x"))
                    rule("hand.tap.fill", L("r.rules.play.t"), L("r.rules.play.x"))
                    ForEach(scoring.games) { g in
                        rule(g.icon, g.name, g.rules(scoring))
                    }
                    rule("trophy.fill", L("r.rules.end.t"), L("r.rules.end.x"))
                    rule("book.closed.fill", L("w.r11.t"), L("r.rules.history"))
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle(L("r.rules.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("w.done")) { dismiss() }.font(Theme.font(17, .bold))
                }
            }
        }
    }

    private func rule(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.violet)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.soft))
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(Theme.font(17, .bold)).foregroundStyle(Theme.ink)
                Text(text).font(Theme.font(15, .regular)).foregroundStyle(Theme.ink.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .panel(padding: 16)
    }
}
