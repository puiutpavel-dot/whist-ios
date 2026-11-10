import Foundation
import SwiftUI

// MARK: - Jocurile din Renț

enum RentzGame: String, CaseIterable, Identifiable, Hashable {
    case kingOfHearts, queens, diamonds, tricks, totals, whist, totalsPlus, tenOfClubs, rentz
    var id: String { rawValue }

    var isPositive: Bool { self == .whist || self == .totalsPlus || self == .tenOfClubs || self == .rentz }
    var isTrickGame: Bool { self != .rentz }
    /// Jocurile în care vrei să iei levate (și, la Totale Plus, tot ce e „penalizare” la Totale).
    var wantsTricks: Bool { self == .whist || self == .totalsPlus }

    var name: String { L("r.game.\(rawValue)") }
    var short: String { short(RentzScore.current) }

    func short(_ s: RentzScoring) -> String {
        switch self {
        case .kingOfHearts: return L("r.short.kingOfHearts", abs(s.kingOfHearts))
        case .queens: return L("r.short.queens", abs(s.queen))
        case .diamonds: return L("r.short.diamonds", abs(s.diamond))
        case .tricks: return L("r.short.tricks", abs(s.trickMinus))
        case .whist: return L("r.short.whist", s.trickPlus)
        case .tenOfClubs: return L("r.short.tenOfClubs", s.tenOfClubs)
        default: return L("r.short.\(rawValue)")
        }
    }

    func rules(_ s: RentzScoring) -> String {
        switch self {
        case .kingOfHearts: return L("r.rules.kingOfHearts", abs(s.kingOfHearts))
        case .queens: return L("r.rules.queens", abs(s.queen))
        case .diamonds: return L("r.rules.diamonds", abs(s.diamond))
        case .tricks: return L("r.rules.tricks", abs(s.trickMinus))
        case .whist: return L("r.rules.whist", s.trickPlus)
        case .tenOfClubs: return L("r.rules.tenOfClubs", s.tenOfClubs)
        case .rentz:
            let p = s.places
            return L("r.rules.rentz", p[0], p[1], p[2], p[3], p[4])
        default: return L("r.rules.\(rawValue)")
        }
    }

    var icon: String {
        switch self {
        case .kingOfHearts: return "crown.fill"
        case .queens: return "person.crop.circle.badge.exclamationmark"
        case .diamonds: return "suit.diamond.fill"
        case .tricks: return "square.stack.3d.down.right"
        case .totals: return "sum"
        case .whist: return "square.stack.3d.up.fill"
        case .totalsPlus: return "plus.circle.fill"
        case .tenOfClubs: return "suit.club.fill"
        case .rentz: return "rectangle.split.3x1"
        }
    }
}

/// Varianta de joc aleasă în meniu: punctajul (Clasic / Casino) și al optulea joc (Whist / Totale Plus).
struct RentzScoring: Equatable {
    enum Style: String, CaseIterable { case classic, casino }

    var style: Style = .classic
    var eighth: RentzGame = .whist

    var kingOfHearts: Int { style == .classic ? -300 : -100 }
    var queen: Int { style == .classic ? -75 : -25 }
    var diamond: Int { style == .classic ? -40 : -10 }
    var trickMinus: Int { style == .classic ? -40 : -10 }
    var trickPlus: Int { -trickMinus }
    var tenOfClubs: Int { -kingOfHearts }
    /// Punctele pentru locurile 1–5 la Renț; ultimul ia mereu 0.
    var places: [Int] { style == .classic ? [600, 300, 150, 75, 40] : [200, 100, 50, 25, 10] }

    /// Cele 8 jocuri ale partidei, în ordinea din tabel.
    var games: [RentzGame] { [.kingOfHearts, .queens, .diamonds, .tricks, .totals, eighth, .tenOfClubs, .rentz] }
}

/// Punctajul jocului în desfășurare (îl fixează motorul la pornire).
enum RentzScore {
    static var current = RentzScoring()

    static var kingOfHearts: Int { current.kingOfHearts }
    static var queen: Int { current.queen }
    static var diamond: Int { current.diamond }
    static var trickMinus: Int { current.trickMinus }
    static var trickPlus: Int { current.trickPlus }
    static var tenOfClubs: Int { current.tenOfClubs }
    static var games: [RentzGame] { current.games }

