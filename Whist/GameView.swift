import SwiftUI

struct GameResult {
    let won: Bool
    let score: Int
    let contractsMade: Int
    let contractsTotal: Int
}

struct GameView: View {
    @StateObject private var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let onFinish: (GameResult) -> Void

    @State private var showScores = false
    @State private var showTracker = false
    @State private var confirmQuit = false
    @State private var reported = false

    init(settings: GameSettings, onFinish: @escaping (GameResult) -> Void) {
        _engine = StateObject(wrappedValue: GameEngine(settings: settings))
        self.onFinish = onFinish
    }

    /// Folosit de modul de capturi: pornește dintr-un joc deja pregătit.
    init(engine: GameEngine, showScores: Bool = false, showTracker: Bool = false) {
        _engine = StateObject(wrappedValue: engine)
        _showScores = State(initialValue: showScores)
        _showTracker = State(initialValue: showTracker)
        _reported = State(initialValue: true)
        self.onFinish = { _ in }
    }

    var body: some View {
        ZStack {
            Theme.backdrop

            GeometryReader { geo in
                let compact = geo.size.height < 720
                VStack(spacing: compact ? 7 : 12) {
                    topBar
                    opponents
                    infoRow
                    centerArea
                    Spacer(minLength: 0)
                    myStatus
                    HandView(engine: engine)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
                .environment(\.compactLayout, compact)
            }

            if engine.phase == .handEnd || engine.phase == .gameOver {
                Color.black.opacity(0.6).ignoresSafeArea()
                    .transition(.opacity)
                HandSummaryView(engine: engine,
                                onNext: { withAnimation(.spring) { engine.nextHand() } },
                                onScores: { showScores = true },
                                onExit: { dismiss() })
                    .padding(20)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: engine.phase)
        .sheet(isPresented: $showScores) { ScoreboardView(engine: engine) }
        .sheet(isPresented: $showTracker) {
            TrackerView(engine: engine)
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Abandonezi jocul?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Abandonează", role: .destructive) { engine.stop(); dismiss() }
            Button("Continuă jocul", role: .cancel) {}
        }
        .onChange(of: engine.phase) { _, newPhase in
            guard newPhase == .gameOver, !reported else { return }
            reported = true
            let best = engine.players.map(\.score).max() ?? 0
            let mine = engine.players[engine.human].score
            let c = engine.humanContractStats
            onFinish(GameResult(won: mine == best, score: mine, contractsMade: c.made, contractsTotal: c.total))
        }
        .onDisappear { engine.stop() }
    }

    // MARK: Top

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                IconButton(system: "xmark") {
                    if engine.phase == .gameOver { dismiss() } else { confirmQuit = true }
                }
                Color.clear.frame(width: 42, height: 42)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("MÂNA \(engine.handIndex + 1) / \(engine.handSizes.count)")
                    .font(Theme.display(24)).foregroundStyle(Theme.ink)
                Text(engine.handSize == 1 ? "1 carte" : "\(engine.handSize) cărți")
                    .font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
            }
            Spacer()
            HStack(spacing: 8) {
                IconButton(system: "rectangle.stack") { showTracker = true }
                    .accessibilityLabel("Cărți ieșite")
                IconButton(system: "list.number") { showScores = true }
            }
        }
        .padding(.top, 4)
    }

    private var opponents: some View {
        HStack(spacing: 6) {
            ForEach(engine.players.dropFirst()) { p in
                OpponentChip(player: p,
                             visibleCard: engine.isForeheadHand ? p.hand.first : nil,
                             isDealer: p.id == engine.dealer,
                             isTurn: p.id == engine.current && (engine.phase == .bidding || engine.phase == .playing))
            }
        }
    }

    private var infoRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                if let t = engine.trump {
                    CardView(card: t, width: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Atu").font(Theme.font(12, .medium)).foregroundStyle(Theme.muted)
                        Text(t.suit.name).font(Theme.font(15, .bold)).foregroundStyle(t.suit.isRed ? Theme.red : Theme.ink)
                    }
                } else {
                    Image(systemName: "nosign").font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.muted)
                    Text("Fără atu").font(Theme.font(15, .bold)).foregroundStyle(Theme.ink)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))

            Spacer()

            let sum = engine.bidSum
            let size = engine.handSize
            VStack(alignment: .trailing, spacing: 0) {
                Text("Licitat").font(Theme.font(12, .medium)).foregroundStyle(Theme.muted)
                HStack(spacing: 4) {
                    Text("\(sum) / \(size)").font(Theme.font(15, .bold)).foregroundStyle(Theme.ink)
                    if engine.phase != .bidding {
                        Text(sum > size ? "peste" : "sub")
                            .font(Theme.font(11, .bold))
                            .foregroundStyle(sum > size ? Color.white : Theme.onPrimary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(sum > size ? Theme.accent : Theme.primary))
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
        }
    }

    // MARK: Center

    @ViewBuilder
    private var centerArea: some View {
        if engine.phase == .bidding && engine.current == engine.human {
            BidPanel(engine: engine)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            TrickTable(engine: engine)
        }
    }

    private var myStatus: some View {
        let me = engine.players[engine.human]
        return HStack(spacing: 10) {
            AvatarView(name: "Tu", index: 0, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Tu").font(Theme.font(16, .bold)).foregroundStyle(Theme.ink)
                    if engine.dealer == engine.human { DealerBadge() }
                }
                Text(statusLine(me)).font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
            }
            Spacer()
            if engine.settings.streakBonus && me.streak != 0 {
                Label("\(abs(me.streak))", systemImage: me.streak > 0 ? "flame.fill" : "snowflake")
                    .font(Theme.font(13, .bold))
                    .foregroundStyle(me.streak > 0 ? Theme.gold : Theme.primary)
            }
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(me.score)").font(Theme.font(22, .heavy)).foregroundStyle(Theme.primary)
                Text("puncte").font(Theme.font(11, .medium)).foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 4)
    }

    private func statusLine(_ me: Player) -> String {
        guard let b = me.bid else { return engine.current == engine.human ? "Alege câte levate iei" : "Aștepți licitația…" }
        return "Licitat \(b) · Luate \(me.tricks)"
    }
}

