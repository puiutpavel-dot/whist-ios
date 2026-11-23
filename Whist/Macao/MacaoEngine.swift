import Foundation
import SwiftUI

/// Macao — jocul în care scapi primul de cărți.
///
/// 54 de cărți (cu cei doi Jokeri), câte 5 în mână. Pui o carte de aceeași culoare sau de aceeași valoare
/// cu cea de pe masă; poți pune mai multe cărți de aceeași valoare deodată.
/// 2 și 3: următorul trage 2 / 3 cărți. Joker: 5 (negru) sau 10 (roșu). Pedepsele se adună.
/// Una dintre cărți schimbă culoarea, una îl ține pe următorul o tură pe loc și una oprește tragerea
/// (care anume — depinde de varianta aleasă). Cu o singură carte în mână spui „Macao!”.
enum MacaoVariant: Int, CaseIterable, Identifiable {
    /// Asul schimbă culoarea, 4 = stai o tură, 7 oprește tragerea.
    case aceChanges
    /// 7 schimbă culoarea, Asul = stai o tură, 4 oprește tragerea.
    case sevenChanges

    var id: Int { rawValue }
    var changer: Int { self == .aceChanges ? 14 : 7 }
    var skipper: Int { self == .aceChanges ? 4 : 14 }
    var stopper: Int { self == .aceChanges ? 7 : 4 }

    var title: String { L(self == .aceChanges ? "m.variant.ace" : "m.variant.seven") }

    static func rankName(_ rank: Int) -> String { Card(suit: .spades, rank: rank).rankLabel }
}

enum MacaoRules {
    static let jokerRank = 15
    static let handSize = 5
    static let forgetPenalty = 5
    static let deckSize = 54

    static func isJoker(_ c: Card) -> Bool { c.rank == jokerRank }
    /// Jokerul roșu e ținut pe „inimă roșie”, cel negru pe „pică”.
    static func isRedJoker(_ c: Card) -> Bool { isJoker(c) && c.suit == .hearts }

    /// Câte cărți trage următorul jucător.
    static func drawValue(_ c: Card) -> Int {
        if isJoker(c) { return isRedJoker(c) ? 10 : 5 }
        return c.rank == 2 || c.rank == 3 ? c.rank : 0
    }

    static func fullDeck() -> [Card] {
        var d = Suit.allCases.flatMap { s in (2...14).map { Card(suit: s, rank: $0) } }
        d.append(Card(suit: .spades, rank: jokerRank))
        d.append(Card(suit: .hearts, rank: jokerRank))
        return d
    }

    static func label(_ c: Card) -> String {
        isJoker(c) ? L(isRedJoker(c) ? "m.joker.red" : "m.joker.black") : c.label
    }
}

enum MacaoMove: Equatable {
    /// Cărțile, în ordinea în care se pun (ultima rămâne deasupra); culoarea cerută, dacă ultima schimbă culoarea.
    case play([Card], suit: Suit?)
    /// Tragi o carte, tragi pedeapsa sau stai o tură — după ce e pe masă.
    case draw
}

enum MacaoDifficulty: Int, CaseIterable, Identifiable {
    case easy, medium, hard
    var id: Int { rawValue }
    var mistakeRate: Double { [0.4, 0.12, 0.0][rawValue] }
    /// Cât de des uită un adversar să spună „Macao”.
    var forgetRate: Double { [0.2, 0.06, 0.0][rawValue] }
    var title: String { L(["c.diff.easy", "c.diff.medium", "c.diff.hard"][rawValue]) }
}

struct MacaoSettings {
    var players = 3
    var variant: MacaoVariant = .aceChanges
    var targetWins = 3
    /// Trebuie să apeși „Macao!” când rămâi cu o carte.
    var announce = true
    var difficulty: MacaoDifficulty = .medium
    var speed = 1.0
}

struct MacaoPlayer: Identifiable {
    let id: Int
    var name: String
    var isHuman: Bool
    var hand: [Card] = []
    /// Câte ture mai stă pe loc.
    var waits = 0
    var saidMacao = false
    var roundsWon = 0
}

struct MacaoRoundRecord: Identifiable {
    let id: Int
    let winner: Int
    let cardsLeft: [Int]
}

@MainActor
final class MacaoEngine: ObservableObject {
    enum Phase: Equatable { case playing, roundEnd, gameOver }

