import SwiftUI

extension Theme {
    /// Culoarea Macao: magenta de neon.
    static let macao = Color(hex: 0xE0389A)
    static let macaoGradient = [Color(hex: 0xC2257F), Color(hex: 0x6A1148), Color(hex: 0x24051A)]
}

// MARK: - Cartea (cu Joker)

struct MacaoCardView: View {
    let card: Card
    var width: CGFloat = 64
    var dimmed = false
    var glow = false

    var body: some View {
        if MacaoRules.isJoker(card) {
            joker
        } else {
            CardView(card: card, width: width, dimmed: dimmed, glow: glow)
        }
    }

    private var joker: some View {
        let color = MacaoRules.isRedJoker(card) ? Theme.cardRed : Theme.cardInk
        let shape = RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
        return ZStack {
            shape.fill(Theme.cardFace)
                .shadow(color: .black.opacity(0.45), radius: width * 0.08, y: width * 0.05)
            shape.strokeBorder(glow ? Theme.gold : Theme.cardEdge, lineWidth: glow ? 3 : 0.75)
            VStack(spacing: width * 0.03) {
                Image(systemName: "star.fill").font(.system(size: width * 0.34, weight: .black))
                Text(verbatim: "JOKER").font(.system(size: width * 0.21, weight: .black).width(.compressed))
                Text(verbatim: "+\(MacaoRules.drawValue(card))").font(.system(size: width * 0.24, weight: .heavy))
            }
            .foregroundStyle(color)
        }
        .frame(width: width, height: width * 1.42)
        .overlay(shape.fill(Color.black.opacity(dimmed ? 0.5 : 0)))
        .shadow(color: glow ? Theme.gold.opacity(0.6) : .clear, radius: 10)
        .accessibilityLabel(MacaoRules.label(card))
    }
}

/// Desenul din meniu: un evantai cu Jokerul în față.
struct MacaoFanArt: View {
    var cardWidth: CGFloat = 46
    var body: some View {
        let cards = [Card(suit: .clubs, rank: 2), Card(suit: .diamonds, rank: 3), Card(suit: .spades, rank: 14),
                     Card(suit: .hearts, rank: 7), Card(suit: .hearts, rank: MacaoRules.jokerRank)]
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.offset) { i, c in
                MacaoCardView(card: c, width: cardWidth)
                    .rotationEffect(.degrees(Double(i - 2) * 15), anchor: .bottom)
                    .offset(x: CGFloat(i - 2) * cardWidth * 0.18)
            }
        }
    }
}

// MARK: - Meniu

struct MacaoMenuView: View {
    @AppStorage("macao.players") private var playerCount = 3
    @AppStorage("macao.variant") private var variant = 0
    @AppStorage("macao.target") private var target = 3
    @AppStorage("macao.announce") private var announce = true
    @AppStorage("macao.difficulty") private var difficulty = 1
    @AppStorage("speed") private var speed = 1.0
    @AppStorage("macao.games") private var gamesPlayed = 0
    @AppStorage("macao.wins") private var gamesWon = 0
    @AppStorage("macao.rounds") private var roundsWon = 0
    @State private var playing = false
    @State private var showRules = false