    /// Locurile la Renț: primul, al doilea… (până la al cincilea); ultimul 0.
    static func rentzPlace(_ place: Int, of n: Int) -> Int {
        if place >= n { return 0 }
        return current.places[min(place - 1, 4)]
    }

    static func isKingOfHearts(_ c: Card) -> Bool { c.suit == .hearts && c.rank == 13 }
    static func isTenOfClubs(_ c: Card) -> Bool { c.suit == .clubs && c.rank == 10 }

    /// Punctele pentru cărțile luate într-o levată, în jocul dat.
    static func trickValue(_ cards: [Card], game: RentzGame) -> Int {
        switch game {
        case .kingOfHearts: return cards.contains(where: isKingOfHearts) ? kingOfHearts : 0
        case .queens: return cards.filter { $0.rank == 12 }.count * queen
        case .diamonds: return cards.filter { $0.suit == .diamonds }.count * diamond
        case .tricks: return trickMinus
        case .whist: return trickPlus
        case .tenOfClubs: return cards.contains(where: isTenOfClubs) ? tenOfClubs : 0
        case .totals:
            return trickValue(cards, game: .kingOfHearts) + trickValue(cards, game: .queens)
                + trickValue(cards, game: .diamonds) + trickMinus
        case .totalsPlus: return -trickValue(cards, game: .totals)
        case .rentz: return 0
        }
    }
}

struct RentzPlayer: Identifiable {
    let id: Int
    var name: String
    var isHuman: Bool
    var hand: [Card] = []
    var score = 0
    var chosen: Set<RentzGame> = []
    var dealPoints = 0
    var tricks = 0
    var place: Int? = nil
}

struct RentzDealRecord: Identifiable {
    let id: Int
    let game: RentzGame
    let chooser: Int
    let deltas: [Int]
    let totals: [Int]
}

/// Un rând din Renț: cărțile unei culori puse pe masă, de la `low` la `high` (pornind de la valet).
struct RentzRow: Hashable {
    var low: Int
    var high: Int
}

// MARK: - Motorul

@MainActor
final class RentzEngine: ObservableObject {
    enum Phase: Equatable { case choosing, playing, trickEnd, dealEnd, gameOver }

    @Published private(set) var players: [RentzPlayer]
    @Published private(set) var phase: Phase = .choosing
    @Published private(set) var dealIndex = 0
    @Published private(set) var chooser: Int
    @Published private(set) var game: RentzGame? = nil
    @Published private(set) var current = 0
    @Published private(set) var trick: [PlayedCard] = []
    @Published private(set) var trickWinner: Int? = nil
    @Published private(set) var rows: [Suit: RentzRow] = [:]
    @Published private(set) var history: [RentzDealRecord] = []
    @Published private(set) var lastEvent: String? = nil
    /// Toate cărțile jucate în mâna curentă (levate).
    @Published private(set) var playedThisDeal: [PlayedCard] = []

    let human = 0
    let speed: Double
    var frozen = false
    private var botTask: Task<Void, Never>?
    private var finishedCount = 0

    static let botNames = ["Ana", "Mihai", "Ioana", "Radu", "Elena"]

    let scoring: RentzScoring

    init(players count: Int, speed: Double = 1, name: String = "", scoring: RentzScoring = RentzScoring()) {
        self.speed = speed
        self.scoring = scoring
        RentzScore.current = scoring
        let me = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var list = [RentzPlayer(id: 0, name: me.isEmpty ? L("name.you") : String(me.prefix(12)), isHuman: true)]
        for i in 1..<count { list.append(RentzPlayer(id: i, name: Self.botNames[i - 1], isHuman: false)) }
        players = list
        chooser = Int.random(in: 0..<count)
        startDeal()
    }

    // MARK: Derivate

    var n: Int { players.count }
    var games: [RentzGame] { scoring.games }
    var totalDeals: Int { n * games.count }
    var low: Int { Deck.lowestRank(players: n) }
    var leadSuit: Suit? { trick.first?.card.suit }

    func available(for p: Int) -> [RentzGame] {
        games.filter { !players[p].chosen.contains($0) }
    }

    func legalCards(for p: Int) -> [Card] {
        let hand = players[p].hand
        guard phase == .playing, let g = game else { return [] }
        if g == .rentz { return hand.filter(isPlayableInRentz) }
        guard let lead = leadSuit else { return hand }
        let follow = hand.filter { $0.suit == lead }
        return follow.isEmpty ? hand : follow
    }

