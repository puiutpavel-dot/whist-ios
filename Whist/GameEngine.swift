import Foundation
import SwiftUI
import UIKit

@MainActor
final class GameEngine: ObservableObject {
    enum Phase { case bidding, playing, trickEnd, handEnd, gameOver }

    @Published private(set) var players: [Player]
    @Published private(set) var phase: Phase = .bidding
    @Published private(set) var handIndex = 0
    @Published private(set) var dealer: Int
    @Published private(set) var current = 0
    @Published private(set) var trump: Card? = nil
    @Published private(set) var trick: [PlayedCard] = []
    @Published private(set) var trickWinner: Int? = nil
    @Published private(set) var history: [HandRecord] = []
    @Published private(set) var toast: String? = nil

    let settings: GameSettings
    let handSizes: [Int]
    let human = 0
    private var botTask: Task<Void, Never>?

    static let botNames = ["Ana", "Mihai", "Ioana", "Radu", "Elena"]

    /// Folosit doar pentru capturile din App Store: adversarii stau pe loc.
    var frozen = false

    init(settings: GameSettings) {
        self.settings = settings
        self.handSizes = GameSettings.handSizes(players: settings.playerCount, format: settings.format)
        var list = [Player(id: 0, name: "Tu", isHuman: true)]
        for i in 1..<settings.playerCount {
            list.append(Player(id: i, name: Self.botNames[i - 1], isHuman: false))
        }
        self.players = list
        self.dealer = Int.random(in: 0..<settings.playerCount)
        startHand()
    }

    // MARK: Derived

    var n: Int { players.count }
    var handSize: Int { handSizes[handIndex] }
    var trumpSuit: Suit? { trump?.suit }
    var leadSuit: Suit? { trick.first?.card.suit }
    var bidSum: Int { players.compactMap(\.bid).reduce(0, +) }
    var isHumanTurn: Bool { players[current].isHuman && (phase == .bidding || phase == .playing) }
    var leader: [Player] { players.sorted { $0.score > $1.score } }

    /// Începutul ultimei serii de mâini de o carte (la 1-8-1 e finalul, la 8-1-8 mijlocul).
    private var lastOnesStart: Int {
        var i = handSizes.count - 1
        while i >= 0 && handSizes[i] != 1 { i -= 1 }
        while i > 0 && handSizes[i - 1] == 1 { i -= 1 }
        return max(i, 0)
    }

    /// Varianta „pe frunte”: nu-ți vezi propria carte, dar le vezi pe ale celorlalți.
    var isForeheadHand: Bool {
        settings.forehead && handSize == 1 && handIndex >= lastOnesStart
    }

    func allowedBids(for p: Int) -> [Int] {
        let all = Array(0...handSize)
        guard p == dealer else { return all }          // ultimul la licitație e cel care a împărțit
        let forbidden = handSize - bidSum
        return all.filter { $0 != forbidden }
    }

    func forbiddenBid(for p: Int) -> Int? {
        guard p == dealer else { return nil }
        let f = handSize - bidSum
        return (0...handSize).contains(f) ? f : nil
    }

    func legalCards(for p: Int) -> [Card] {
        let hand = players[p].hand
        guard let lead = leadSuit else { return hand }
        let follow = hand.filter { $0.suit == lead }
        if !follow.isEmpty { return follow }
        if let t = trumpSuit {
            let trumps = hand.filter { $0.suit == t }
            if !trumps.isEmpty { return trumps }   // obligat să tai cu atu
        }
        return hand
    }

    func beats(_ a: Card, _ b: Card) -> Bool {
        if a.suit == b.suit { return a.rank > b.rank }
        if let t = trumpSuit, a.suit == t { return true }
        return false
    }

    func currentWinner() -> PlayedCard? {
        guard var best = trick.first else { return nil }
        for pc in trick.dropFirst() where beats(pc.card, best.card) { best = pc }
        return best
    }

    // MARK: Flow

    private func startHand() {
        let size = handSize
        var deck = Deck.make(players: n).shuffled()
        for i in players.indices {
            players[i].hand = []
            players[i].bid = nil
            players[i].tricks = 0
        }
        for c in 0..<size {
            for k in 0..<n {
                let p = (dealer + 1 + k) % n
                players[p].hand.append(deck[c * n + k])
            }
        }
        let used = size * n
        trump = used < deck.count ? deck[used] : nil       // la 8 cărți nu rămâne carte → fără atu
        deck.removeAll()
        for i in players.indices { players[i].hand = sortHand(players[i].hand) }
        trick = []
        trickWinner = nil
        current = (dealer + 1) % n
        phase = .bidding
        runBots()
    }

    private func sortHand(_ hand: [Card]) -> [Card] {
        let order: [Suit] = [.spades, .hearts, .clubs, .diamonds]   // alternează culorile
        return hand.sorted {
            let a = order.firstIndex(of: $0.suit)!, b = order.firstIndex(of: $1.suit)!
            return a == b ? $0.rank > $1.rank : a < b
        }
    }