    private var rules: MacaoVariant { MacaoVariant(rawValue: variant) ?? .aceChanges }
    private var settings: MacaoSettings {
        MacaoSettings(players: playerCount, variant: rules, targetWins: target, announce: announce,
                      difficulty: MacaoDifficulty(rawValue: difficulty) ?? .medium, speed: speed)
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
                        Divider().overlay(Theme.line)
                        label(L("m.menu.target"))
                        Pills(options: [1, 3, 5], selection: $target) { "\($0)" }
                        Text(L("m.menu.playersLine", playerCount - 1, target))
                            .font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
                        Divider().overlay(Theme.line)
                        label(L("m.menu.variant"))
                        Pills(options: [0, 1], selection: $variant) { MacaoVariant(rawValue: $0)?.title ?? "" }
                        Text(variantLine(rules))
                            .font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Divider().overlay(Theme.line)
                        Toggle(isOn: $announce) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("m.menu.announce")).font(Theme.font(16, .semibold)).foregroundStyle(Theme.ink)
                                Text(L("m.menu.announceText", MacaoRules.forgetPenalty))
                                    .font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
                            }
                        }
                        .tint(Theme.primary)
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
                        stat("\(roundsWon)", L("m.stat.rounds"))
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
        }
        .fullScreenCover(isPresented: $playing) {
            MacaoGameView(settings: settings) { won, rounds in
                gamesPlayed += 1
                if won { gamesWon += 1 }
                roundsWon += rounds
            }
        }
        .sheet(isPresented: $showRules) { MacaoRulesView(variant: rules) }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: Theme.macaoGradient, startPoint: .topTrailing, endPoint: .bottomLeading))
            MacaoFanArt(cardWidth: 62)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 44).padding(.top, 30)
            VStack(alignment: .leading, spacing: 6) {
                GoldTag(text: L("w.menu.new.tag"))
                Text(verbatim: "MACAO").font(Theme.display(58)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                Text(L("m.menu.tagline")).font(Theme.font(15, .semibold)).foregroundStyle(.white.opacity(0.85))
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

/// „A schimbă culoarea · 4 stai o tură · 7 oprește tragerea”
func variantLine(_ v: MacaoVariant) -> String {
    L("m.variant.line", MacaoVariant.rankName(v.changer), MacaoVariant.rankName(v.skipper), MacaoVariant.rankName(v.stopper))
}

// MARK: - Masa

struct MacaoGameView: View {
    @StateObject private var engine: MacaoEngine
    @Environment(\.dismiss) private var dismiss
    let onFinish: (Bool, Int) -> Void
    @State private var selected: [Card] = []
    @State private var choosingSuit = false
    @State private var confirmQuit = false
    @State private var showRules = false
    @State private var reported = false

    init(settings: MacaoSettings, onFinish: @escaping (Bool, Int) -> Void) {
        _engine = StateObject(wrappedValue: MacaoEngine(settings: settings))
        self.onFinish = onFinish
    }

    init(engine: MacaoEngine, selected: [Card] = []) {
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
                    HStack(spacing: 8) {
                        ForEach(engine.players.dropFirst()) { p in
                            MacaoOpponentView(player: p, engine: engine)
                        }
                    }
                    table(compact: compact)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(TableFelt())
                    statusLine
                    actionPanel.frame(height: 84)
                    MacaoHandView(engine: engine, selected: selected, onTap: tap)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
                .environment(\.compactLayout, compact)
            }
            if engine.phase != .playing {
                Color.black.opacity(0.6).ignoresSafeArea().transition(.opacity)
                MacaoSummaryView(engine: engine,
                                 onNext: { withAnimation(.spring) { engine.nextRound() } },
                                 onExit: { dismiss() })
                    .padding(20)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: engine.phase)
        .sheet(isPresented: $showRules) { MacaoRulesView(variant: engine.variant) }
        .confirmationDialog(L("w.quit.title"), isPresented: $confirmQuit, titleVisibility: .visible) {
            Button(L("w.quit.yes"), role: .destructive) { engine.stop(); dismiss() }
            Button(L("w.quit.no"), role: .cancel) {}
        }
        .onChange(of: engine.current) { _, _ in clearSelection() }
        .onChange(of: engine.phase) { _, p in
            clearSelection()
            guard p == .gameOver, !reported else { return }
            reported = true
            let me = engine.players[engine.human]
            onFinish(me.roundsWon >= engine.settings.targetWins, me.roundsWon)
        }
        .onDisappear { engine.stop() }
    }

    private func clearSelection() {
        selected = []
        choosingSuit = false
    }

    private var topBar: some View {
        HStack {
            IconButton(system: "xmark") {
                if engine.phase == .gameOver { dismiss() } else { confirmQuit = true }
            }
            Spacer()
            VStack(spacing: 2) {
                Text(L("c.round", engine.round + 1)).font(Theme.display(24)).foregroundStyle(Theme.ink)
                Text(L("m.target", engine.settings.targetWins)).font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
            }
            Spacer()
            IconButton(system: "book.closed") { showRules = true }
                .accessibilityLabel(L("w.menu.rules"))
        }
        .padding(.top, 4)
    }

    // MARK: Masa: pachetul, teancul și ce e în joc

    private func table(compact: Bool) -> some View {
        let w: CGFloat = compact ? 74 : 92
        let recent = Array(engine.discardPile.suffix(3))
        return HStack(spacing: compact ? 16 : 22) {
            Button {
                if myTurn && !choosingSuit { engine.humanDraw() }
            } label: {
                VStack(spacing: 5) {
                    ZStack {
                        if engine.deck.isEmpty {
                            RoundedRectangle(cornerRadius: w * 0.11, style: .continuous)
                                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                .frame(width: w * 0.8, height: w * 0.8 * 1.42)
                        } else {
                            CardBackView(width: w * 0.8, emblem: "M").offset(x: -3, y: -3)
                            CardBackView(width: w * 0.8, emblem: "M")
                        }
                    }
                    Text("\(engine.deck.count)").font(Theme.font(12, .bold)).foregroundStyle(Theme.muted)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(drawTitle)

            ZStack {
                ForEach(recent) { c in
                    MacaoCardView(card: c, width: w)
                        .rotationEffect(.degrees(Double((c.id * 37) % 23) - 11))
                        .transition(.asymmetric(insertion: .scale(scale: 1.4).combined(with: .opacity), removal: .opacity))
                }
            }
            .frame(width: w * 1.3, height: w * 1.42 + 16)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: engine.discardPile.count)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("m.suit.now").uppercased()).font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.muted)
                    suitChip(engine.activeSuit, size: compact ? 38 : 44)
                }
                if engine.pendingDraw > 0 {
                    Text(verbatim: "+\(engine.pendingDraw)")
                        .font(Theme.display(26)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Capsule().fill(Theme.accent))
                        .transition(.scale.combined(with: .opacity))
                } else if engine.pendingSkip > 0 {
                    Label(engine.pendingSkip > 1 ? "×\(engine.pendingSkip)" : "", systemImage: "pause.fill")
                        .font(Theme.font(16, .heavy)).foregroundStyle(.black)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(Theme.gold))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 64, alignment: .leading)
            .animation(.spring(response: 0.3), value: engine.pendingDraw)
            .animation(.spring(response: 0.3), value: engine.pendingSkip)
        }
        .padding(.vertical, 8)
    }

    private func suitChip(_ suit: Suit?, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(Theme.cardFace)
            if let s = suit {
                Text(s.symbol).font(.system(size: size * 0.6)).foregroundStyle(s.isRed ? Theme.cardRed : Theme.cardInk)
            } else {
                Image(systemName: "star.fill").font(.system(size: size * 0.45, weight: .bold)).foregroundStyle(Theme.macao)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Theme.gold, lineWidth: 2))
        .accessibilityLabel(suit?.name ?? L("m.suit.any"))
    }

    private var statusLine: some View {
        let p = engine.players[engine.current]
        return VStack(spacing: 2) {
            Text(p.isHuman ? L("w.turn.you") : L("w.turn.playing", p.name))
                .font(Theme.font(16, .bold)).foregroundStyle(Theme.ink).lineLimit(1)
            Text(engine.lastEvent ?? L("m.hint")).font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
                .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Ce poți face

    private var drawTitle: String {
        if engine.pendingDraw > 0 { return L("m.act.drawN", engine.pendingDraw) }
        if engine.pendingSkip > 0 { return L("m.act.wait") }
        return L("m.act.draw")
    }

    @ViewBuilder
    private var actionPanel: some View {
        if engine.awaitingMacao {
            MacaoShoutButton(deadline: engine.macaoDeadline) { engine.sayMacao() }
        } else if myTurn && choosingSuit {
            VStack(spacing: 6) {
                Text(L("m.pickSuit")).font(Theme.font(13, .bold)).foregroundStyle(Theme.gold)
                HStack(spacing: 12) {
                    ForEach(Suit.allCases, id: \.self) { s in
                        Button {
                            let cards = selected
                            clearSelection()
                            engine.humanPlay(cards, suit: s)
                        } label: {
                            Text(s.symbol).font(.system(size: 28))
                                .foregroundStyle(s.isRed ? Theme.cardRed : Theme.cardInk)
                                .frame(width: 54, height: 46)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.cardFace))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(s.name)
                    }
                }
            }
        } else if myTurn {
            VStack(spacing: 8) {
                Text(tipLine).font(Theme.font(12, .semibold)).foregroundStyle(Theme.gold)
                    .lineLimit(1).minimumScaleFactor(0.8)
                HStack(spacing: 8) {
                    if !selected.isEmpty {
                        pill(selected.count > 1 ? L("m.act.playN", selected.count) : L("m.act.play"), "play.fill", primary: true) {
                            if engine.needsSuit(selected) {
                                withAnimation(.spring(response: 0.3)) { choosingSuit = true }
                            } else {
                                let cards = selected
                                clearSelection()
                                engine.humanPlay(cards)
                            }
                        }
                    }
                    pill(drawTitle, engine.pendingSkip > 0 ? "pause.fill" : "rectangle.stack.badge.plus", primary: false) {
                        clearSelection()
                        engine.humanDraw()
                    }
                }
            }
        } else {
            Color.clear
        }
    }

    private var tipLine: String {
        switch MacaoBot.choose(for: engine.human, engine: engine, mistakes: false) {
        case .draw:
            if engine.pendingDraw > 0 { return L("c.tip", L("m.tip.drawN", engine.pendingDraw)) }
            if engine.pendingSkip > 0 { return L("c.tip", L("m.tip.wait")) }
            return L("c.tip", L("m.tip.draw"))
        case .play(let cards, let suit):
            let list = cards.map(MacaoRules.label).joined(separator: " ")
            if let s = suit { return L("c.tip", L("m.tip.playSuit", list, s.symbol)) }
            return L("c.tip", L("m.tip.play", list))
        }
    }

    private func pill(_ title: String, _ icon: String, primary: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(Theme.font(15, .bold))
                .foregroundStyle(primary ? Theme.onPrimary : Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.8)
                .padding(.horizontal, 16).padding(.vertical, 11)
                .frame(maxWidth: primary ? .infinity : nil)
                .background(Capsule().fill(primary ? Theme.primary : Theme.raised))
                .overlay(Capsule().strokeBorder(primary ? .clear : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// Atingi o carte ca s-o alegi; mai atingi altele de aceeași valoare ca să le pui împreună.
    private func tap(_ c: Card) {
        guard myTurn else { return }
        choosingSuit = false
        let hand = engine.players[engine.human].hand
        if let i = selected.firstIndex(of: c) {
            selected.remove(at: i)
            if let first = selected.first, !engine.canPlay(first) {
                if let j = selected.firstIndex(where: { engine.canPlay($0) }) { selected.swapAt(0, j) } else { selected = [] }
            }
        } else if let first = selected.first, first.rank == c.rank {
            selected.append(c)
        } else if engine.canPlay(c) {
            selected = [c]
        } else if let sibling = hand.first(where: { $0.rank == c.rank && engine.canPlay($0) }) {
            selected = [sibling, c]
        } else {
            Haptics.warning()
            return
        }
        Haptics.tap()
    }
}

/// Butonul „MACAO!”, cu timpul care se scurge.
struct MacaoShoutButton: View {
    let deadline: Date
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(verbatim: "MACAO!").font(Theme.display(34)).foregroundStyle(.black)
                TimelineView(.periodic(from: .now, by: 0.05)) { ctx in
                    let left = max(0, min(1, deadline.timeIntervalSince(ctx.date) / MacaoEngine.macaoWindow))
                    GeometryReader { geo in
                        Capsule().fill(.black.opacity(0.75)).frame(width: geo.size.width * left)
                    }
                    .frame(height: 5)
                }
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Capsule().fill(Theme.gold))
            .shadow(color: Theme.gold.opacity(0.5), radius: 14, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Macao")
    }
}

struct MacaoOpponentView: View {
    let player: MacaoPlayer
    @ObservedObject var engine: MacaoEngine
    @Environment(\.compactLayout) private var compact

    var body: some View {
        let isTurn = engine.current == player.id && engine.phase == .playing
        let count = player.hand.count
        let shown = min(count, 7)
        let w: CGFloat = compact ? 26 : 32
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                AvatarView(name: player.name, index: player.id, size: 28)
                    .overlay(Circle().strokeBorder(Theme.gold, lineWidth: isTurn ? 3 : 0).padding(-3))
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: player.name).font(Theme.font(13, .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                    Text(count == 1 ? L("w.cards.one") : L("w.cards.n", count))
                        .font(Theme.font(11, .semibold)).foregroundStyle(count <= 2 ? Theme.gold : Theme.muted).lineLimit(1)
                }
            }
            ZStack {
                ForEach(0..<shown, id: \.self) { i in
                    CardBackView(width: w, emblem: "M")
                        .rotationEffect(.degrees((Double(i) - Double(shown - 1) / 2) * 9), anchor: .bottom)
                }
            }
            .frame(height: w * 1.42 + 8)
            Group {
                if count == 1 && player.saidMacao {
                    GoldTag(text: "Macao!")
                } else if player.waits > 0 {
                    Label(L("m.badge.waits"), systemImage: "pause.fill")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.gold)
                } else {
                    Text(L("m.wins", player.roundsWon)).font(Theme.font(11, .semibold)).foregroundStyle(Theme.muted)
                }
            }
            .lineLimit(1)
            .frame(height: 16)
        }
        .padding(.vertical, 8).padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isTurn ? Theme.raised.opacity(0.9) : Theme.surface.opacity(0.75)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(isTurn ? Theme.gold : Theme.line, lineWidth: isTurn ? 1.5 : 1))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: count)
    }
}

