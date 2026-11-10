import Foundation
import SwiftUI

/// Castelul — jocul românesc de curte (turnul de pietre dărâmat cu mingea), adaptat la cărți.
///
/// Fiecare jucător își ridică un castel de 7 niveluri: As, 2, 3, 4, 5, 6, 7, în ordine, de orice culoare.
/// 8, 9 și 10 sunt „mingi”: dărâmă nivelul de sus al unui adversar, dacă au aceeași culoare (roșu/negru).
/// Valetul din mână blochează automat o minge. Dama ține loc de orice nivel. Popa pune scut până la tura ta următoare.
/// La fiecare tură: tragi o carte, apoi joci sau arunci una. Câștigă runda cine termină primul castelul.
enum CastelRules {
    static let levels = 7
    static let targetScore = 25
    static let winBonus = 5

    /// Valoarea cărții în joc: Asul e 1.
    static func value(_ c: Card) -> Int { c.rank == 14 ? 1 : c.rank }
    static func isBall(_ c: Card) -> Bool { (8...10).contains(c.rank) }
    static func isJack(_ c: Card) -> Bool { c.rank == 11 }
    static func isQueen(_ c: Card) -> Bool { c.rank == 12 }
    static func isKing(_ c: Card) -> Bool { c.rank == 13 }
    static func sameColor(_ a: Card, _ b: Card) -> Bool { a.suit.isRed == b.suit.isRed }

    static func fullDeck() -> [Card] {
        Suit.allCases.flatMap { s in (2...14).map { Card(suit: s, rank: $0) } }
    }
}

enum CastelAction: Hashable {
    case build(Card)
    case attack(Card, target: Int)
    case shield(Card)
    case discard(Card)

    var card: Card {
        switch self {
        case .build(let c), .attack(let c, _), .shield(let c), .discard(let c): return c
        }
    }
}

enum CastelDifficulty: Int, CaseIterable, Identifiable {
    case easy, medium, hard
    var id: Int { rawValue }
    /// Cât de des face un adversar o mutare la întâmplare.
    var mistakeRate: Double { [0.45, 0.15, 0.0][rawValue] }
    var title: String { L(["c.diff.easy", "c.diff.medium", "c.diff.hard"][rawValue]) }
}

struct CastelPlayer: Identifiable {
    let id: Int
    var name: String
    var isHuman: Bool
    var hand: [Card] = []
    var castle: [Card] = []
    var shielded = false
    var score = 0
    var roundsWon = 0
}

struct CastelRoundRecord: Identifiable {
    let id: Int
    let winner: Int
    let levels: [Int]
    let points: [Int]
}

@MainActor
final class CastelEngine: ObservableObject {
    enum Phase: Equatable { case playing, roundEnd, gameOver }

    @Published private(set) var players: [CastelPlayer]
    @Published private(set) var phase: Phase = .playing
    @Published private(set) var current = 0
    @Published private(set) var deck: [Card] = []
    @Published private(set) var discardPile: [Card] = []
    @Published private(set) var round = 0
    @Published private(set) var turnCount = 0
    @Published private(set) var lastEvent: String? = nil
    /// Ultima minge aruncată (pentru animație): cine, spre cine, blocată sau nu.
    @Published private(set) var lastAttack: (from: Int, to: Int, blocked: Bool)? = nil
    @Published private(set) var history: [CastelRoundRecord] = []

    let human = 0
    let difficulty: CastelDifficulty
    let speed: Double
    var frozen = false
    private var botTask: Task<Void, Never>?
    private var starter: Int

    static let botNames = ["Ana", "Mihai", "Ioana"]

    init(players count: Int, difficulty: CastelDifficulty = .medium, speed: Double = 1) {
        self.difficulty = difficulty
        self.speed = speed
        var list = [CastelPlayer(id: 0, name: L("name.you"), isHuman: true)]
        for i in 1..<max(2, min(4, count)) { list.append(CastelPlayer(id: i, name: Self.botNames[i - 1], isHuman: false)) }
        players = list
        starter = Int.random(in: 0..<list.count)
        startRound()
    }

    var n: Int { players.count }
    var topDiscard: Card? { discardPile.last }

    func needed(for p: Int) -> Int { players[p].castle.count + 1 }

    // MARK: Mutări permise