    func isPlayableInRentz(_ c: Card) -> Bool {
        guard let row = rows[c.suit] else { return c.rank == 11 }
        return c.rank == row.low - 1 || c.rank == row.high + 1
    }

    func currentWinner() -> PlayedCard? {
        guard let first = trick.first else { return nil }
        return trick.filter { $0.card.suit == first.card.suit }.max { $0.card.rank < $1.card.rank }
    }

    /// Cartea ar câștiga levata dacă ar fi jucată acum?
    func wouldWin(_ c: Card) -> Bool {
        guard let best = currentWinner() else { return true }
        return c.suit == best.card.suit && c.rank > best.card.rank
    }

    // MARK: Flux

    private func startDeal() {
        RentzScore.current = scoring
        var deck = Deck.make(players: n).shuffled()
        for i in players.indices {
            players[i].hand = []
            players[i].dealPoints = 0
            players[i].tricks = 0
            players[i].place = nil
        }
        for c in 0..<8 {
            for k in 0..<n { players[(chooser + k) % n].hand.append(deck[c * n + k]) }
        }
        deck.removeAll()
        for i in players.indices { players[i].hand = Self.sortHand(players[i].hand) }
        game = nil
        trick = []
        trickWinner = nil
        rows = [:]
        playedThisDeal = []
        finishedCount = 0
        lastEvent = nil
        current = chooser
        phase = .choosing
        runBots()
    }

    static func sortHand(_ hand: [Card]) -> [Card] {
        let order: [Suit] = [.spades, .hearts, .clubs, .diamonds]
        return hand.sorted {
            let a = order.firstIndex(of: $0.suit) ?? 0, b = order.firstIndex(of: $1.suit) ?? 0
            return a == b ? $0.rank > $1.rank : a < b
        }
    }

    func humanChoose(_ g: RentzGame) {
        guard phase == .choosing, chooser == human, !players[human].chosen.contains(g) else { return }
        choose(g)
        runBots()
    }

    func humanPlay(_ c: Card) {
        guard phase == .playing, current == human, legalCards(for: human).contains(c) else { return }
        Haptics.tap()
        play(c, by: human)
        runBots()
    }

    func nextDeal() {
        guard phase == .dealEnd else { return }
        dealIndex += 1
        chooser = (chooser + 1) % n
        startDeal()
    }

    func stop() { botTask?.cancel() }

    private func choose(_ g: RentzGame) {
        guard phase == .choosing else { return }
        players[chooser].chosen.insert(g)
        game = g
        current = chooser
        phase = .playing
    }

