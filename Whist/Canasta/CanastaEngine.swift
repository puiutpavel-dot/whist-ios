import Foundation
import SwiftUI

/// Canasta clasică: 108 cărți (două pachete + 4 Jokeri), etalări de cărți de aceeași valoare,
/// canasta = 7 cărți, treiari roșii, teanc care se poate lua. 2 sau 3 jucători fiecare pentru el,
/// 4 jucători în două echipe.
struct CanastaCard: Identifiable, Hashable {
    let id: Int
    let suit: Suit
    /// 2...14, 15 = Joker
    let rank: Int

    var isJoker: Bool { rank == 15 }
    /// Jokerii și doiarii țin locul oricărei cărți.
    var isWild: Bool { rank == 15 || rank == 2 }
    var isRedThree: Bool { rank == 3 && suit.isRed }
    var isBlackThree: Bool { rank == 3 && !suit.isRed }
    var points: Int {
        if isJoker { return 50 }
        if rank == 2 || rank == 14 { return 20 }
        return rank >= 8 ? 10 : 5
    }
    var face: Card { Card(suit: suit, rank: rank) }
    var label: String { isJoker ? "Joker" : face.label }
}

struct CanastaMeld: Identifiable, Equatable {
    let rank: Int
    var cards: [CanastaCard]

    var id: Int { rank }
    var wilds: Int { cards.filter(\.isWild).count }
    var naturals: Int { cards.count - wilds }
    var isCanasta: Bool { cards.count >= 7 }
    var isNatural: Bool { wilds == 0 }
    var cardPoints: Int { cards.reduce(0) { $0 + $1.points } }
    var bonus: Int { isCanasta ? (isNatural ? 500 : 300) : 0 }
}

enum CanastaRules {
    static let deckSize = 108
    static let maxWilds = 3
    static let maxHands = 30

    static func handSize(players: Int) -> Int { players == 2 ? 15 : (players == 3 ? 13 : 11) }

    /// Câte puncte trebuie să aibă prima etalare, după scorul echipei.
    static func minimum(score: Int) -> Int {
        if score < 0 { return 15 }
        if score < 1500 { return 50 }
        return score < 3000 ? 90 : 120
    }

    static func fullDeck() -> [CanastaCard] {
        var d: [CanastaCard] = []
        for _ in 0..<2 {
            for s in Suit.allCases {
                for r in 2...14 { d.append(CanastaCard(id: d.count, suit: s, rank: r)) }
            }
            d.append(CanastaCard(id: d.count, suit: .spades, rank: 15))
            d.append(CanastaCard(id: d.count, suit: .hearts, rank: 15))
        }
        return d
    }

    static func sortHand(_ h: [CanastaCard]) -> [CanastaCard] {
        func key(_ c: CanastaCard) -> (Int, Int, Int) {
            (c.isWild ? 0 : 1, -c.rank, c.suit.rawValue * 1000 + c.id)
        }
        return h.sorted { key($0) < key($1) }
    }
}

enum CanastaStep: Equatable {
    case draw
    case takePile
    case meld([CanastaCard], rank: Int)
    case discard(CanastaCard)
}

struct CanastaSettings {
    var players = 2
    var target = 3000
    var difficulty: MacaoDifficulty = .medium
    var speed = 1.0
}

struct CanastaPlayer: Identifiable {
    let id: Int
    var name: String
    var isHuman: Bool
    var hand: [CanastaCard] = []
}

struct CanastaTeamResult: Equatable {
    var meldPoints = 0
    var canastaBonus = 0
    var redThrees = 0
    var outBonus = 0
    var handPenalty = 0
    var total: Int { meldPoints + canastaBonus + redThrees + outBonus - handPenalty }
}

struct CanastaHandRecord: Identifiable {
    let id: Int
    /// Cine a închis; `nil` dacă s-a terminat pachetul.
    let out: Int?
    let teams: [CanastaTeamResult]
}

@MainActor
final class CanastaEngine: ObservableObject {
    enum Phase: Equatable { case playing, handEnd, gameOver }
    enum Stage: Equatable { case draw, play }

