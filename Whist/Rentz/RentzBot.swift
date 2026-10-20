import Foundation

/// Adversarii din Renț: nu văd cărțile celorlalți, doar ce s-a jucat.
@MainActor
enum RentzBot {

    // MARK: Alegerea jocului

    static func chooseGame(for p: Int, engine e: RentzEngine) -> RentzGame {
        let options = e.available(for: p)
        guard !options.isEmpty else { return .whist }
        let hand = e.players[p].hand
        let scored = options.map { ($0, expectedValue($0, hand: hand, engine: e) + Double.random(in: -12...12)) }
        return scored.max { $0.1 < $1.1 }?.0 ?? options[0]
    }

    /// Cât crede botul că ia în acest joc (puncte, cu semn).
    static func expectedValue(_ g: RentzGame, hand: [Card], engine e: RentzEngine) -> Double {
        let n = Double(e.n)
        let tricks = BotAI.estimateTricks(hand: hand, trump: nil, players: e.n)
        let cardsTaken = tricks * n
        let deckSize = Double(8 * e.n)
        switch g {
        case .whist:
            return tricks * Double(RentzScore.trickPlus)
        case .tricks:
            return tricks * Double(RentzScore.trickMinus)
        case .queens:
            let mine = Double(hand.filter { $0.rank == 12 }.count)
            return (cardsTaken * 4 / deckSize + mine * 0.25) * Double(RentzScore.queen)
        case .diamonds:
            let suitSize = Double(15 - e.low)
            let highDiamonds = Double(hand.filter { $0.suit == .diamonds && $0.rank >= 12 }.count)
            return (cardsTaken * suitSize / deckSize + highDiamonds * 0.4) * Double(RentzScore.diamond)
        case .kingOfHearts:
            return kingRisk(hand: hand, low: e.low, tricks: tricks) * Double(RentzScore.kingOfHearts)
        case .totals:
            return expectedValue(.tricks, hand: hand, engine: e) + expectedValue(.queens, hand: hand, engine: e)
                + expectedValue(.diamonds, hand: hand, engine: e) + expectedValue(.kingOfHearts, hand: hand, engine: e)
        case .tenOfClubs:
            let hasTen = hand.contains(where: RentzScore.isTenOfClubs)
            let higherClubs = hand.filter { $0.suit == .clubs && $0.rank > 10 }.count
            let p = hasTen ? (higherClubs >= 2 ? 0.75 : 0.45) : min(0.5, tricks / 8 * 0.9)
            return p * Double(RentzScore.tenOfClubs)
        case .rentz:
            let jacks = Double(hand.filter { $0.rank == 11 }.count)
            let aces = Double(hand.filter { $0.rank == 14 }.count)
            let far = Double(hand.filter { abs($0.rank - 11) >= 3 && $0.rank != 14 }.count)
            let place = max(1, min(n, 2.6 - jacks * 0.45 - aces * 0.25 + far * 0.15))
            return Double(RentzScore.rentzPlace(Int(place.rounded()), of: e.n)) * 0.85
        }
    }

    private static func kingRisk(hand: [Card], low: Int, tricks: Double) -> Double {
        if hand.contains(where: RentzScore.isKingOfHearts) {
            let lowerHearts = hand.filter { $0.suit == .hearts && $0.rank < 13 }.count
            return lowerHearts >= 3 ? 0.35 : (lowerHearts >= 1 ? 0.6 : 0.85)
        }
        let aceHearts = hand.contains { $0.suit == .hearts && $0.rank == 14 }
        return min(0.6, tricks / 8 + (aceHearts ? 0.25 : 0))
    }

    // MARK: Jocul

    static func chooseCard(for p: Int, engine e: RentzEngine) -> Card? {
        let legal = e.legalCards(for: p)
        guard !legal.isEmpty, let g = e.game else { return nil }
        if g == .rentz { return rentzCard(legal, p: p, engine: e) }
        if g == .whist { return trickCard(legal, wantsTricks: true, engine: e) }
        if g == .tenOfClubs { return tenOfClubsCard(legal, engine: e) }
        return avoidCard(legal, game: g, engine: e)
    }

    /// Cât de „periculoasă” e o carte în jocul dat (cât te poate costa dacă o iei).
    static func danger(_ c: Card, game: RentzGame) -> Int {
        var d = 0
        if (game == .kingOfHearts || game == .totals) && RentzScore.isKingOfHearts(c) { d += 200 }
        if (game == .queens || game == .totals) && c.rank == 12 { d += 40 }
        if (game == .diamonds || game == .totals) && c.suit == .diamonds { d += 30 }
        return d
    }