// MARK: - Opponent chip

struct DealerBadge: View {
    var body: some View {
        Text("D")
            .font(Theme.font(10, .heavy))
            .foregroundStyle(Color.black)
            .frame(width: 16, height: 16)
            .background(Circle().fill(Theme.gold))
            .accessibilityLabel("Împarte")
    }
}

struct OpponentChip: View {
    let player: Player
    var visibleCard: Card? = nil
    let isDealer: Bool
    let isTurn: Bool
    @Environment(\.compactLayout) private var compact

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                if let c = visibleCard {
                    // cartea „de pe fruntea” adversarului
                    CardView(card: c, width: 30)
                        .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Theme.gold, lineWidth: isTurn ? 2.5 : 0).padding(-3))
                        .frame(height: 46)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    AvatarView(name: player.name, index: player.id, size: 38)
                    .overlay(Circle().strokeBorder(Theme.gold, lineWidth: isTurn ? 3 : 0).padding(-4))
                    .scaleEffect(isTurn ? 1.06 : 1)
                    .animation(.spring(response: 0.3), value: isTurn)
                }
                if isDealer { DealerBadge().offset(x: 6, y: -4) }
            }
            .padding(.top, 4)
            Text(verbatim: player.name)
                .font(Theme.font(13, .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(verbatim: bidText)
                .font(Theme.font(13, .bold))
                .foregroundStyle(bidColor)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Capsule().fill(Theme.soft))
            HStack(spacing: 3) {
                if !compact {
                    CardBackView(width: 10)
                    Text("\(player.hand.count) ·").font(Theme.font(11, .semibold)).foregroundStyle(Theme.muted)
                }
                Text("\(player.score) p").font(Theme.font(11, .semibold)).foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 5 : 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isTurn ? Theme.raised : Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isTurn ? Theme.gold : Theme.line, lineWidth: isTurn ? 1.5 : 1)
        )
    }

    private var bidText: String {
        guard let b = player.bid else { return "–" }
        return "\(player.tricks) / \(b)"
    }

    private var bidColor: Color {
        guard let b = player.bid else { return Theme.muted }
        if player.tricks > b { return Theme.red }
        if player.tricks == b { return Theme.green }
        return Theme.primary
    }
}