    @Published private(set) var players: [MacaoPlayer]
    @Published private(set) var phase: Phase = .playing
    @Published private(set) var current = 0
    @Published private(set) var deck: [Card] = []
    @Published private(set) var discardPile: [Card] = []
    /// Culoarea cerută. `nil` după un Joker: merge orice carte.
    @Published private(set) var activeSuit: Suit? = nil
    @Published private(set) var pendingDraw = 0
    @Published private(set) var pendingSkip = 0
    @Published private(set) var round = 0
    @Published private(set) var turnCount = 0
    @Published private(set) var lastEvent: String? = nil
    @Published private(set) var history: [MacaoRoundRecord] = []
    /// Ai rămas cu o carte și încă n-ai spus „Macao”.
    @Published private(set) var awaitingMacao = false
    @Published private(set) var macaoDeadline = Date.distantPast

    let human = 0
    let settings: MacaoSettings
    var frozen = false
    private var botTask: Task<Void, Never>?
    private var starter: Int

    static let botNames = ["Ana", "Mihai", "Ioana"]
    /// Cât timp ai ca să spui „Macao”.
    static let macaoWindow: TimeInterval = 3.5

    init(settings: MacaoSettings = MacaoSettings()) {
        self.settings = settings
        var list = [MacaoPlayer(id: 0, name: L("name.you"), isHuman: true)]
        for i in 1..<max(2, min(4, settings.players)) {
            list.append(MacaoPlayer(id: i, name: Self.botNames[i - 1], isHuman: false))
        }
        players = list
        starter = Int.random(in: 0..<list.count)
        startRound()
    }

    var n: Int { players.count }
    var variant: MacaoVariant { settings.variant }
    var topCard: Card? { discardPile.last }
    var nextPlayer: Int { (current + 1) % n }

    // MARK: Reguli

    func isChanger(_ c: Card) -> Bool { c.rank == variant.changer }
    func isSkipper(_ c: Card) -> Bool { c.rank == variant.skipper }
    func isStopper(_ c: Card) -> Bool { c.rank == variant.stopper }

    private func matchesTop(_ c: Card) -> Bool {
        guard let top = topCard else { return true }
        if MacaoRules.isJoker(top) && activeSuit == nil { return true }
        return c.rank == top.rank || c.suit == activeSuit
    }

    /// Poate fi pusă cartea asta prima, acum?
    func canPlay(_ c: Card) -> Bool {
        guard phase == .playing else { return false }
        if pendingDraw > 0 {
            if MacaoRules.isJoker(c) || isStopper(c) { return true }
            return MacaoRules.drawValue(c) > 0 && matchesTop(c)
        }
        if pendingSkip > 0 { return isSkipper(c) }
        if MacaoRules.isJoker(c) || isChanger(c) { return true }
        return matchesTop(c)
    }

    /// Mai multe cărți deodată: toate de aceeași valoare, iar prima se potrivește cu masa.
    func isLegal(_ cards: [Card], for p: Int) -> Bool {
        guard phase == .playing, p == current, let first = cards.first, canPlay(first) else { return false }
        guard Set(cards).count == cards.count else { return false }
        return cards.allSatisfy { $0.rank == first.rank && players[p].hand.contains($0) }
    }

    func needsSuit(_ cards: [Card]) -> Bool { cards.last.map(isChanger) ?? false }

    func playable(for p: Int) -> [Card] {
        guard phase == .playing, p == current else { return [] }
        return players[p].hand.filter(canPlay)
    }

    // MARK: Flux

    private func startRound() {
        var d = MacaoRules.fullDeck().shuffled()
        for i in players.indices {
            players[i].hand = Self.sortHand(Array(d.suffix(MacaoRules.handSize)))
            d.removeLast(MacaoRules.handSize)
            players[i].waits = 0
            players[i].saidMacao = false
        }
        // prima carte de pe masă e una simplă, fără efect
        let plain = d.lastIndex { c in
            !MacaoRules.isJoker(c) && MacaoRules.drawValue(c) == 0 && !isChanger(c) && !isSkipper(c) && !isStopper(c)
        } ?? d.count - 1
        let first = d.remove(at: plain)
        deck = d
        discardPile = [first]
        activeSuit = first.suit
        pendingDraw = 0
        pendingSkip = 0
        turnCount = 0
        awaitingMacao = false
        lastEvent = nil
        phase = .playing
        current = starter
        runBots()
    }

    static func sortHand(_ h: [Card]) -> [Card] {
        h.sorted { ($0.suit.rawValue, $0.rank) < ($1.suit.rawValue, $1.rank) }
    }

    private func draw(_ p: Int, _ count: Int) {
        guard count > 0 else { return }
        var got: [Card] = []
        for _ in 0..<count {
            if deck.isEmpty {
                guard discardPile.count > 1 else { break }
                let keep = discardPile.removeLast()
                deck = discardPile.shuffled()
                discardPile = [keep]
            }
            if let c = deck.popLast() { got.append(c) }
        }
        guard !got.isEmpty else { return }
        players[p].hand = Self.sortHand(players[p].hand + got)
        players[p].saidMacao = false
    }