    @Published private(set) var players: [CanastaPlayer]
    @Published private(set) var phase: Phase = .playing
    @Published private(set) var stage: Stage = .draw
    @Published private(set) var current = 0
    @Published private(set) var stock: [CanastaCard] = []
    @Published private(set) var pile: [CanastaCard] = []
    /// Etalările fiecărei echipe.
    @Published private(set) var melds: [[CanastaMeld]] = []
    @Published private(set) var redThrees: [[CanastaCard]] = []
    /// Echipa a făcut prima etalare.
    @Published private(set) var opened: [Bool] = []
    @Published private(set) var scores: [Int] = []
    @Published private(set) var round = 0
    /// Punctele etalate în tura asta, cât timp echipa nu a deschis.
    @Published private(set) var turnPoints = 0
    @Published private(set) var turnMelded = false
    @Published private(set) var lastEvent: String? = nil
    @Published private(set) var history: [CanastaHandRecord] = []

    let human = 0
    let settings: CanastaSettings
    var frozen = false
    private var botTask: Task<Void, Never>?
    private var starter: Int
    private var cleanAtTurnStart = true

    private struct Undo {
        let hand: [CanastaCard]
        let melds: [CanastaMeld]
        let turnPoints: Int
        let turnMelded: Bool
    }
    private var undoState: Undo?

    static let botNames = ["Ana", "Mihai", "Ioana"]

    init(settings: CanastaSettings = CanastaSettings()) {
        self.settings = settings
        var list = [CanastaPlayer(id: 0, name: L("name.you"), isHuman: true)]
        for i in 1..<max(2, min(4, settings.players)) {
            list.append(CanastaPlayer(id: i, name: Self.botNames[i - 1], isHuman: false))
        }
        players = list
        starter = Int.random(in: 0..<list.count)
        scores = Array(repeating: 0, count: list.count == 4 ? 2 : list.count)
        startHand()
    }

    var n: Int { players.count }
    var teamCount: Int { n == 4 ? 2 : n }
    func team(of p: Int) -> Int { n == 4 ? p % 2 : p }
    func members(of t: Int) -> [Int] { players.indices.filter { team(of: $0) == t } }
    func hasCanasta(_ t: Int) -> Bool { melds[t].contains(where: \.isCanasta) }
    func minimum(_ t: Int) -> Int { CanastaRules.minimum(score: scores[t]) }
    /// Teancul e blocat pentru toți cât timp are în el un Joker, un doi sau un trei roșu.
    var pileFrozen: Bool { pile.contains { $0.isWild || $0.isRedThree } }
    var winnerTeam: Int { scores.indices.max { scores[$0] < scores[$1] } ?? 0 }

    // MARK: Flux

    private func startHand() {
        var d = CanastaRules.fullDeck().shuffled()
        let size = CanastaRules.handSize(players: n)
        for i in players.indices {
            players[i].hand = Array(d.suffix(size))
            d.removeLast(size)
        }
        stock = d
        pile = []
        melds = Array(repeating: [], count: teamCount)
        redThrees = Array(repeating: [], count: teamCount)
        opened = Array(repeating: false, count: teamCount)
        for k in 0..<n {
            let p = (starter + k) % n
            layRedThrees(p)
            players[p].hand = CanastaRules.sortHand(players[p].hand)
        }
        // prima carte a teancului: până apare una obișnuită
        while let c = stock.popLast() {
            pile.append(c)
            if !c.isWild && c.rank != 3 { break }
        }
        lastEvent = nil
        phase = .playing
        current = starter
        beginTurn()
        runBots()
    }

    private func beginTurn() {
        stage = .draw
        turnPoints = 0
        turnMelded = false
        undoState = nil
        cleanAtTurnStart = melds[team(of: current)].isEmpty
    }

    /// Treiarii roșii nu stau în mână: se pun pe masă și se trage altă carte în loc.
    private func layRedThrees(_ p: Int, replace: Bool = true) {
        let t = team(of: p)
        while let i = players[p].hand.firstIndex(where: \.isRedThree) {
            redThrees[t].append(players[p].hand.remove(at: i))
            if replace, let c = stock.popLast() { players[p].hand.append(c) }
        }
    }

    private func saveUndo() {
        let p = current
        undoState = Undo(hand: players[p].hand, melds: melds[team(of: p)], turnPoints: turnPoints, turnMelded: turnMelded)
    }