    func humanBid(_ b: Int) {
        guard phase == .bidding, current == human, allowedBids(for: human).contains(b) else { return }
        placeBid(b, by: human)
        runBots()
    }

    func humanPlay(_ card: Card) {
        guard phase == .playing, current == human, legalCards(for: human).contains(card) else { return }
        Haptics.tap()
        play(card, by: human)
        runBots()
    }

    func nextHand() {
        guard phase == .handEnd else { return }
        handIndex += 1
        dealer = (dealer + 1) % n
        startHand()
    }

    func stop() { botTask?.cancel() }

    private func placeBid(_ b: Int, by p: Int) {
        players[p].bid = b
        if players.allSatisfy({ $0.bid != nil }) {
            phase = .playing
            current = (dealer + 1) % n
        } else {
            current = (p + 1) % n
        }
    }

    private func play(_ card: Card, by p: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            players[p].hand.removeAll { $0 == card }
            trick.append(PlayedCard(player: p, card: card))
        }
        if trick.count == n {
            trickWinner = currentWinner()?.player
            phase = .trickEnd
        } else {
            current = (p + 1) % n
        }
    }

    private func finishTrick() {
        guard let w = trickWinner else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            players[w].tricks += 1
            trick = []
        }
        trickWinner = nil
        if players[w].hand.isEmpty {
            endHand()
        } else {
            current = w
            phase = .playing
        }
    }

    private func endHand() {
        var entries: [HandRecord.Entry] = []
        let countsForStreak = handSize > 1      // mâinile de o carte nu contează la serii
        for i in players.indices {
            let bid = players[i].bid ?? 0
            let tr = players[i].tricks
            let made = bid == tr
            let delta = made ? 5 + bid : -abs(tr - bid)
            var bonus = 0
            if settings.streakBonus && countsForStreak {
                if made {
                    players[i].streak = max(players[i].streak, 0) + 1
                    if players[i].streak == 5 { bonus = 10; players[i].streak = 0 }
                } else {
                    players[i].streak = min(players[i].streak, 0) - 1
                    if players[i].streak == -5 { bonus = -10; players[i].streak = 0 }
                }
            }
            players[i].score += delta + bonus
            entries.append(.init(bid: bid, tricks: tr, delta: delta, bonus: bonus, total: players[i].score))
        }
        history.append(HandRecord(id: handIndex, size: handSize, trump: trump, dealer: dealer, entries: entries))
        let me = entries[human]
        if me.made { Haptics.success() } else { Haptics.warning() }
        phase = handIndex == handSizes.count - 1 ? .gameOver : .handEnd
    }

    // MARK: Derulare rapidă (capturi App Store)

    /// Joacă instantaneu, cu logica adversarilor pentru toate locurile (inclusiv al tău),
    /// până când `stop` devine adevărat. Întoarce false dacă jocul s-a terminat înainte.
    @discardableResult
    func fastForward(maxSteps: Int = 5000, until stop: (GameEngine) -> Bool) -> Bool {
        botTask?.cancel()
        frozen = true
        for _ in 0..<maxSteps {
            if stop(self) { return true }
            switch phase {
            case .bidding:
                let p = current
                let b = isForeheadHand
                    ? BotAI.foreheadBid(for: p, engine: self, allowed: allowedBids(for: p))
                    : BotAI.bid(hand: players[p].hand, trump: trump, players: n, allowed: allowedBids(for: p))
                placeBid(b, by: p)
            case .playing:
                let p = current
                let wants = (players[p].bid ?? 0) > players[p].tricks
                play(BotAI.chooseCard(legal: legalCards(for: p), engine: self, wantsMore: wants), by: p)
            case .trickEnd:
                finishTrick()
            case .handEnd:
                nextHand()
            case .gameOver:
                return stop(self)
            }
        }
        return stop(self)
    }

    // MARK: Bots

    private func runBots() {
        botTask?.cancel()
        guard !frozen else { return }
        botTask = Task { [weak self] in
            await self?.botLoop()
        }
    }

    private func pause(_ seconds: Double) async {
        let s = seconds / max(settings.speed, 0.25)
        try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000))
    }

    private func botLoop() async {
        while !Task.isCancelled {
            switch phase {
            case .bidding:
                guard !players[current].isHuman else { return }
                await pause(0.7)
                if Task.isCancelled { return }
                let p = current
                let b = isForeheadHand
                    ? BotAI.foreheadBid(for: p, engine: self, allowed: allowedBids(for: p))
                    : BotAI.bid(hand: players[p].hand, trump: trump, players: n,
                                allowed: allowedBids(for: p))
                placeBid(b, by: p)
            case .playing:
                guard !players[current].isHuman else { return }
                await pause(0.65)
                if Task.isCancelled { return }
                let p = current
                let wants = (players[p].bid ?? 0) > players[p].tricks
                let card = BotAI.chooseCard(legal: legalCards(for: p), engine: self, wantsMore: wants)
                play(card, by: p)
            case .trickEnd:
                await pause(1.1)
                if Task.isCancelled { return }
                finishTrick()
            case .handEnd, .gameOver:
                return
            }
        }
    }
}

@MainActor
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}
