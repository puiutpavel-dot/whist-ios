import SwiftUI

extension Theme {
    /// Culoarea Canastei: turcoaz.
    static let canasta = Color(hex: 0x14B8A6)
    static let canastaGradient = [Color(hex: 0x0F9488), Color(hex: 0x0B4F5C), Color(hex: 0x041C24)]
}

// MARK: - Cartea

struct CanastaCardView: View {
    let card: CanastaCard
    var width: CGFloat = 64
    var dimmed = false
    var glow = false

    var body: some View {
        if card.isJoker {
            joker
        } else {
            CardView(card: card.face, width: width, dimmed: dimmed, glow: glow)
        }
    }

    private var joker: some View {
        let color = card.suit.isRed ? Theme.cardRed : Theme.cardInk
        let shape = RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
        return ZStack {
            shape.fill(Theme.cardFace)
                .shadow(color: .black.opacity(0.45), radius: width * 0.08, y: width * 0.05)
            shape.strokeBorder(glow ? Theme.gold : Theme.cardEdge, lineWidth: glow ? 3 : 0.75)
            VStack(spacing: width * 0.03) {
                Image(systemName: "star.fill").font(.system(size: width * 0.34, weight: .black))
                Text(verbatim: "JOKER").font(.system(size: width * 0.21, weight: .black).width(.compressed))
                Text(verbatim: "50").font(.system(size: width * 0.24, weight: .heavy))
            }
            .foregroundStyle(color)
        }
        .frame(width: width, height: width * 1.42)
        .overlay(shape.fill(Color.black.opacity(dimmed ? 0.5 : 0)))
        .shadow(color: glow ? Theme.gold.opacity(0.6) : .clear, radius: 10)
        .accessibilityLabel("Joker")
    }
}

/// Desenul din meniu: o canastă de șapte cărți.
struct CanastaArt: View {
    var cardWidth: CGFloat = 44
    var body: some View {
        let suits: [Suit] = [.spades, .hearts, .clubs, .diamonds, .spades, .hearts, .clubs]
        HStack(spacing: -cardWidth * 0.62) {
            ForEach(Array(suits.enumerated()), id: \.offset) { i, s in
                CardView(card: Card(suit: s, rank: 13), width: cardWidth)
                    .rotationEffect(.degrees(Double(i - 3) * 4))
                    .offset(y: abs(CGFloat(i - 3)) * cardWidth * 0.05)
            }
        }
    }
}

// MARK: - Meniu

struct CanastaMenuView: View {
    @AppStorage("canasta.players") private var playerCount = 2
    @AppStorage("canasta.target") private var target = 3000
    @AppStorage("canasta.difficulty") private var difficulty = 1
    @AppStorage("speed") private var speed = 1.0
    @AppStorage("canasta.games") private var gamesPlayed = 0
    @AppStorage("canasta.wins") private var gamesWon = 0
    @AppStorage("canasta.best") private var bestScore = 0
    @State private var playing = false
    @State private var showRules = false

    private var settings: CanastaSettings {
        CanastaSettings(players: playerCount, target: target,
                        difficulty: MacaoDifficulty(rawValue: difficulty) ?? .medium, speed: speed)
    }