    var canUndo: Bool {
        guard phase == .playing, stage == .play, let u = undoState else { return false }
        return u.melds != melds[team(of: current)]
    }

    // MARK: Trasul și teancul

    @discardableResult
    private func drawCard(_ p: Int) -> Bool {
        guard phase == .playing, stage == .draw, p == current else { return false }
        let before = players[p].hand.count
        if let c = stock.popLast() { players[p].hand.append(c) }
        layRedThrees(p)
        guard players[p].hand.count > before else {
            // pachetul s-a terminat fără să mai primești o carte
            endHand(out: nil)
            return true
        }
        players[p].hand = CanastaRules.sortHand(players[p].hand)
        stage = .play
        lastEvent = L("k.event.drew", players[p].name)
        saveUndo()
        return true
    }

    /// Cu ce cărți din mână poți lua teancul acum (goală = cartea de sus merge direct la o etalare a ta).
    func takeOption(for p: Int) -> [CanastaCard]? {
        guard phase == .playing, stage == .draw, p == current, let top = pile.last, !top.isWild, top.rank != 3 else { return nil }
        let t = team(of: p)
        let hand = players[p].hand
        let nat = hand.filter { !$0.isWild && $0.rank == top.rank }
        let wilds = hand.filter(\.isWild).sorted { $0.points > $1.points }
        let existing = melds[t].first { $0.rank == top.rank }
        let blocked = pileFrozen || !opened[t]

        var use: [CanastaCard]
        if nat.count >= 2 {
            use = Array(nat.prefix(2))
        } else if !blocked, existing != nil {
            use = []
        } else if !blocked, nat.count == 1, let w = wilds.last {
            use = [nat[0], w]
        } else {
            return nil
        }
        if !opened[t] {
            // prima etalare: etalarea cu cartea de sus trebuie să atingă singură minimul
            let need = minimum(t)
            var value = top.points + use.reduce(0) { $0 + $1.points }
            for c in nat.dropFirst(2) where value < need {
                use.append(c)
                value += c.points
            }
            for w in wilds.prefix(CanastaRules.maxWilds) where value < need {
                use.append(w)
                value += w.points
            }
            guard value >= need else { return nil }
        }
        let total = (existing?.cards.count ?? 0) + 1 + use.count
        let usedWilds = (existing?.wilds ?? 0) + use.filter(\.isWild).count
        guard usedWilds <= CanastaRules.maxWilds else { return nil }
        let rest = pile.dropLast().filter { !$0.isRedThree }.count
        let after = hand.count - use.count + rest
        let canasta = hasCanasta(t) || total >= 7
        guard after >= 2 || canasta else { return nil }
        return use
    }