    /// Jocuri negative: nu luăm levate cu penalizări.
    private static func avoidCard(_ legal: [Card], game g: RentzGame, engine e: RentzEngine) -> Card {
        let byRank = legal.sorted { $0.rank < $1.rank }
        guard let best = e.currentWinner() else {
            // deschidem cu o carte mică, dintr-o culoare fără penalizări dacă se poate
            let safe = byRank.filter { danger($0, game: g) == 0 }
            return (safe.first ?? byRank.first)!
        }
        let following = legal.contains { $0.suit == best.card.suit }
        let isLast = e.trick.count == e.n - 1
        let trickDanger = e.trick.reduce(0) { $0 + danger($1.card, game: g) } + (g == .tricks || g == .totals ? 50 : 0)
        if following {
            let losers = byRank.filter { !e.wouldWin($0) }
            if let dump = losers.last { return dump }                 // cea mai mare care tot pierde
            // trebuie să câștigăm: dacă levata e curată și suntem ultimii, scăpăm de cea mai mare
            if isLast && trickDanger == 0 { return byRank.last! }
            return byRank.last!                                        // oricum o luăm: aruncăm cea mai mare
        }
        // nu avem culoarea: scăpăm de cea mai periculoasă, apoi de cea mai mare
        return legal.max { (danger($0, game: g), $0.rank) < (danger($1, game: g), $1.rank) }!
    }

    /// Whist (+): vrem levate.
    private static func trickCard(_ legal: [Card], wantsTricks: Bool, engine e: RentzEngine) -> Card {
        let byRank = legal.sorted { $0.rank < $1.rank }
        guard e.currentWinner() != nil else {
            return legal.first { $0.rank == 14 } ?? byRank.last!
        }
        let winners = byRank.filter { e.wouldWin($0) }
        let isLast = e.trick.count == e.n - 1
        if !winners.isEmpty { return isLast ? winners.first! : winners.last! }
        return byRank.first!
    }

    /// Zece de treflă: îl vrem în levata noastră.
    private static func tenOfClubsCard(_ legal: [Card], engine e: RentzEngine) -> Card {
        let byRank = legal.sorted { $0.rank < $1.rank }
        let tenOnTable = e.trick.contains { RentzScore.isTenOfClubs($0.card) }
        let ten = legal.first(where: RentzScore.isTenOfClubs)
        guard let best = e.currentWinner() else {
            // deschidem cu treflă mare dacă avem 10 + ceva peste; altfel o carte mică
            if ten != nil, let high = legal.filter({ $0.suit == .clubs && $0.rank > 10 }).max(by: { $0.rank < $1.rank }) { return high }
            return byRank.first { $0.suit != .clubs } ?? byRank.first!
        }
        let winners = byRank.filter { e.wouldWin($0) }
        let isLast = e.trick.count == e.n - 1
        if tenOnTable { return winners.first ?? byRank.first! }
        if let ten, isLast, ten.suit == best.card.suit, e.wouldWin(ten) { return ten }
        // nu riscăm să-l dăm altcuiva: jucăm mic
        let nonTen = byRank.filter { !RentzScore.isTenOfClubs($0) }
        return nonTen.first ?? byRank.first!
    }

    /// Renț: așii (mai muți o dată), cea mai mică (îl sare pe următorul), cărțile care ne deblochează alte cărți.
    private static func rentzCard(_ legal: [Card], p: Int, engine e: RentzEngine) -> Card {
        let hand = Set(e.players[p].hand)
        func score(_ c: Card) -> Int {
            var s = 0
            if c.rank == 14 { s += 6 }
            if c.rank == e.low { s += 4 }
            let up = Card(suit: c.suit, rank: c.rank + 1), down = Card(suit: c.suit, rank: c.rank - 1)
            if c.rank >= 11 && hand.contains(up) { s += 3 }
            if c.rank <= 11 && hand.contains(down) { s += 3 }
            if c.rank == 11 {
                // un valet deschide culoarea pentru toți: îl punem doar dacă avem cărți în ea
                let mineInSuit = hand.filter { $0.suit == c.suit && $0.rank != 11 }.count
                s += mineInSuit >= 2 ? 2 : -2
            }
            return s
        }
        return legal.max { (score($0), $0.rank) < (score($1), $1.rank) }!
    }
}