    private var modeLine: String {
        let cards = CanastaRules.handSize(players: playerCount)
        switch playerCount {
        case 2: return L("k.menu.mode2", cards)
        case 3: return L("k.menu.mode3", cards)
        default: return L("k.menu.mode4", CanastaEngine.botNames[1], cards)
        }
    }

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
                        label(L("w.menu.players"))
                        Pills(options: [2, 3, 4], selection: $playerCount) { "\($0)" }
                        Text(modeLine).font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
                        Divider().overlay(Theme.line)
                        label(L("k.menu.target"))
                        Pills(options: [1500, 3000, 5000], selection: $target) { "\($0)" }
                        Divider().overlay(Theme.line)
                        label(L("c.menu.difficulty"))
                        Pills(options: [0, 1, 2], selection: $difficulty) { MacaoDifficulty(rawValue: $0)?.title ?? "" }
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
                        stat("\(bestScore)", L("k.stat.best"))
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
        }
        .fullScreenCover(isPresented: $playing) {
            CanastaGameView(settings: settings) { won, score in
                gamesPlayed += 1
                if won { gamesWon += 1 }
                bestScore = max(bestScore, score)
            }
        }
        .sheet(isPresented: $showRules) { CanastaRulesView() }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: Theme.canastaGradient, startPoint: .topTrailing, endPoint: .bottomLeading))
            CanastaArt(cardWidth: 58)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 18).padding(.top, 26)
            VStack(alignment: .leading, spacing: 6) {
                GoldTag(text: L("w.menu.new.tag"))
                Text(L("k.title")).font(Theme.display(54)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                Text(L("k.menu.tagline")).font(Theme.font(15, .semibold)).foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: 240, alignment: .leading)
            }
            .padding(20)
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func stat(_ value: String, _ title: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(Theme.display(30)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.6)
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

struct CanastaGameView: View {
    @StateObject private var engine: CanastaEngine
    @Environment(\.dismiss) private var dismiss
    let onFinish: (Bool, Int) -> Void
    @State private var selected: [CanastaCard] = []
    @State private var confirmQuit = false
    @State private var showRules = false
    @State private var reported = false

    init(settings: CanastaSettings, onFinish: @escaping (Bool, Int) -> Void) {
        _engine = StateObject(wrappedValue: CanastaEngine(settings: settings))
        self.onFinish = onFinish
    }

    init(engine: CanastaEngine, selected: [CanastaCard] = []) {
        _engine = StateObject(wrappedValue: engine)
        _selected = State(initialValue: selected)
        _reported = State(initialValue: true)
        onFinish = { _, _ in }
    }

    private var myTurn: Bool { engine.phase == .playing && engine.current == engine.human }
    private var myTeam: Int { engine.team(of: engine.human) }

    var body: some View {
        ZStack {
            Theme.backdrop
            GeometryReader { geo in
                let compact = geo.size.height < 720
                VStack(spacing: compact ? 6 : 10) {
                    topBar
                    HStack(spacing: 8) {
                        ForEach(engine.players.dropFirst()) { p in
                            CanastaOpponentView(player: p, engine: engine)
                        }
                        centerPiles(compact: compact)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(teamOrder, id: \.self) { t in
                                CanastaTeamArea(engine: engine, team: t, mine: t == myTeam,
                                                canAdd: { rank in myTurn && engine.meldRank(for: selected, onto: rank, by: engine.human) != nil },
                                                onTap: { rank in addTo(rank) })
                            }
                        }
                        .padding(10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(TableFelt())
                    statusLine
                    actionPanel.frame(height: 44)
                    CanastaHandView(engine: engine, selected: selected, onTap: tap)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
                .environment(\.compactLayout, compact)
            }
            if engine.phase != .playing {
                Color.black.opacity(0.6).ignoresSafeArea().transition(.opacity)
                CanastaSummaryView(engine: engine,
                                   onNext: { withAnimation(.spring) { engine.nextHand() } },
                                   onExit: { dismiss() })
                    .padding(20)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: engine.phase)
        .sheet(isPresented: $showRules) { CanastaRulesView() }
        .confirmationDialog(L("w.quit.title"), isPresented: $confirmQuit, titleVisibility: .visible) {
            Button(L("w.quit.yes"), role: .destructive) { engine.stop(); dismiss() }
            Button(L("w.quit.no"), role: .cancel) {}
        }
        .onChange(of: engine.current) { _, _ in selected = [] }
        .onChange(of: engine.phase) { _, p in
            selected = []
            guard p == .gameOver, !reported else { return }
            reported = true
            onFinish(engine.winnerTeam == myTeam, engine.scores[myTeam])
        }
        .onDisappear { engine.stop() }
    }

    /// Echipa ta e ultima, lângă mână.
    private var teamOrder: [Int] {
        (0..<engine.teamCount).filter { $0 != myTeam } + [myTeam]
    }

    private var topBar: some View {
        HStack {
            IconButton(system: "xmark") {
                if engine.phase == .gameOver { dismiss() } else { confirmQuit = true }
            }
            Spacer()
            VStack(spacing: 2) {
                Text(L("c.round", engine.round + 1)).font(Theme.display(22)).foregroundStyle(Theme.ink)
                Text(L("k.target", engine.settings.target)).font(Theme.font(12, .medium)).foregroundStyle(Theme.muted)
            }
            Spacer()
            IconButton(system: "book.closed") { showRules = true }
                .accessibilityLabel(L("w.menu.rules"))
        }
        .padding(.top, 4)
    }

    // MARK: Pachetul și teancul

    private func centerPiles(compact: Bool) -> some View {
        let w: CGFloat = compact ? 40 : 46
        let canTake = myTurn && engine.takeOption(for: engine.human) != nil
        return HStack(spacing: 10) {
            Button {
                if myTurn && engine.stage == .draw { engine.humanDraw() }
            } label: {
                VStack(spacing: 3) {
                    CardBackView(width: w, emblem: "C")
                    Text("\(engine.stock.count)").font(Theme.font(11, .bold)).foregroundStyle(Theme.muted)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("k.act.draw"))

            Button {
                if canTake { engine.humanTake() }
            } label: {
                VStack(spacing: 3) {
                    ZStack {
                        if let top = engine.pile.last {
                            CanastaCardView(card: top, width: w, glow: canTake)
                        } else {
                            RoundedRectangle(cornerRadius: w * 0.14, style: .continuous)
                                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                .frame(width: w, height: w * 1.42)
                        }
                    }
                    HStack(spacing: 3) {
                        if engine.pileFrozen {
                            Image(systemName: "snowflake").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.canasta)
                        }
                        Text("\(engine.pile.count)").font(Theme.font(11, .bold)).foregroundStyle(Theme.muted)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("k.act.take", engine.pile.count))
        }
        .padding(.vertical, 8).padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface.opacity(0.75)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
    }

    private var statusLine: some View {
        let p = engine.players[engine.current]
        return VStack(spacing: 2) {
            Text(p.isHuman ? L("w.turn.you") : L("w.turn.playing", p.name))
                .font(Theme.font(15, .bold)).foregroundStyle(Theme.ink).lineLimit(1)
            Text(detailLine).font(Theme.font(12, .semibold)).foregroundStyle(myTurn ? Theme.gold : Theme.muted)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    private var detailLine: String {
        guard myTurn else { return engine.lastEvent ?? "" }
        let missing = engine.missingToOpen(myTeam)
        if missing > 0 { return L("k.minProgress", engine.turnPoints, engine.minimum(myTeam)) }
        if selected.count > 0, selected.allSatisfy(\.isWild) { return L("k.hint.wild") }
        switch CanastaBot.next(for: engine.human, engine: engine, mistakes: false) {
        case .draw: return L("c.tip", L("k.tip.draw"))
        case .takePile: return L("c.tip", L("k.tip.take"))
        case .meld(let cards, _): return L("c.tip", L("k.tip.meld", cards.map(\.label).joined(separator: " ")))
        case .discard(let c): return L("c.tip", L("k.tip.discard", c.label))
        }
    }

    // MARK: Ce poți face

    @ViewBuilder
    private var actionPanel: some View {
        if myTurn && engine.stage == .draw {
            HStack(spacing: 8) {
                pill(L("k.act.draw"), "rectangle.stack.badge.plus", primary: true, enabled: true) { engine.humanDraw() }
                pill(L("k.act.take", engine.pile.count), "square.stack.3d.up.fill", primary: false,
                     enabled: engine.takeOption(for: engine.human) != nil) { engine.humanTake() }
            }
        } else if myTurn {
            let canMeld = engine.meldRank(for: selected, by: engine.human) != nil
            let canDrop = selected.count == 1 && engine.canDiscard(selected[0], by: engine.human)
            HStack(spacing: 8) {
                pill(L("k.act.meld"), "square.grid.3x1.below.line.grid.1x2", primary: canMeld, enabled: canMeld) {
                    let cards = selected
                    selected = []
                    engine.humanMeld(cards)
                }
                pill(L("k.act.discard"), "arrow.up.forward.square", primary: canDrop && !canMeld, enabled: canDrop) {
                    let c = selected[0]
                    selected = []
                    engine.humanDiscard(c)
                }
                if engine.canUndo {
                    pill(L("k.act.undo"), "arrow.uturn.backward", primary: false, enabled: true) {
                        selected = []
                        engine.undo()
                    }
                }
            }
        } else {
            Color.clear
        }
    }

    private func pill(_ title: String, _ icon: String, primary: Bool, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(Theme.font(14, .bold))
                .foregroundStyle(primary ? Theme.onPrimary : Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 12).padding(.vertical, 11)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(primary ? Theme.primary : Theme.raised))
                .overlay(Capsule().strokeBorder(primary ? .clear : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }

    private func tap(_ c: CanastaCard) {
        guard myTurn, engine.stage == .play else {
            if myTurn { Haptics.warning() }
            return
        }
        if let i = selected.firstIndex(of: c) { selected.remove(at: i) } else { selected.append(c) }
        Haptics.tap()
    }

    /// Atingi o etalare de-a ta: cărțile alese se adaugă la ea.
    private func addTo(_ rank: Int) {
        guard myTurn, engine.meldRank(for: selected, onto: rank, by: engine.human) != nil else { return }
        let cards = selected
        selected = []
        engine.humanMeld(cards, onto: rank)
    }
}

struct CanastaOpponentView: View {
    let player: CanastaPlayer
    @ObservedObject var engine: CanastaEngine

    var body: some View {
        let isTurn = engine.current == player.id && engine.phase == .playing
        let count = player.hand.count
        let partner = engine.n == 4 && engine.team(of: player.id) == engine.team(of: engine.human)
        VStack(spacing: 4) {
            AvatarView(name: player.name, index: player.id, size: 28)
                .overlay(Circle().strokeBorder(Theme.gold, lineWidth: isTurn ? 3 : 0).padding(-3))
            Text(verbatim: player.name).font(Theme.font(12, .bold)).foregroundStyle(Theme.ink).lineLimit(1)
            Text(count == 1 ? L("w.cards.one") : L("w.cards.n", count))
                .font(Theme.font(10, .semibold)).foregroundStyle(count <= 2 ? Theme.gold : Theme.muted).lineLimit(1)
            if partner {
                Text(L("k.partner").uppercased()).font(.system(size: 8, weight: .heavy)).foregroundStyle(Theme.canasta)
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isTurn ? Theme.raised.opacity(0.9) : Theme.surface.opacity(0.75)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(isTurn ? Theme.gold : Theme.line, lineWidth: isTurn ? 1.5 : 1))
    }
}

// MARK: - Etalările unei echipe

struct CanastaTeamArea: View {
    @ObservedObject var engine: CanastaEngine
    let team: Int
    let mine: Bool
    let canAdd: (Int) -> Bool
    let onTap: (Int) -> Void

    private var name: String {
        if engine.n == 4 { return L(mine ? "k.team.us" : "k.team.them") }
        return engine.players[team].name
    }

    var body: some View {
        let melds = engine.melds[team]
        let reds = engine.redThrees[team]
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(name.uppercased()).font(.system(size: 11, weight: .heavy)).kerning(0.5)
                    .foregroundStyle(mine ? Theme.gold : Theme.muted)
                Text("\(engine.scores[team])").font(Theme.font(13, .heavy)).foregroundStyle(Theme.ink)
                if !reds.isEmpty {
                    HStack(spacing: 2) {
                        Text(verbatim: "3♥").font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.cardRed)
                        Text(verbatim: "×\(reds.count)").font(Theme.font(12, .bold)).foregroundStyle(Theme.ink)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.cardFace.opacity(0.92)))
                }
                Spacer(minLength: 0)
                if !engine.opened[team] {
                    Text(L("k.min", engine.minimum(team))).font(Theme.font(11, .semibold)).foregroundStyle(Theme.muted)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            if melds.isEmpty {
                Text(L("k.noMelds")).font(Theme.font(12, .medium)).foregroundStyle(Theme.muted.opacity(0.7))
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], alignment: .leading, spacing: 10) {
                    ForEach(melds) { m in
                        CanastaMeldView(meld: m, highlight: mine && canAdd(m.rank))
                            .onTapGesture { if mine { onTap(m.rank) } }
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(mine ? 0.28 : 0.16)))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: melds)
    }
}

struct CanastaMeldView: View {
    let meld: CanastaMeld
    var highlight = false

    var body: some View {
        let w: CGFloat = 40
        let top = meld.cards.first { !$0.isWild } ?? meld.cards[0]
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                if meld.cards.count > 3 {
                    RoundedRectangle(cornerRadius: w * 0.14, style: .continuous).fill(Theme.cardFace.opacity(0.6))
                        .frame(width: w, height: w * 1.42).offset(x: 3, y: -3)
                }
                CanastaCardView(card: top, width: w, glow: highlight)
                    .overlay(RoundedRectangle(cornerRadius: w * 0.14, style: .continuous)
                        .strokeBorder(meld.isCanasta ? (meld.isNatural ? Theme.accent : Theme.cardInk) : .clear, lineWidth: 3))
                if meld.wilds > 0 {
                    HStack(spacing: 1) {
                        Image(systemName: "star.fill").font(.system(size: 7, weight: .black))
                        Text("\(meld.wilds)").font(.system(size: 9, weight: .black))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 3).padding(.vertical, 1)
                    .background(Capsule().fill(Theme.gold))
                    .offset(x: 5, y: -5)
                }
            }
            Text(verbatim: meld.isCanasta ? "C·\(meld.cards.count)" : "×\(meld.cards.count)")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(meld.isCanasta ? Theme.gold : Theme.ink.opacity(0.85))
        }
        .accessibilityLabel("\(top.face.rankLabel) ×\(meld.cards.count)")
    }
}

// MARK: - Mâna

struct CanastaHandView: View {
    @ObservedObject var engine: CanastaEngine
    let selected: [CanastaCard]
    let onTap: (CanastaCard) -> Void
    @Environment(\.compactLayout) private var compact
    private var cardW: CGFloat { compact ? 54 : 62 }

    var body: some View {
        GeometryReader { geo in
            let hand = engine.players[engine.human].hand
            let count = max(hand.count, 1)
            let room = geo.size.width - 8
            let fit = (room - CGFloat(count) * cardW) / CGFloat(max(count - 1, 1))
            let spacing = min(6, max(fit, 24 - cardW))
            let width = CGFloat(count) * cardW + CGFloat(count - 1) * spacing
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(hand) { card in
                        let on = selected.contains(card)
                        CanastaCardView(card: card, width: cardW, glow: on)
                            .offset(y: on ? -16 : 0)
                            .onTapGesture { onTap(card) }
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                                    removal: .scale(scale: 0.5).combined(with: .opacity)))
                    }
                }
                .padding(.horizontal, 4)
                .frame(minWidth: geo.size.width, minHeight: geo.size.height, alignment: .bottom)
            }
            .scrollDisabled(width <= room)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selected)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hand)
        }
        .frame(height: cardW * 1.42 + 22)
    }
}