    func humanPlay(_ cards: [Card], suit: Suit? = nil) {
        guard current == human, isLegal(cards, for: human) else { return }
        if needsSuit(cards) && suit == nil { return }
        Haptics.tap()
        apply(.play(cards, suit: suit), by: human)
        runBots()
    }

    func humanDraw() {
        guard phase == .playing, current == human else { return }
        Haptics.tap()
        apply(.draw, by: human)
        runBots()
    }

    func sayMacao() {
        guard awaitingMacao else { return }
        awaitingMacao = false
        players[human].saidMacao = true
        lastEvent = L("m.event.macao", players[human].name)
        Haptics.success()
    }

    func nextRound() {
        guard phase == .roundEnd else { return }
        round += 1
        starter = (starter + 1) % n
        startRound()
    }

    func stop() { botTask?.cancel() }

    private func apply(_ m: MacaoMove, by p: Int) {
        guard phase == .playing, p == current else { return }
        let name = players[p].name
        // Ai apucat să joci din nou fără să fi spus „Macao”: fereastra se închide, fără pedeapsă.
        if p == human && awaitingMacao { awaitingMacao = false }

        switch m {
        case .draw:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if pendingDraw > 0 {
                    let k = pendingDraw
                    pendingDraw = 0
                    draw(p, k)
                    lastEvent = L("m.event.drewN", name, k)
                } else if pendingSkip > 0 {
                    players[p].waits = pendingSkip - 1
                    pendingSkip = 0
                    lastEvent = L("m.event.waits", name)
                } else {
                    draw(p, 1)
                    lastEvent = L("m.event.drew", name)
                }
            }
            if p == human { Haptics.warning() }

        case .play(let cards, let suit):
            guard isLegal(cards, for: p), let last = cards.last else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                for c in cards {
                    players[p].hand.removeAll { $0 == c }
                    discardPile.append(c)
                    pendingDraw += MacaoRules.drawValue(c)
                    if isSkipper(c) { pendingSkip += 1 }
                    if isStopper(c) { pendingDraw = 0 }
                }
                if MacaoRules.isJoker(last) {
                    activeSuit = nil
                } else if isChanger(last) {
                    activeSuit = suit ?? last.suit
                } else {
                    activeSuit = last.suit
                }
                let list = cards.map(MacaoRules.label).joined(separator: " ")
                if isChanger(last), let s = activeSuit {
                    lastEvent = L("m.event.playedSuit", name, list, s.symbol)
                } else {
                    lastEvent = L("m.event.played", name, list)
                }
            }
            if players[p].hand.isEmpty {
                endRound(winner: p)
                return
            }
            if players[p].hand.count == 1 { announceMacao(p) }
        }

        turnCount += 1
        // siguranță: o rundă nu poate dura la nesfârșit
        if turnCount > 3000 {
            let w = players.min { $0.hand.count < $1.hand.count }?.id ?? p
            endRound(winner: w)
            return
        }
        advance(from: p)
    }

    /// A rămas cu o carte: adversarii anunță singuri (și mai uită), tu ai câteva secunde să apeși butonul.
    private func announceMacao(_ p: Int) {
        let name = players[p].name
        if p == human && settings.announce && !frozen {
            awaitingMacao = true
            macaoDeadline = Date().addingTimeInterval(Self.macaoWindow)
            return
        }
        if p != human && Double.random(in: 0..<1) < settings.difficulty.forgetRate {
            draw(p, MacaoRules.forgetPenalty)
            lastEvent = L("m.event.forgot", name, MacaoRules.forgetPenalty)
            return
        }
        players[p].saidMacao = true
        lastEvent = (lastEvent.map { $0 + " · " } ?? "") + L("m.event.macao", name)
    }

    private func forgotMacao() {
        guard awaitingMacao else { return }
        awaitingMacao = false
        guard phase == .playing, players[human].hand.count == 1 else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            draw(human, MacaoRules.forgetPenalty)
            lastEvent = L("m.event.forgot", players[human].name, MacaoRules.forgetPenalty)
        }
        Haptics.warning()
    }

    private func advance(from p: Int) {
        current = (p + 1) % n
        var hops = 0
        // Cine stă pe loc nu se poate apăra: ia ce e pe masă și pierde tura.
        while players[current].waits > 0 && hops < 8 * n {
            if pendingDraw > 0 {
                draw(current, pendingDraw)
                pendingDraw = 0
            }
            if pendingSkip > 0 {
                players[current].waits += pendingSkip
                pendingSkip = 0
            }
            players[current].waits -= 1
            current = (current + 1) % n
            hops += 1
        }
    }

    private func endRound(winner w: Int) {
        awaitingMacao = false
        pendingDraw = 0
        pendingSkip = 0
        players[w].roundsWon += 1
        history.append(MacaoRoundRecord(id: round, winner: w, cardsLeft: players.map(\.hand.count)))
        lastEvent = L("m.event.roundWon", players[w].name)
        if w == human && !frozen { Haptics.success() }
        phase = players[w].roundsWon >= settings.targetWins ? .gameOver : .roundEnd
    }

    // MARK: Derulare rapidă (capturi + test de anduranță)

    @discardableResult
    func fastForward(maxSteps: Int = 20000, until stop: (MacaoEngine) -> Bool) -> Bool {
        botTask?.cancel()
        frozen = true
        for _ in 0..<maxSteps {
            if stop(self) { return true }
            switch phase {
            case .playing: apply(MacaoBot.choose(for: current, engine: self, mistakes: true), by: current)
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
            // adversarii te așteaptă să spui „Macao”
            while awaitingMacao && Date() < macaoDeadline {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if Task.isCancelled { return }
            }
            if awaitingMacao { forgotMacao() }
            guard phase == .playing, current != human else { return }
            try? await Task.sleep(nanoseconds: UInt64(1.0 / max(settings.speed, 0.25) * 1_000_000_000))
            if Task.isCancelled { return }
            let p = current
            guard phase == .playing, p != human else { return }
            apply(MacaoBot.choose(for: p, engine: self, mistakes: true), by: p)
        }
    }
}