    @discardableResult
    private func takePile(_ p: Int) -> Bool {
        guard let use = takeOption(for: p), let top = pile.last else { return false }
        let t = team(of: p)
        let name = players[p].name
        let count = pile.count
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            players[p].hand.removeAll { use.contains($0) }
            add([top] + use, rank: top.rank, team: t)
            if !opened[t] {
                turnPoints += top.points + use.reduce(0) { $0 + $1.points }
            }
            turnMelded = true
            players[p].hand += pile.dropLast()
            pile = []
            layRedThrees(p, replace: false)
            players[p].hand = CanastaRules.sortHand(players[p].hand)
            stage = .play
            lastEvent = L("k.event.took", name, count)
        }
        saveUndo()
        if players[p].hand.isEmpty { endHand(out: p) }
        return true
    }

    // MARK: Etalări

    private func add(_ cards: [CanastaCard], rank: Int, team t: Int) {
        if let i = melds[t].firstIndex(where: { $0.rank == rank }) {
            melds[t][i].cards += cards
        } else {
            melds[t].append(CanastaMeld(rank: rank, cards: cards))
            melds[t].sort { $0.rank > $1.rank }
        }
    }

    /// Valoarea pe care s-ar etala cărțile astea, dacă se poate. `onto`: etalarea aleasă, pentru cărți care țin loc.
    func meldRank(for cards: [CanastaCard], onto: Int? = nil, by p: Int) -> Int? {
        guard phase == .playing, stage == .play, p == current, !cards.isEmpty else { return nil }
        let hand = players[p].hand
        guard Set(cards.map(\.id)).count == cards.count, cards.allSatisfy({ hand.contains($0) }) else { return nil }
        let t = team(of: p)
        let nat = cards.filter { !$0.isWild }
        let wild = cards.count - nat.count
        let rank: Int
        if let first = nat.first {
            guard nat.allSatisfy({ $0.rank == first.rank }) else { return nil }
            if let onto, onto != first.rank { return nil }
            rank = first.rank
        } else {
            guard let onto else { return nil }
            rank = onto
        }
        guard (4...14).contains(rank) else { return nil }
        let existing = melds[t].first { $0.rank == rank }
        if nat.isEmpty && existing == nil { return nil }
        let totalNat = (existing?.naturals ?? 0) + nat.count
        let totalWild = (existing?.wilds ?? 0) + wild
        let total = totalNat + totalWild
        guard totalNat >= 2, totalWild <= CanastaRules.maxWilds, total >= 3 else { return nil }
        let after = hand.count - cards.count
        let canasta = hasCanasta(t) || total >= 7
        // fără canastă trebuie să-ți rămână o carte de aruncat și una în mână
        if after <= 1 && !canasta { return nil }
        if after == 0 && !opened[t] {
            let value = cards.reduce(0) { $0 + $1.points }
            if turnPoints + value < minimum(t) { return nil }
        }
        return rank
    }

    @discardableResult
    private func meld(_ cards: [CanastaCard], onto: Int?, by p: Int) -> Bool {
        guard let rank = meldRank(for: cards, onto: onto, by: p) else { return false }
        let t = team(of: p)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            players[p].hand.removeAll { cards.contains($0) }
            add(cards, rank: rank, team: t)
            if !opened[t] { turnPoints += cards.reduce(0) { $0 + $1.points } }
            turnMelded = true
            lastEvent = L("k.event.melded", players[p].name, cards.map(\.label).joined(separator: " "))
        }
        if players[p].hand.isEmpty { endHand(out: p) }
        return true
    }

    /// Câte puncte îi mai lipsesc primei etalări din tura asta.
    func missingToOpen(_ t: Int) -> Int {
        guard !opened[t], turnMelded else { return 0 }
        return max(0, minimum(t) - turnPoints)
    }

    func canDiscard(_ c: CanastaCard, by p: Int) -> Bool {
        guard phase == .playing, stage == .play, p == current, players[p].hand.contains(c) else { return false }
        let t = team(of: p)
        if missingToOpen(t) > 0 { return false }
        if players[p].hand.count == 1 && !hasCanasta(t) { return false }
        return true
    }

    @discardableResult
    private func discard(_ c: CanastaCard, by p: Int) -> Bool {
        guard canDiscard(c, by: p) else { return false }
        let t = team(of: p)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            players[p].hand.removeAll { $0 == c }
            pile.append(c)
            if turnMelded { opened[t] = true }
            lastEvent = L("k.event.discarded", players[p].name, c.label)
        }
        if players[p].hand.isEmpty {
            endHand(out: p)
        } else if stock.isEmpty {
            endHand(out: nil)
        } else {
            current = (p + 1) % n
            beginTurn()
        }
        return true
    }

    // MARK: Omul

    func humanDraw() {
        guard current == human, drawCard(human) else { return }
        Haptics.tap()
    }

    func humanTake() {
        guard current == human, takePile(human) else { return }
        Haptics.success()
    }

    func humanMeld(_ cards: [CanastaCard], onto: Int? = nil) {
        guard current == human, meld(cards, onto: onto, by: human) else { return }
        Haptics.tap()
    }

    func humanDiscard(_ c: CanastaCard) {
        guard current == human, discard(c, by: human) else { return }
        Haptics.tap()
        runBots()
    }

    /// Iei înapoi în mână ce ai etalat în tura asta.
    func undo() {
        guard current == human, canUndo, let u = undoState else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            players[human].hand = u.hand
            melds[team(of: human)] = u.melds
            turnPoints = u.turnPoints
            turnMelded = u.turnMelded
        }
    }

    func nextHand() {
        guard phase == .handEnd else { return }
        round += 1
        starter = (starter + 1) % n
        startHand()
    }

    func stop() { botTask?.cancel() }

    // MARK: Sfârșitul rundei

    private func endHand(out: Int?) {
        var results: [CanastaTeamResult] = []
        for t in 0..<teamCount {
            var r = CanastaTeamResult()
            r.meldPoints = melds[t].reduce(0) { $0 + $1.cardPoints }
            r.canastaBonus = melds[t].reduce(0) { $0 + $1.bonus }
            let reds = redThrees[t].count
            let redValue = reds == 4 ? 800 : reds * 100
            r.redThrees = melds[t].isEmpty ? -redValue : redValue
            if let out, team(of: out) == t { r.outBonus = cleanAtTurnStart ? 200 : 100 }
            r.handPenalty = members(of: t).reduce(0) { sum, p in
                sum + players[p].hand.reduce(0) { $0 + $1.points }
            }
            results.append(r)
        }
        for t in 0..<teamCount { scores[t] += results[t].total }
        history.append(CanastaHandRecord(id: round, out: out, teams: results))
        lastEvent = out.map { L("k.event.out", players[$0].name) } ?? L("k.event.stockOut")
        if let out, team(of: out) == team(of: human), !frozen { Haptics.success() }
        let finished = scores.contains { $0 >= settings.target } || round + 1 >= CanastaRules.maxHands
        phase = finished ? .gameOver : .handEnd
    }

    // MARK: Pași (adversari, sfaturi, derulare rapidă)

    @discardableResult
    private func perform(_ step: CanastaStep, by p: Int) -> Bool {
        switch step {
        case .draw: return drawCard(p)
        case .takePile: return takePile(p)
        case .meld(let cards, let rank): return meld(cards, onto: rank, by: p)
        case .discard(let c): return discard(c, by: p)
        }
    }

    /// Plasă de siguranță: dacă un pas nu se poate face, tura tot se încheie.
    private func rescue(_ p: Int) {
        if stage == .draw {
            drawCard(p)
            return
        }
        if let u = undoState, missingToOpen(team(of: p)) > 0 {
            players[p].hand = u.hand
            melds[team(of: p)] = u.melds
            turnPoints = u.turnPoints
            turnMelded = u.turnMelded
        }
        if let c = players[p].hand.last(where: { canDiscard($0, by: p) }) {
            discard(c, by: p)
        } else {
            endHand(out: nil)
        }
    }

    private func act(_ p: Int) {
        let step = CanastaBot.next(for: p, engine: self, mistakes: true)
        if !perform(step, by: p) { rescue(p) }
    }

    @discardableResult
    func fastForward(maxSteps: Int = 200_000, until stop: (CanastaEngine) -> Bool) -> Bool {
        botTask?.cancel()
        frozen = true
        for _ in 0..<maxSteps {
            if stop(self) { return true }
            switch phase {
            case .playing: act(current)
            case .handEnd: nextHand()
            case .gameOver: return stop(self)
            }
        }
        return stop(self)
    }

    private func runBots() {
        botTask?.cancel()
        guard !frozen else { return }
        botTask = Task { [weak self] in await self?.botLoop() }
    }

    private func botLoop() async {
        while !Task.isCancelled {
            guard phase == .playing, current != human else { return }
            try? await Task.sleep(nanoseconds: UInt64(0.85 / max(settings.speed, 0.25) * 1_000_000_000))
            if Task.isCancelled { return }
            guard phase == .playing, current != human else { return }
            act(current)
        }
    }
}