// MARK: - Rezumat

struct CanastaSummaryView: View {
    @ObservedObject var engine: CanastaEngine
    let onNext: () -> Void
    let onExit: () -> Void

    private func name(_ t: Int) -> String {
        if engine.n == 4 { return L(t == engine.team(of: engine.human) ? "k.team.us" : "k.team.them") }
        return engine.players[t].name
    }

    var body: some View {
        let over = engine.phase == .gameOver
        let rec = engine.history.last
        let mine = engine.team(of: engine.human)
        VStack(spacing: 14) {
            if over {
                let won = engine.winnerTeam == mine
                Image(systemName: won ? "trophy.fill" : "flag.checkered")
                    .font(.system(size: 38, weight: .bold)).foregroundStyle(won ? Theme.gold : Theme.primary)
                Text(won ? L("w.won") : L("w.gameOver")).font(Theme.display(36)).foregroundStyle(Theme.ink)
            } else if let rec {
                Text(rec.out.map { L("k.sum.out.title", engine.players[$0].name) } ?? L("k.sum.stock.title"))
                    .font(Theme.display(28)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            }
            if let rec {
                VStack(spacing: 0) {
                    row("", (0..<engine.teamCount).map(name), header: true)
                    row(L("k.sum.melds"), rec.teams.map { "\($0.meldPoints)" })
                    row(L("k.sum.canastas"), rec.teams.map { "\($0.canastaBonus)" })
                    row(L("k.sum.red"), rec.teams.map { "\($0.redThrees)" })
                    row(L("k.sum.out"), rec.teams.map { "\($0.outBonus)" })
                    row(L("k.sum.hand"), rec.teams.map { $0.handPenalty == 0 ? "0" : "−\($0.handPenalty)" })
                    Divider().overlay(Theme.line).padding(.vertical, 4)
                    row(L("k.sum.round"), rec.teams.map { "\($0.total)" }, strong: true)
                    row(L("k.sum.total"), engine.scores.map { "\($0)" }, strong: true, gold: true)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.bg))
            }
            if over { Button(L("w.backToMenu"), action: onExit).buttonStyle(PrimaryButtonStyle()) }
            else { Button(L("c.nextRound"), action: onNext).buttonStyle(PrimaryButtonStyle()) }
        }
        .panel(padding: 20)
        .frame(maxWidth: 460)
    }