// MARK: - Trick table

struct TrickTable: View {
    @ObservedObject var engine: GameEngine
    @Environment(\.compactLayout) private var compact

    var body: some View {
        GeometryReader { geo in
            let n = CGFloat(engine.n)
            let cardW = max(10, min(64, (geo.size.width - 24 - (n - 1) * 6) / n))
            ZStack {
                if engine.trick.isEmpty {
                    VStack(spacing: 6) {
                        Text(headline).font(Theme.font(18, .bold)).foregroundStyle(Theme.ink)
                        Text(subline).font(Theme.font(14, .medium)).foregroundStyle(Theme.muted)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .transition(.opacity)
                } else {
                    HStack(spacing: 6) {
                        ForEach(engine.trick) { pc in
                            VStack(spacing: 6) {
                                CardView(card: pc.card, width: cardW, glow: pc.player == engine.trickWinner)
                                    .scaleEffect(pc.player == engine.trickWinner ? 1.06 : 1)
                                Text(engine.players[pc.player].name)
                                    .font(Theme.font(12, .semibold))
                                    .foregroundStyle(pc.player == engine.trickWinner ? Theme.ink : Theme.muted)
                                    .lineLimit(1)
                            }
                            .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity),
                                                    removal: .opacity))
                        }
                    }
                }

                if let w = engine.trickWinner {
                    VStack {
                        Spacer()
                        Text(w == engine.human ? "Iei levata!" : "\(engine.players[w].name) ia levata")
                            .font(Theme.font(14, .bold))
                            .foregroundStyle(w == engine.human ? Theme.onPrimary : .white)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Capsule().fill(w == engine.human ? Theme.primary : Theme.accent))
                    }
                    .padding(.bottom, 10)
                    .transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: compact ? 150 : 190)
        .background(TableFelt())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: engine.trick.count)
        .animation(.easeInOut(duration: 0.2), value: engine.trickWinner)
    }

    private var headline: String {
        let p = engine.players[engine.current]
        switch engine.phase {
        case .bidding: return p.isHuman ? "Rândul tău" : "Licitează \(p.name)…"
        case .playing: return p.isHuman ? (engine.trick.isEmpty ? "Tu deschizi" : "Rândul tău") : "Joacă \(p.name)…"
        default: return ""
        }
    }

    private var subline: String {
        switch engine.phase {
        case .bidding: return "Fiecare spune câte levate crede că ia"
        case .playing:
            let me = engine.players[engine.human]
            guard let b = me.bid else { return "" }
            let left = b - me.tricks
            if left > 0 { return "Mai ai nevoie de \(left) \(left == 1 ? "levată" : "levate")" }
            if left == 0 { return "Ai exact cât ai licitat — evită levatele" }
            return "Ai depășit licitația cu \(-left)"
        default: return ""
        }
    }
}

// MARK: - Bid panel

struct BidPanel: View {
    @ObservedObject var engine: GameEngine
    @Environment(\.compactLayout) private var compact

    var body: some View {
        let allowed = Set(engine.allowedBids(for: engine.human))
        let forbidden = engine.forbiddenBid(for: engine.human)
        let tip = engine.settings.coach ? engine.coachBid() : nil   // nil când nu mai e licitația ta
        VStack(spacing: compact ? 8 : 12) {
            Text("CÂTE LEVATE IEI?").font(Theme.display(26)).foregroundStyle(Theme.ink)
            if engine.isForeheadHand {
                Label("Cartea e pe frunte: o vezi doar pe a celorlalți", systemImage: "eye.slash.fill")
                    .font(Theme.font(13, .semibold)).foregroundStyle(Theme.primary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: min(engine.handSize + 1, 5)), spacing: 8) {
                ForEach(0...engine.handSize, id: \.self) { b in
                    let ok = allowed.contains(b)
                    Button {
                        Haptics.tap()
                        withAnimation(.spring) { engine.humanBid(b) }
                    } label: {
                        Text("\(b)")
                            .font(Theme.font(22, .bold))
                            .foregroundStyle(ok ? Theme.onPrimary : Theme.muted)
                            .strikethrough(!ok, color: Theme.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: compact ? 40 : 50)
                            .background(Capsule().fill(ok ? Theme.primary : Theme.soft))
                            .overlay(Capsule().strokeBorder(Theme.gold, lineWidth: tip?.bid == b ? 3 : 0))
                    }
                    .buttonStyle(.plain)
                    .disabled(!ok)
                }
            }
            if let tip {
                CoachTip(title: "SFAT: SPUNE \(tip.bid)", text: tip.reason)
            }
            if let f = forbidden {
                Text("Împarți tu: nu poți spune \(f), suma licitațiilor ar fi egală cu numărul de cărți.")
                    .font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            } else {
                Text("Suma licitată până acum: \(engine.bidSum) din \(engine.handSize)")
                    .font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: compact ? 150 : 190)
        .panel(padding: compact ? 12 : 16)
    }
}

// MARK: - Hand

struct HandView: View {
    @ObservedObject var engine: GameEngine
    @Environment(\.compactLayout) private var compact
    private var maxCardW: CGFloat { compact ? 60 : 74 }