// MARK: - Adversarii (văd doar masa, propria mână și câte cărți au ceilalți)

@MainActor
enum MacaoBot {
    static func choose(for p: Int, engine e: MacaoEngine, mistakes: Bool) -> MacaoMove {
        let hand = e.players[p].hand
        let legal = hand.filter(e.canPlay)
        guard !legal.isEmpty else { return .draw }

        if mistakes, Double.random(in: 0..<1) < e.settings.difficulty.mistakeRate, let c = legal.randomElement() {
            return .play([c], suit: e.isChanger(c) ? bestSuit(in: hand.filter { $0 != c }, fallback: c.suit) : nil)
        }

        let nextCount = e.players[(p + 1) % e.n].hand.count
        let danger = nextCount <= 2

        var best: (cards: [Card], score: Int)? = nil
        for first in legal {
            let same = hand.filter { $0.rank == first.rank && $0 != first }
            // Jokerii și cărțile care schimbă culoarea se joacă pe rând; restul, toate deodată.
            let single = MacaoRules.isJoker(first) || e.isChanger(first)
            var group = [first]
            if !single {
                let rest = hand.filter { !same.contains($0) && $0 != first }
                let want = bestSuit(in: rest, fallback: first.suit)
                // cartea care rămâne deasupra e cea de culoarea de care am cele mai multe
                group += same.filter { $0.suit != want } + same.filter { $0.suit == want }
            }
            let left = hand.count - group.count
            var score: Int
            if left == 0 {
                score = 1000
            } else if MacaoRules.isJoker(first) {
                score = e.pendingDraw > 0 ? 70 : (danger ? 75 : 10)
            } else if e.isChanger(first) {
                score = 15
            } else if MacaoRules.drawValue(first) > 0 {
                score = (danger ? 80 : 42) + group.count * 6
            } else if e.isSkipper(first) {
                score = (danger ? 70 : 46) + group.count * 4
            } else if e.isStopper(first) && e.pendingDraw > 0 {
                score = 60
            } else {
                let lastSuit = group.last?.suit ?? first.suit
                let follow = hand.filter { !group.contains($0) && $0.suit == lastSuit }.count
                score = 50 + group.count * 10 + follow * 3
            }
            if best == nil || score > best!.score { best = (group, score) }
        }
        guard let pick = best, let last = pick.cards.last else { return .draw }
        let suit: Suit? = e.isChanger(last) ? bestSuit(in: hand.filter { !pick.cards.contains($0) }, fallback: last.suit) : nil
        return .play(pick.cards, suit: suit)
    }

    /// Culoarea din care am cele mai multe cărți (fără Jokeri).
    static func bestSuit(in cards: [Card], fallback: Suit) -> Suit {
        var counts: [Suit: Int] = [:]
        for c in cards where !MacaoRules.isJoker(c) { counts[c.suit, default: 0] += 1 }
        return counts.max { ($0.value, -$0.key.rawValue) < ($1.value, -$1.key.rawValue) }?.key ?? fallback
    }
}