    private func row(_ title: String, _ values: [String], header: Bool = false, strong: Bool = false, gold: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(title).font(Theme.font(13, strong ? .bold : .medium)).foregroundStyle(strong ? Theme.ink : Theme.muted)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                Text(verbatim: v)
                    .font(Theme.font(header ? 12 : 14, header || strong ? .heavy : .semibold))
                    .foregroundStyle(gold ? Theme.gold : (header ? Theme.muted : Theme.ink))
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(width: 62, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Reguli

struct CanastaRulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    rule("flag.checkered", L("k.r.goal.t"), L("k.r.goal.x"))
                    rule("rectangle.on.rectangle", L("k.r.cards.t"), L("k.r.cards.x"))
                    rule("arrow.triangle.2.circlepath", L("k.r.turn.t"), L("k.r.turn.x"))
                    rule("square.grid.3x1.below.line.grid.1x2", L("k.r.melds.t"), L("k.r.melds.x"))
                    rule("star.fill", L("k.r.wild.t"), L("k.r.wild.x"))
                    rule("crown.fill", L("k.r.canasta.t"), L("k.r.canasta.x"))
                    rule("heart.fill", L("k.r.threes.t"), L("k.r.threes.x"))
                    rule("square.stack.3d.up.fill", L("k.r.pile.t"), L("k.r.pile.x"))
                    rule("lock.open.fill", L("k.r.open.t"), L("k.r.open.x"))
                    rule("checkmark.seal.fill", L("k.r.out.t"), L("k.r.out.x"))
                    rule("sum", L("k.r.score.t"), L("k.r.score.x"))
                    Text(L("k.r.note")).font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center).padding(.horizontal, 8).padding(.top, 4)
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle(L("k.r.title"))
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
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.canasta)
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