    func legalActions(for p: Int) -> [CastelAction] {
        guard phase == .playing, p == current else { return [] }
        let me = players[p]
        var out: [CastelAction] = []
        for c in me.hand {
            if (CastelRules.value(c) == needed(for: p) && CastelRules.value(c) <= 7) || (CastelRules.isQueen(c) && me.castle.count < CastelRules.levels) {
                out.append(.build(c))
            }
            if CastelRules.isBall(c) {
                for t in players where t.id != p && canAttack(t.id, with: c) {
                    out.append(.attack(c, target: t.id))
                }
            }
            if CastelRules.isKing(c) && !me.shielded { out.append(.shield(c)) }
            out.append(.discard(c))
        }
        return out
    }

    func canAttack(_ target: Int, with ball: Card) -> Bool {
        let t = players[target]
        guard let top = t.castle.last, !t.shielded else { return false }
        return CastelRules.sameColor(top, ball)
    }

    // MARK: Flux

    private func startRound() {
        var d = CastelRules.fullDeck().shuffled()
        for i in players.indices {
            players[i].hand = Array(d.prefix(5))
            d.removeFirst(5)
            players[i].castle = []
            players[i].shielded = false
        }
        deck = d
        discardPile = []
        turnCount = 0
        lastAttack = nil
        lastEvent = nil
        phase = .playing
        current = starter
        beginTurn()
        runBots()
    }

    private func beginTurn() {
        players[current].shielded = false
        drawCard(for: current)
        turnCount += 1
    }

    private func drawCard(for p: Int) {
        if deck.isEmpty {
            guard discardPile.count > 1 else { return }
            let keep = discardPile.removeLast()
            deck = discardPile.shuffled()
            discardPile = [keep]
            lastEvent = L("c.event.reshuffle")
        }
        if let c = deck.popLast() {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                players[p].hand.append(c)
                players[p].hand = Self.sortHand(players[p].hand)
            }
        }
    }

    static func sortHand(_ h: [Card]) -> [Card] {
        h.sorted { (CastelRules.value($0), $0.suit.rawValue) < (CastelRules.value($1), $1.suit.rawValue) }
    }

    func humanAct(_ a: CastelAction) {
        guard phase == .playing, current == human, legalActions(for: human).contains(a) else { return }
        Haptics.tap()
        apply(a, by: human)
        runBots()
    }

    func nextRound() {
        guard phase == .roundEnd else { return }
        round += 1
        starter = (starter + 1) % n
        startRound()
    }

    func stop() { botTask?.cancel() }

    private func apply(_ a: CastelAction, by p: Int) {
        guard phase == .playing, p == current, players[p].hand.contains(a.card) else { return }
        let name = players[p].name
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            players[p].hand.removeAll { $0 == a.card }
            lastAttack = nil
            switch a {
            case .build(let c):
                players[p].castle.append(c)
                lastEvent = L("c.event.build", name, players[p].castle.count)
            case .attack(let c, let t):
                let target = players[t].name
                if let j = players[t].hand.first(where: CastelRules.isJack) {
                    players[t].hand.removeAll { $0 == j }
                    discardPile.append(j)
                    lastEvent = L("c.event.blocked", target, name)
                    lastAttack = (p, t, true)
                    drawCard(for: t)   // cine a blocat își completează mâna
                } else if let fallen = players[t].castle.popLast() {
                    discardPile.append(fallen)
                    lastEvent = L("c.event.hit", name, target, players[t].castle.count)
                    lastAttack = (p, t, false)
                }
                discardPile.append(c)
            case .shield(let c):
                players[p].shielded = true
                discardPile.append(c)
                lastEvent = L("c.event.shield", name)
            case .discard(let c):
                discardPile.append(c)
                lastEvent = L("c.event.discard", name)
            }
        }
        if case .attack(_, let t) = a, t == human, lastAttack?.blocked == false { Haptics.warning() }

        if players[p].castle.count >= CastelRules.levels {
            endRound(winner: p)
            return
        }
        // siguranță: o rundă nu poate dura la nesfârșit
        if turnCount > 400 {
            let w = players.max { $0.castle.count < $1.castle.count }?.id ?? p
            endRound(winner: w)
            return
        }
        current = (p + 1) % n
        beginTurn()
    }

    private func endRound(winner w: Int) {
        var pts: [Int] = []
        for i in players.indices {
            let gained = players[i].castle.count + (i == w ? CastelRules.winBonus : 0)
            players[i].score += gained
            pts.append(gained)
        }
        players[w].roundsWon += 1
        history.append(CastelRoundRecord(id: round, winner: w, levels: players.map(\.castle.count), points: pts))
        lastEvent = L("c.event.roundWon", players[w].name)
        if w == human { Haptics.success() }
        phase = players.contains { $0.score >= CastelRules.targetScore } ? .gameOver : .roundEnd
    }

    // MARK: Derulare rapidă (capturi + test de anduranță)

    @discardableResult
    func fastForward(maxSteps: Int = 20000, until stop: (CastelEngine) -> Bool) -> Bool {
        botTask?.cancel()
        frozen = true
        for _ in 0..<maxSteps {
            if stop(self) { return true }
            switch phase {
            case .playing:
                guard let a = CastelBot.choose(for: current, engine: self, mistakes: true) else { return stop(self) }
                apply(a, by: current)
            case .roundEnd: nextRound()
            case .gameOver: return stop(self)
            }
        }
        return stop(self)
    }

    // MARK: Adversarii

    private func runBots() {
        botTask?.cancel()
        guard !frozen else { return }
        botTask = Task { [weak self] in await self?.botLoop() }
    }

    private func botLoop() async {
        while !Task.isCancelled {
            guard phase == .playing, current != human else { return }
            try? await Task.sleep(nanoseconds: UInt64(0.9 / max(speed, 0.25) * 1_000_000_000))
            if Task.isCancelled { return }
            let p = current
            guard phase == .playing, p != human, let a = CastelBot.choose(for: p, engine: self, mistakes: true) else { return }
            apply(a, by: p)
        }
    }
}