// MARK: - Adversarii (văd masa, teancul și propria mână)

@MainActor
enum CanastaBot {
    static func next(for p: Int, engine e: CanastaEngine, mistakes: Bool) -> CanastaStep {
        let t = e.team(of: p)
        // nu greșește la mijlocul primei etalări
        let midOpening = e.missingToOpen(t) > 0
        let slip = mistakes && !midOpening && Double.random(in: 0..<1) < e.settings.difficulty.mistakeRate * 0.5
        if e.stage == .draw {
            return e.takeOption(for: p) != nil && !slip ? .takePile : .draw
        }
        if !slip, let m = bestMeld(for: p, engine: e) { return .meld(m.cards, rank: m.rank) }
        return .discard(chooseDiscard(for: p, engine: e, careless: slip))
    }

    static func bestMeld(for p: Int, engine e: CanastaEngine) -> (cards: [CanastaCard], rank: Int)? {
        let t = e.team(of: p)
        let hand = e.players[p].hand
        let wilds = hand.filter(\.isWild).sorted { $0.points > $1.points }
        let groups = Dictionary(grouping: hand.filter { !$0.isWild && $0.rank >= 4 }, by: \.rank)
            .sorted { $0.key > $1.key }
        func exists(_ r: Int) -> Bool { e.melds[t].contains { $0.rank == r } }
        func ok(_ cards: [CanastaCard], _ r: Int) -> Bool { e.meldRank(for: cards, onto: r, by: p) != nil }
        func value(_ cards: [CanastaCard]) -> Int { cards.reduce(0) { $0 + $1.points } }

        let need = e.minimum(t)
        if !e.opened[t] && e.turnPoints < need {
            // prima etalare: un plan întreg care atinge minimul, altfel nimic
            var plan: [(cards: [CanastaCard], rank: Int)] = []
            var total = e.turnPoints
            for (r, cs) in groups where cs.count >= 3 || exists(r) {
                plan.append((cs, r))
                total += value(cs)
            }
            var free = wilds
            while total < need, let w = free.first,
                  let k = plan.indices.first(where: { i in
                      plan[i].cards.filter(\.isWild).count + (e.melds[t].first { $0.rank == plan[i].rank }?.wilds ?? 0) < CanastaRules.maxWilds
                  }) {
                free.removeFirst()
                plan[k].cards.append(w)
                total += w.points
            }
            for (r, cs) in groups where cs.count == 2 && !exists(r) {
                guard total < need, let w = free.first else { break }
                free.removeFirst()
                plan.append((cs + [w], r))
                total += value(cs) + w.points
            }
            let used = plan.reduce(0) { $0 + $1.cards.count }
            guard total >= need, hand.count - used >= 2 else { return nil }
            return plan.first { ok($0.cards, $0.rank) }
        }

        // 1. cărți la etalările echipei și etalări noi din cel puțin trei cărți
        for (r, cs) in groups where exists(r) || cs.count >= 3 {
            if ok(cs, r) { return (cs, r) }
            let fewer = Array(cs.dropLast())
            if !fewer.isEmpty, exists(r) || fewer.count >= 3, ok(fewer, r) { return (fewer, r) }
        }
        // 2. Jokeri și doiari care închid o canastă
        for m in e.melds[t] where !m.isCanasta && m.cards.count >= 5 {
            let missing = 7 - m.cards.count
            if missing <= CanastaRules.maxWilds - m.wilds, wilds.count >= missing {
                let ws = Array(wilds.suffix(missing))
                if ok(ws, m.rank) { return (ws, m.rank) }
            }
        }
        // 3. o pereche plus o carte care ține loc, spre sfârșitul pachetului sau când am destule
        if e.stock.count < 30 || wilds.count >= 2 {
            for (r, cs) in groups where cs.count == 2 && !exists(r) {
                if let w = wilds.last, ok(cs + [w], r) { return (cs + [w], r) }
            }
        }
        return nil
    }

    static func chooseDiscard(for p: Int, engine e: CanastaEngine, careless: Bool) -> CanastaCard {
        let hand = e.players[p].hand
        let options = hand.filter { e.canDiscard($0, by: p) }
        guard let fallback = options.last ?? hand.last else {
            return CanastaCard(id: -1, suit: .spades, rank: 4)
        }
        if careless, let c = options.filter({ !$0.isWild }).randomElement() { return c }
        let t = e.team(of: p)
        let nt = e.team(of: (p + 1) % e.n)
        func cost(_ c: CanastaCard) -> Int {
            if c.isWild { return 200 + c.points }
            if c.isBlackThree { return -40 }
            var s = hand.filter { !$0.isWild && $0.rank == c.rank }.count * 25
            if e.melds[t].contains(where: { $0.rank == c.rank }) { s += 80 }
            // următorul adversar ar putea lua teancul cu ea
            if nt != t, e.opened[nt], !e.pileFrozen, e.melds[nt].contains(where: { $0.rank == c.rank }) {
                s += 60 + e.pile.count * 4
            }
            return s + c.points / 5
        }
        return options.min { (cost($0), $0.id) < (cost($1), $1.id) } ?? fallback
    }
}