    var body: some View {
        GeometryReader { geo in
            let hand = engine.players[engine.human].hand
            let count = max(hand.count, 1)
            let cardW: CGFloat = min(maxCardW, geo.size.width / 4.6)
            let natural = CGFloat(count) * cardW + CGFloat(count - 1) * 6
            let spacing = natural > geo.size.width
                ? (geo.size.width - CGFloat(count) * cardW) / CGFloat(max(count - 1, 1))
                : 6
            let myTurn = engine.phase == .playing && engine.current == engine.human
            let legal = Set(engine.legalCards(for: engine.human))
            let suggested = engine.settings.coach && !engine.isForeheadHand ? engine.coachCard() : nil

            HStack(spacing: spacing) {
                ForEach(hand) { card in
                    let canPlay = myTurn && legal.contains(card)
                    Group {
                        if engine.isForeheadHand {
                            CardBackView(width: cardW, emblem: "?")
                        } else {
                            CardView(card: card, width: cardW, dimmed: myTurn && !canPlay)
                        }
                    }
                        .overlay(alignment: .top) {
                            if suggested == card {
                                GoldTag(text: "Sfat").offset(y: -9)
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

// MARK: - Summary

struct HandSummaryView: View {
    @ObservedObject var engine: GameEngine
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
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(won ? Theme.gold : Theme.primary)
                Text(won ? "AI CÂȘTIGAT!" : "JOC ÎNCHEIAT")
                    .font(Theme.display(40)).foregroundStyle(Theme.ink)
            } else if let rec {
                let me = rec.entries[engine.human]
                Text(me.made ? "CONTRACT REUȘIT!" : "CONTRACT RATAT")
                    .font(Theme.display(34))
                    .foregroundStyle(me.made ? Theme.green : Theme.red)
                Text("Mâna \(rec.id + 1) · \(rec.size) \(rec.size == 1 ? "carte" : "cărți")")
                    .font(Theme.font(14, .medium)).foregroundStyle(Theme.muted)
            }

            VStack(spacing: 8) {
                let order = over
                    ? engine.players.sorted { $0.score > $1.score }.map(\.id)
                    : engine.players.map(\.id)
                ForEach(Array(order.enumerated()), id: \.element) { pos, i in
                    row(pos: pos, i: i, over: over, entry: rec?.entries[i])
                }
            }

            VStack(spacing: 10) {
                if over {
                    Button("Înapoi la meniu", action: onExit).buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Mâna următoare", action: onNext).buttonStyle(PrimaryButtonStyle())
                }
                Button("Tabela de scor", action: onScores).buttonStyle(SecondaryButtonStyle())
            }
        }
        .panel(padding: 22)
        .frame(maxWidth: 440)
    }

    private func row(pos: Int, i: Int, over: Bool, entry: HandRecord.Entry?) -> some View {
        let p = engine.players[i]
        return HStack(spacing: 10) {
            if over {
                Text("\(pos + 1)").font(Theme.font(15, .bold)).foregroundStyle(Theme.muted).frame(width: 18)
            }
            AvatarView(name: p.name, index: p.id, size: 30)
            Text(p.name).font(Theme.font(16, .semibold)).foregroundStyle(Theme.ink)
            Spacer()
            if !over, let e = entry {
                Text("\(e.tricks)/\(e.bid)").font(Theme.font(14, .medium)).foregroundStyle(Theme.muted)
                Text(e.delta >= 0 ? "+\(e.delta)" : "\(e.delta)")
                    .font(Theme.font(15, .bold))
                    .foregroundStyle(e.made ? Theme.green : Theme.red)
                    .frame(minWidth: 34, alignment: .trailing)
                if e.bonus != 0 {
                    Text(e.bonus > 0 ? "+\(e.bonus)" : "\(e.bonus)")
                        .font(Theme.font(12, .heavy))
                        .foregroundStyle(e.bonus > 0 ? Color.black : .white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(e.bonus > 0 ? Theme.gold : Theme.accent))
                }
            }
            Text("\(p.score)")
                .font(Theme.font(17, .heavy)).foregroundStyle(Theme.primary)
                .frame(minWidth: 40, alignment: .trailing)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.isHuman ? Theme.soft : Theme.bg))
    }
}

/// Masa de joc: postav închis, cu o lumină roșie discretă și un chenar subțire.
struct TableFelt: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(RadialGradient(colors: [Color(hex: 0x2A0E14), Theme.surface],
                                 center: .center, startRadius: 10, endRadius: 260))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Theme.accent.opacity(0.8), Theme.accent.opacity(0.15)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 1.5))
            .shadow(color: Theme.accent.opacity(0.18), radius: 18, y: 6)
    }
}

