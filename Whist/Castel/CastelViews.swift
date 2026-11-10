import SwiftUI

extension Theme {
    /// Culoarea Castelului: piatră arămie.
    static let amber = Color(hex: 0xD97706)
    static let castleGradient = [Color(hex: 0xD97706), Color(hex: 0x7C2D12), Color(hex: 0x2A1006)]
}

// MARK: - Meniu

struct CastelMenuView: View {
    @AppStorage("castel.players") private var playerCount = 3
    @AppStorage("castel.difficulty") private var difficulty = 1
    @AppStorage("speed") private var speed = 1.0
    @AppStorage("castel.games") private var gamesPlayed = 0
    @AppStorage("castel.wins") private var gamesWon = 0
    @AppStorage("castel.best") private var bestScore = 0
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
                        label(L("w.menu.players"))
                        Pills(options: [2, 3, 4], selection: $playerCount) { "\($0)" }
                        Text(L("c.menu.playersLine", playerCount - 1, CastelRules.targetScore))
                            .font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
                        Divider().overlay(Theme.line)
                        label(L("c.menu.difficulty"))
                        Pills(options: [0, 1, 2], selection: $difficulty) { CastelDifficulty(rawValue: $0)?.title ?? "" }
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
            CastelGameView(players: playerCount, difficulty: CastelDifficulty(rawValue: difficulty) ?? .medium,
                           speed: speed) { won, score in
                gamesPlayed += 1
                if won { gamesWon += 1 }
                bestScore = max(bestScore, score)
            }
        }
        .sheet(isPresented: $showRules) { CastelRulesView() }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: Theme.castleGradient, startPoint: .topTrailing, endPoint: .bottomLeading))
            CastleTowerArt(levels: 6, cardWidth: 46)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 24).padding(.top, 18)
            VStack(alignment: .leading, spacing: 6) {
                GoldTag(text: L("c.menu.tag"))
                Text(L("c.title")).font(Theme.display(58)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                Text(L("c.menu.tagline")).font(Theme.font(15, .semibold)).foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: 220, alignment: .leading)
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

/// Un turn de cărți (desen pentru meniu): As, 2, 3… de jos în sus.
struct CastleTowerArt: View {
    let levels: Int
    var cardWidth: CGFloat = 40
    var body: some View {
        let suits: [Suit] = [.spades, .hearts, .clubs, .diamonds]
        VStack(spacing: -cardWidth * 1.15) {
            ForEach((0..<levels).reversed(), id: \.self) { i in
                CardView(card: Card(suit: suits[i % 4], rank: i == 0 ? 14 : i + 1), width: cardWidth)
                    .rotationEffect(.degrees(i.isMultiple(of: 2) ? -3 : 3))
            }
        }
    }
}

// MARK: - Masa

struct CastelGameView: View {
    @StateObject private var engine: CastelEngine
    @Environment(\.dismiss) private var dismiss
    let onFinish: (Bool, Int) -> Void
    @State private var selected: Card? = nil
    @State private var confirmQuit = false
    @State private var showRules = false
    @State private var reported = false

    init(players: Int, difficulty: CastelDifficulty, speed: Double, onFinish: @escaping (Bool, Int) -> Void) {
        _engine = StateObject(wrappedValue: CastelEngine(players: players, difficulty: difficulty, speed: speed))
        self.onFinish = onFinish
    }

    init(engine: CastelEngine, selected: Card? = nil) {
        _engine = StateObject(wrappedValue: engine)
        _selected = State(initialValue: selected)
        _reported = State(initialValue: true)
        onFinish = { _, _ in }
    }

    private var myTurn: Bool { engine.phase == .playing && engine.current == engine.human }

    var body: some View {
        ZStack {
            Theme.backdrop
            GeometryReader { geo in
                let compact = geo.size.height < 720
                VStack(spacing: compact ? 8 : 12) {
                    topBar
                    opponents
                    tableCenter
                    Spacer(minLength: 0)
                    myCastle
                    actionPanel
                    CastelHandView(engine: engine, selected: $selected)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
                .environment(\.compactLayout, compact)
            }
            if engine.phase != .playing {
                Color.black.opacity(0.6).ignoresSafeArea().transition(.opacity)
                CastelSummaryView(engine: engine,
                                  onNext: { withAnimation(.spring) { engine.nextRound() } },
                                  onExit: { dismiss() })
                    .padding(20)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: engine.phase)
        .sheet(isPresented: $showRules) { CastelRulesView() }
        .confirmationDialog(L("w.quit.title"), isPresented: $confirmQuit, titleVisibility: .visible) {
            Button(L("w.quit.yes"), role: .destructive) { engine.stop(); dismiss() }
            Button(L("w.quit.no"), role: .cancel) {}
        }
        .onChange(of: engine.current) { _, _ in selected = nil }
        .onChange(of: engine.phase) { _, p in
            selected = nil
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
                Text(L("c.round", engine.round + 1)).font(Theme.display(24)).foregroundStyle(Theme.ink)
                Text(L("c.target", CastelRules.targetScore)).font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
            }
            Spacer()
            IconButton(system: "book.closed") { showRules = true }
                .accessibilityLabel(L("w.menu.rules"))
        }
        .padding(.top, 4)
    }

    private var opponents: some View {
        HStack(spacing: 6) {
            ForEach(engine.players.dropFirst()) { p in
                let targetable = selected.map { CastelRules.isBall($0) && engine.canAttack(p.id, with: $0) } ?? false
                CastelOpponentView(player: p, engine: engine, targetable: myTurn && targetable)
                    .onTapGesture {
                        guard myTurn, targetable, let c = selected else { return }
                        engine.humanAct(.attack(c, target: p.id))
                        selected = nil
                    }
            }
        }
    }

    private var tableCenter: some View {
        HStack(spacing: 14) {
            VStack(spacing: 4) {
                ZStack {
                    if engine.deck.isEmpty {
                        RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                            .frame(width: 46, height: 65)
                    } else {
                        CardBackView(width: 46, emblem: "♜")
                    }
                }
                Text("\(engine.deck.count)").font(Theme.font(12, .bold)).foregroundStyle(Theme.muted)
            }
            VStack(spacing: 4) {
                if let top = engine.topDiscard {
                    CardView(card: top, width: 46).transition(.scale.combined(with: .opacity))
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(Theme.soft).frame(width: 46, height: 65)
                }
                Text(L("c.discard")).font(Theme.font(11, .semibold)).foregroundStyle(Theme.muted)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(turnLine).font(Theme.font(16, .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                Text(engine.lastEvent ?? L("c.hint")).font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(TableFelt())
        .animation(.spring(response: 0.3), value: engine.discardPile.count)
    }

    private var turnLine: String {
        let p = engine.players[engine.current]
        return p.isHuman ? L("w.turn.you") : L("w.turn.playing", p.name)
    }

    private var myCastle: some View {
        let me = engine.players[engine.human]
        return HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(me.name).font(Theme.font(16, .bold)).foregroundStyle(Theme.ink)
                    if me.shielded {
                        Image(systemName: "shield.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.gold)
                    }
                }
                Text(L("c.levels", me.castle.count, CastelRules.levels)).font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
                Text(L("w.pts.short", me.score)).font(Theme.font(20, .heavy)).foregroundStyle(Theme.primary)
            }
            Spacer(minLength: 0)
            CastleRow(castle: me.castle, cardWidth: 34, highlightNext: myTurn && selected.map { isBuild($0) } == true)
        }
        .padding(.horizontal, 4)
    }

    private func isBuild(_ c: Card) -> Bool {
        engine.legalActions(for: engine.human).contains(.build(c))
    }

    /// Ce poți face cu cartea aleasă.
    @ViewBuilder
    private var actionPanel: some View {
        if myTurn, let c = selected {
            let legal = engine.legalActions(for: engine.human).filter { $0.card == c }
            HStack(spacing: 8) {
                ForEach(legal, id: \.self) { a in
                    switch a {
                    case .build:
                        actionButton(L("c.act.build"), "building.columns.fill", primary: true) { engine.humanAct(a) }
                    case .shield:
                        actionButton(L("c.act.shield"), "shield.fill", primary: true) { engine.humanAct(a) }
                    case .discard:
                        actionButton(L("c.act.discard"), "arrow.down.to.line", primary: false) { engine.humanAct(a) }
                    case .attack:
                        EmptyView()
                    }
                }
                if legal.contains(where: { if case .attack = $0 { return true }; return false }) {
                    Text(L("c.act.pickTarget")).font(Theme.font(12, .bold)).foregroundStyle(Theme.gold)
                        .lineLimit(2).minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .transition(.opacity)
        } else if myTurn {
            let tip = CastelBot.choose(for: engine.human, engine: engine, mistakes: false)
            Text(tip.map { L("c.tip", describe($0)) } ?? L("c.pickCard"))
                .font(Theme.font(12, .semibold)).foregroundStyle(Theme.gold)
                .lineLimit(2).frame(maxWidth: .infinity)
        } else {
            Color.clear.frame(height: 20)
        }
    }

    private func describe(_ a: CastelAction) -> String {
        switch a {
        case .build(let c): return L("c.tip.build", c.label)
        case .attack(let c, let t): return L("c.tip.attack", c.label, engine.players[t].name)
        case .shield(let c): return L("c.tip.shield", c.label)
        case .discard(let c): return L("c.tip.discard", c.label)
        }
    }

    private func actionButton(_ title: String, _ icon: String, primary: Bool, _ action: @escaping () -> Void) -> some View {
        Button { action(); selected = nil } label: {
            Label(title, systemImage: icon)
                .font(Theme.font(14, .bold))
                .foregroundStyle(primary ? Theme.onPrimary : Theme.ink)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Capsule().fill(primary ? Theme.primary : Theme.raised))
        }
        .buttonStyle(.plain)
    }
}

/// Castelul unui jucător: nivelurile, de la As în sus.
struct CastleRow: View {
    let castle: [Card]
    var cardWidth: CGFloat = 26
    var highlightNext = false
    var body: some View {
        HStack(spacing: -cardWidth * 0.45) {
            ForEach(0..<CastelRules.levels, id: \.self) { i in
                if i < castle.count {
                    CardView(card: castle[i], width: cardWidth)
                        .offset(y: -CGFloat(i) * cardWidth * 0.12)
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                                removal: .scale(scale: 0.3).combined(with: .opacity)))
                } else {
                    RoundedRectangle(cornerRadius: cardWidth * 0.14, style: .continuous)
                        .strokeBorder(i == castle.count && highlightNext ? Theme.gold : Theme.line,
                                      style: StrokeStyle(lineWidth: i == castle.count && highlightNext ? 2 : 1, dash: [3]))
                        .frame(width: cardWidth, height: cardWidth * 1.42)
                        .offset(y: -CGFloat(i) * cardWidth * 0.12)
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: castle.count)
    }
}

struct CastelOpponentView: View {
    let player: CastelPlayer
    @ObservedObject var engine: CastelEngine
    let targetable: Bool

    var body: some View {
        let isTurn = engine.current == player.id && engine.phase == .playing
        let hit = engine.lastAttack.map { $0.to == player.id } ?? false
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                AvatarView(name: player.name, index: player.id, size: 26)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: player.name).font(Theme.font(13, .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                    Text(L("w.pts.short", player.score)).font(Theme.font(11, .semibold)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                if player.shielded {
                    Image(systemName: "shield.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.gold)
                }
            }
            CastleRow(castle: player.castle, cardWidth: 18)
                .frame(height: 40)
            HStack(spacing: 3) {
                Image(systemName: "rectangle.portrait.on.rectangle.portrait").font(.system(size: 9, weight: .bold))
                Text("\(player.hand.count)").font(Theme.font(11, .bold))
                Text("·").font(Theme.font(11, .bold))
                Text("\(player.castle.count)/\(CastelRules.levels)").font(Theme.font(11, .bold))
            }
            .foregroundStyle(Theme.muted)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(isTurn ? Theme.raised : Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(targetable ? Theme.accent : (isTurn ? Theme.gold : Theme.line), lineWidth: targetable ? 2.5 : (isTurn ? 1.5 : 1)))
        .overlay(alignment: .topTrailing) {
            if targetable {
                Image(systemName: "scope").font(.system(size: 14, weight: .black)).foregroundStyle(.white)
                    .padding(5).background(Circle().fill(Theme.accent)).offset(x: 4, y: -6)
            }
        }
        .scaleEffect(hit ? 0.96 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: engine.discardPile.count)
    }
}

// MARK: - Mâna

struct CastelHandView: View {
    @ObservedObject var engine: CastelEngine
    @Binding var selected: Card?
    @Environment(\.compactLayout) private var compact
    private var maxCardW: CGFloat { compact ? 58 : 70 }

    var body: some View {
        GeometryReader { geo in
            let hand = engine.players[engine.human].hand
            let count = max(hand.count, 1)
            let cardW: CGFloat = min(maxCardW, geo.size.width / 4.4)
            let natural = CGFloat(count) * cardW + CGFloat(count - 1) * 6
            let spacing = natural > geo.size.width ? (geo.size.width - CGFloat(count) * cardW) / CGFloat(max(count - 1, 1)) : 6
            let myTurn = engine.phase == .playing && engine.current == engine.human
            let useful = Set(engine.legalActions(for: engine.human).compactMap { a -> Card? in
                if case .discard = a { return nil }; return a.card
            })
            HStack(spacing: spacing) {
                ForEach(hand) { card in
                    let isSel = selected == card
                    CardView(card: card, width: cardW, dimmed: myTurn && !useful.contains(card) && !isSel, glow: isSel)
                        .overlay(alignment: .bottom) { roleBadge(card, width: cardW) }
                        .offset(y: isSel ? -18 : (myTurn && useful.contains(card) ? -8 : 0))
                        .onTapGesture {
                            guard myTurn else { return }
                            Haptics.tap()
                            selected = isSel ? nil : card
                        }
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                                removal: .scale(scale: 0.5).combined(with: .opacity)))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selected)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hand)
        }
        .frame(height: maxCardW * 1.42 + 22)
    }

    /// Mic semn pe carte: minge, blocaj, joker, scut.
    @ViewBuilder
    private func roleBadge(_ c: Card, width: CGFloat) -> some View {
        let icon: String? = CastelRules.isBall(c) ? "circle.fill"
            : CastelRules.isJack(c) ? "hand.raised.fill"
            : CastelRules.isQueen(c) ? "star.fill"
            : CastelRules.isKing(c) ? "shield.fill" : nil
        if let icon {
            Image(systemName: icon).font(.system(size: width * 0.17, weight: .bold))
                .foregroundStyle(.white)
                .padding(width * 0.06)
                .background(Circle().fill(CastelRules.isBall(c) ? Theme.accent : Theme.amber))
                .offset(y: width * 0.12)
        }
    }
}

// MARK: - Rezumat

struct CastelSummaryView: View {
    @ObservedObject var engine: CastelEngine
    let onNext: () -> Void
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
                Image(systemName: "building.columns.fill").font(.system(size: 34, weight: .bold)).foregroundStyle(Theme.amber)
                Text(L("c.summary.title", engine.players[rec.winner].name)).font(Theme.display(30)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text(L("c.summary.sub", rec.id + 1)).font(Theme.font(14, .medium)).foregroundStyle(Theme.muted)
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
                        if !over, let r = rec {
                            Text("+\(r.points[i])").font(Theme.font(15, .bold)).foregroundStyle(Theme.green)
                        }
                        Text("\(p.score)").font(Theme.font(17, .heavy)).foregroundStyle(Theme.primary)
                            .frame(minWidth: 44, alignment: .trailing)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.isHuman ? Theme.soft : Theme.bg))
                }
            }
            if over { Button(L("w.backToMenu"), action: onExit).buttonStyle(PrimaryButtonStyle()) }
            else { Button(L("c.nextRound"), action: onNext).buttonStyle(PrimaryButtonStyle()) }
        }
        .panel(padding: 22)
        .frame(maxWidth: 440)
    }
}

// MARK: - Reguli

struct CastelRulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    rule("figure.run", L("c.r.origin.t"), L("c.r.origin.x"))
                    rule("person.3.fill", L("c.r.setup.t"), L("c.r.setup.x"))
                    rule("building.columns.fill", L("c.r.build.t"), L("c.r.build.x"))
                    rule("circle.fill", L("c.r.ball.t"), L("c.r.ball.x"))
                    rule("hand.raised.fill", L("c.r.jack.t"), L("c.r.jack.x"))
                    rule("star.fill", L("c.r.queen.t"), L("c.r.queen.x"))
                    rule("shield.fill", L("c.r.king.t"), L("c.r.king.x"))
                    rule("arrow.triangle.2.circlepath", L("c.r.turn.t"), L("c.r.turn.x"))
                    rule("trophy.fill", L("c.r.score.t"), L("c.r.score.x", CastelRules.winBonus, CastelRules.targetScore))
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle(L("c.r.title"))
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
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.amber)
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