// MARK: - Mâna

struct MacaoHandView: View {
    @ObservedObject var engine: MacaoEngine
    let selected: [Card]
    let onTap: (Card) -> Void
    @Environment(\.compactLayout) private var compact
    private var cardW: CGFloat { compact ? 58 : 68 }

    var body: some View {
        GeometryReader { geo in
            let hand = engine.players[engine.human].hand
            let count = max(hand.count, 1)
            let room = geo.size.width - 8
            let fit = (room - CGFloat(count) * cardW) / CGFloat(max(count - 1, 1))
            // cărțile se suprapun cât e nevoie, dar rămâne mereu o fâșie de atins; peste atât, mâna se derulează
            let spacing = min(6, max(fit, 26 - cardW))
            let width = CGFloat(count) * cardW + CGFloat(count - 1) * spacing
            let myTurn = engine.phase == .playing && engine.current == engine.human
            let playable = Set(engine.playable(for: engine.human))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(hand) { card in
                        let order = selected.firstIndex(of: card)
                        let canGo = playable.contains(card)
                        MacaoCardView(card: card, width: cardW, dimmed: myTurn && !canGo && order == nil, glow: order != nil)
                            .overlay(alignment: .top) {
                                if let order, selected.count > 1 {
                                    Text("\(order + 1)").font(.system(size: 12, weight: .black)).foregroundStyle(.black)
                                        .frame(width: 20, height: 20).background(Circle().fill(Theme.gold)).offset(y: -8)
                                }
                            }
                            .offset(y: order != nil ? -18 : (myTurn && canGo ? -8 : 0))
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
        .frame(height: cardW * 1.42 + 26)
    }
}

// MARK: - Rezumat

struct MacaoSummaryView: View {
    @ObservedObject var engine: MacaoEngine
    let onNext: () -> Void
    let onExit: () -> Void

    var body: some View {
        let over = engine.phase == .gameOver
        let rec = engine.history.last
        VStack(spacing: 16) {
            if over {
                let won = engine.players[engine.human].roundsWon >= engine.settings.targetWins
                Image(systemName: won ? "trophy.fill" : "flag.checkered")
                    .font(.system(size: 42, weight: .bold)).foregroundStyle(won ? Theme.gold : Theme.primary)
                Text(won ? L("w.won") : L("w.gameOver")).font(Theme.display(40)).foregroundStyle(Theme.ink)
            } else if let rec {
                Image(systemName: "hand.thumbsup.fill").font(.system(size: 34, weight: .bold)).foregroundStyle(Theme.macao)
                Text(L("m.summary.title", engine.players[rec.winner].name)).font(Theme.display(30)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text(L("m.summary.sub", rec.id + 1, engine.settings.targetWins))
                    .font(Theme.font(14, .medium)).foregroundStyle(Theme.muted)
            }
            VStack(spacing: 8) {
                let order = over ? engine.players.sorted { $0.roundsWon > $1.roundsWon }.map(\.id) : engine.players.map(\.id)
                ForEach(Array(order.enumerated()), id: \.element) { pos, i in
                    let p = engine.players[i]
                    let left = rec?.cardsLeft[i] ?? 0
                    HStack(spacing: 10) {
                        if over { Text("\(pos + 1)").font(Theme.font(15, .bold)).foregroundStyle(Theme.muted).frame(width: 18) }
                        AvatarView(name: p.name, index: p.id, size: 30)
                        Text(p.name).font(Theme.font(16, .semibold)).foregroundStyle(Theme.ink)
                        Spacer()
                        if !over {
                            Text(left == 0 ? "✓" : (left == 1 ? L("w.cards.one") : L("w.cards.n", left)))
                                .font(Theme.font(14, .bold)).foregroundStyle(left == 0 ? Theme.green : Theme.muted)
                        }
                        Text(L("m.wins", p.roundsWon)).font(Theme.font(16, .heavy)).foregroundStyle(Theme.primary)
                            .frame(minWidth: 70, alignment: .trailing)
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

struct MacaoRulesView: View {
    let variant: MacaoVariant
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let changer = MacaoVariant.rankName(variant.changer)
        let skipper = MacaoVariant.rankName(variant.skipper)
        let stopper = MacaoVariant.rankName(variant.stopper)
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    rule("flag.checkered", L("m.r.goal.t"), L("m.r.goal.x"))
                    rule("person.3.fill", L("m.r.setup.t"), L("m.r.setup.x", MacaoRules.handSize))
                    rule("rectangle.on.rectangle", L("m.r.play.t"), L("m.r.play.x"))
                    rule("plus.circle.fill", L("m.r.draw.t"), L("m.r.draw.x"))
                    rule("star.fill", L("m.r.joker.t"), L("m.r.joker.x"))
                    rule("paintpalette.fill", L("m.r.changer.t", changer), L("m.r.changer.x"))
                    rule("pause.fill", L("m.r.skipper.t", skipper), L("m.r.skipper.x", skipper))
                    rule("hand.raised.fill", L("m.r.stopper.t", stopper), L("m.r.stopper.x"))
                    rule("megaphone.fill", L("m.r.macao.t"), L("m.r.macao.x", MacaoRules.forgetPenalty))
                    rule("trophy.fill", L("m.r.score.t"), L("m.r.score.x"))
                    Text(L("m.r.variants")).font(Theme.font(13, .medium)).foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center).padding(.horizontal, 8).padding(.top, 4)
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle(L("m.r.title"))
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
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.macao)
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