/// Bulă de sfat a antrenorului.
struct CoachTip: View {
    let title: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.gold)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.gold)
                Text(text).font(Theme.font(12, .medium)).foregroundStyle(Theme.ink.opacity(0.85))
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.gold.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1))
    }
}

/// „Cărți ieșite”: pentru fiecare culoare, ce s-a jucat, ce ai tu și ce mai e la ceilalți.
struct TrackerView: View {
    @ObservedObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let low = Deck.lowestRank(players: engine.n)
        let played = Set(engine.playedThisHand.map(\.card))
        let mine = engine.isForeheadHand ? [] : Set(engine.players[engine.human].hand)
        let order: [Suit] = engine.trumpSuit.map { t in [t] + Suit.allCases.filter { $0 != t } } ?? Suit.allCases
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 14) {
                        legend(color: Theme.cardFace, text: "în joc")
                        legend(color: Theme.primary, text: "la tine")
                        legend(color: Theme.soft, text: "ieșite")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(order, id: \.self) { suit in
                        let ranks = Array((low...14).reversed())
                        let out = ranks.filter { r in
                            let c = Card(suit: suit, rank: r)
                            return !played.contains(c) && !mine.contains(c) && c != engine.trump
                        }.count
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(suit.symbol).font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(suit.isRed ? Theme.red : Theme.ink)
                                Text(suit.name.uppercased()).font(Theme.display(20)).foregroundStyle(Theme.ink)
                                if suit == engine.trumpSuit { GoldTag(text: "Atu") }
                                Spacer()
                                Text("\(out) la ceilalți").font(Theme.font(12, .semibold)).foregroundStyle(Theme.muted)
                            }
                            HStack(spacing: 4) {
                                ForEach(ranks, id: \.self) { r in
                                    let c = Card(suit: suit, rank: r)
                                    let isMine = mine.contains(c)
                                    let gone = played.contains(c) || c == engine.trump
                                    Text(c.rankLabel)
                                        .font(.system(size: 13, weight: .heavy).width(.condensed))
                                        .foregroundStyle(isMine ? Theme.onPrimary : gone ? Theme.muted : Theme.cardInk)
                                        .strikethrough(gone && !isMine, color: Theme.muted)
                                        .frame(maxWidth: .infinity, minHeight: 30)
                                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .fill(isMine ? Theme.primary : gone ? Theme.soft : Theme.cardFace))
                                }
                            }
                        }
                        .panel(padding: 12)
                    }
                    if engine.trump != nil {
                        Text("Cartea de atu întoarsă se socotește ieșită.")
                            .font(Theme.font(12, .medium)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("Cărți ieșite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gata") { dismiss() }.font(Theme.font(17, .bold))
                }
            }
        }
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 14, height: 14)
            Text(text).font(Theme.font(12, .semibold)).foregroundStyle(Theme.muted)
        }
    }
}