    private func play(_ c: Card, by p: Int) {
        guard phase == .playing, p == current, let g = game, players[p].hand.contains(c) else { return }
        if g == .rentz {
            guard isPlayableInRentz(c) else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                players[p].hand.removeAll { $0 == c }
                if var row = rows[c.suit] {
                    row.low = min(row.low, c.rank); row.high = max(row.high, c.rank)
                    rows[c.suit] = row
                } else {
                    rows[c.suit] = RentzRow(low: c.rank, high: c.rank)
                }
                playedThisDeal.append(PlayedCard(player: p, card: c))
            }
            advanceRentz(after: c, by: p)
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            players[p].hand.removeAll { $0 == c }
            trick.append(PlayedCard(player: p, card: c))
            playedThisDeal.append(PlayedCard(player: p, card: c))
        }
        if trick.count == n {
            trickWinner = currentWinner()?.player
            phase = .trickEnd
        } else {
            current = (p + 1) % n
        }
    }

    /// Renț: cine nu are carte bună trece; asul dă încă o mutare; cea mai mică carte îl sare pe următorul.
    private func advanceRentz(after c: Card, by p: Int) {
        if players[p].hand.isEmpty && players[p].place == nil {
            finishedCount += 1
            players[p].place = finishedCount
            lastEvent = L("r.event.finished", players[p].name, finishedCount)
        }
        let active = players.filter { $0.place == nil }
        if active.count <= 1 {
            if let last = active.first { finishedCount += 1; players[last.id].place = finishedCount }
            endDeal()
            return
        }
        if c.rank == 14 && players[p].place == nil {
            lastEvent = L("r.event.ace", players[p].name)
            current = p
            return
        }
        var next = nextActive(after: p)
        if c.rank == low {
            lastEvent = L("r.event.skip", players[next].name)
            next = nextActive(after: next)
        }
        current = next
    }

    private func nextActive(after p: Int) -> Int {
        var q = (p + 1) % n
        for _ in 0..<n {
            if players[q].place == nil { return q }
            q = (q + 1) % n
        }
        return p
    }

    /// Renț: jucătorul la rând nu are nicio carte bună.
    private func passRentz() {
        let p = current
        lastEvent = L("r.event.pass", players[p].name)
        current = nextActive(after: p)
    }

    private func finishTrick() {
        guard let w = trickWinner, let g = game else { return }
        let cards = trick.map(\.card)
        let pts = RentzScore.trickValue(cards, game: g)
        withAnimation(.easeInOut(duration: 0.3)) {
            players[w].tricks += 1
            players[w].dealPoints += pts
            trick = []
        }
        trickWinner = nil
        if dealIsOver(after: cards) {
            endDeal()
        } else {
            current = w
            phase = .playing
        }
    }

    /// Jocurile cu o singură carte „premiată” se opresc când au ieșit toate penalizările.
    private func dealIsOver(after cards: [Card]) -> Bool {
        if players.allSatisfy({ $0.hand.isEmpty }) { return true }
        let played = playedThisDeal.map(\.card)
        switch game {
        case .kingOfHearts: return cards.contains(where: RentzScore.isKingOfHearts)
        case .tenOfClubs: return cards.contains(where: RentzScore.isTenOfClubs)
        case .queens: return played.filter { $0.rank == 12 }.count == 4
        case .diamonds: return played.filter { $0.suit == .diamonds }.count == 15 - low
        default: return false
        }
    }

    private func endDeal() {
        guard let g = game else { return }
        if g == .rentz {
            for i in players.indices {
                players[i].dealPoints = RentzScore.rentzPlace(players[i].place ?? n, of: n)
            }
        }
        var deltas: [Int] = []
        for i in players.indices {
            players[i].score += players[i].dealPoints
            deltas.append(players[i].dealPoints)
        }
        history.append(RentzDealRecord(id: dealIndex, game: g, chooser: chooser, deltas: deltas,
                                       totals: players.map(\.score)))
        if deltas[human] >= 0 && g.isPositive && deltas[human] > 0 { Haptics.success() }
        else if deltas[human] < 0 { Haptics.warning() }
        phase = dealIndex == totalDeals - 1 ? .gameOver : .dealEnd
    }

    // MARK: Derulare rapidă (capturi + test de anduranță)

    @discardableResult
    func fastForward(maxSteps: Int = 20000, until stop: (RentzEngine) -> Bool) -> Bool {
        botTask?.cancel()
        frozen = true
        for _ in 0..<maxSteps {
            if stop(self) { return true }
            if !step() { return stop(self) }
        }
        return stop(self)
    }

    /// Un pas, cu logica adversarilor pentru oricine e la rând. Întoarce false la final.
    private func step() -> Bool {
        switch phase {
        case .choosing:
            choose(RentzBot.chooseGame(for: chooser, engine: self))
        case .playing:
            if let card = RentzBot.chooseCard(for: current, engine: self) { play(card, by: current) }
            else if game == .rentz { passRentz() }
            else { return false }
        case .trickEnd: finishTrick()
        case .dealEnd: nextDeal()
        case .gameOver: return false
        }
        return true
    }

    // MARK: Adversarii

    private func runBots() {
        botTask?.cancel()
        guard !frozen else { return }
        botTask = Task { [weak self] in await self?.botLoop() }
    }

    private func pause(_ s: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(s / max(speed, 0.25) * 1_000_000_000))
    }

    private func botLoop() async {
        while !Task.isCancelled {
            switch phase {
            case .choosing:
                guard chooser != human else { return }
                await pause(0.9)
                if Task.isCancelled { return }
                choose(RentzBot.chooseGame(for: chooser, engine: self))
            case .playing:
                if current == human {
                    // în Renț, dacă n-ai nicio carte bună, treci automat
                    guard game == .rentz, legalCards(for: human).isEmpty else { return }
                    await pause(0.9)
                    if Task.isCancelled { return }
                    passRentz()
                    continue
                }
                await pause(game == .rentz ? 0.55 : 0.65)
                if Task.isCancelled { return }
                let p = current
                if let card = RentzBot.chooseCard(for: p, engine: self) { play(card, by: p) }
                else if game == .rentz { passRentz() }
                else { return }
            case .trickEnd:
                await pause(1.1)
                if Task.isCancelled { return }
                finishTrick()
            case .dealEnd, .gameOver:
                return
            }
        }
    }
}