// MARK: - Adversarii (văd doar ce e pe masă și propria mână)

@MainActor
enum CastelBot {
    static func choose(for p: Int, engine e: CastelEngine, mistakes: Bool) -> CastelAction? {
        let legal = e.legalActions(for: p)
        guard !legal.isEmpty else { return nil }
        if mistakes, Double.random(in: 0..<1) < e.difficulty.mistakeRate {
            return legal.filter { if case .discard = $0 { return false }; return true }.randomElement() ?? legal.randomElement()
        }
        let me = e.players[p]
        let opponents = e.players.filter { $0.id != p }
        let leader = opponents.max { $0.castle.count < $1.castle.count }

        // 1. construiesc cu cartea exactă
        if let a = legal.first(where: { if case .build(let c) = $0 { return !CastelRules.isQueen(c) }; return false }) { return a }
        // 2. dărâm adversarul periculos (aproape gata sau mult înaintea mea)
        let attacks = legal.compactMap { a -> (CastelAction, Int)? in
            if case .attack(_, let t) = a { return (a, e.players[t].castle.count) }; return nil
        }
        if let best = attacks.max(by: { $0.1 < $1.1 }),
           best.1 >= 5 || best.1 >= me.castle.count + 2 { return best.0 }
        // 3. Dama ca nivel
        if let a = legal.first(where: { if case .build = $0 { return true }; return false }) { return a }
        // 4. scut când am castelul sus și cineva mă poate lovi
        if me.castle.count >= 4, let a = legal.first(where: { if case .shield = $0 { return true }; return false }) { return a }
        // 5. orice atac asupra liderului
        if let l = leader, let a = attacks.first(where: { if case .attack(_, let t) = $0.0 { return t == l.id }; return false }) {
            return a.0
        }
        // 6. arunc cartea cea mai puțin utilă
        let need = e.needed(for: p)
        func keep(_ c: Card) -> Int {
            if CastelRules.isJack(c) { return 100 }
            if CastelRules.isQueen(c) { return 90 }
            if CastelRules.isKing(c) { return me.castle.count >= 3 ? 60 : 35 }
            if CastelRules.isBall(c) {
                let usable = opponents.contains { o in o.castle.last.map { CastelRules.sameColor($0, c) } ?? false }
                return usable ? 55 : 30
            }
            let v = CastelRules.value(c)
            if v < need { return 8 + v }           // l-am pus deja; poate trebuie refăcut după o minge
            return 70 - (v - need) * 8               // cu cât e mai aproape, cu atât îl păstrez
        }
        let discards = legal.compactMap { a -> CastelAction? in if case .discard = a { return a }; return nil }
        return discards.min { keep($0.card) < keep($1.card) } ?? legal.first
    }
}
