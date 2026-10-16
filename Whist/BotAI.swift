import Foundation

/// Adversari simpli, dar cinstiți: nu văd cărțile celorlalți.
@MainActor
enum BotAI {

    // MARK: Licitație

    static func estimateTricks(hand: [Card], trump: Card?, players: Int) -> Double {
        let low = Deck.lowestRank(players: players)
        let t = trump?.suit
        let h = hand.count
        var known = Set(hand)
        if let trump { known.insert(trump) }

        var total = 0.0
        for card in hand {
            // câte cărți mai mari din aceeași culoare sunt „pe afară”
            let higherOut = (card.rank + 1 ..< 15).filter { r in
                r >= low && !known.contains(Card(suit: card.suit, rank: r))
            }.count

            var p: Double
            if card.suit == t {
                p = [0.95, 0.72, 0.48, 0.28][min(higherOut, 3)]
                if higherOut >= 3 && h >= 5 { p = 0.35 }       // atuurile mici taie în mâinile lungi
            } else {
                p = [0.85, 0.40, 0.12, 0.04][min(higherOut, 3)]
                let sameSuit = hand.filter { $0.suit == card.suit }.count
                if t != nil {
                    // cu cât sunt mai mulți jucători și mai multe cărți, cu atât crește riscul de tăiere
                    let risk = Double(players - 3) * 0.06 + Double(max(h - 3, 0)) * 0.03 + Double(max(sameSuit - 2, 0)) * 0.08
                    p *= max(0.45, 1.0 - risk)
                }
            }
            total += p
        }
        return total
    }

    static func bid(hand: [Card], trump: Card?, players: Int, allowed: [Int]) -> Int {
        let est = estimateTricks(hand: hand, trump: trump, players: players)
        // un pic de personalitate
        let noisy = est + Double.random(in: -0.25...0.25)
        return allowed.min {
            let da = abs(Double($0) - noisy), db = abs(Double($1) - noisy)
            return da == db ? $0 < $1 : da < db
        } ?? 0
    }

    /// Pe frunte: botul nu-și știe cartea, dar le vede pe ale celorlalți.
    /// Calculează exact probabilitatea să câștige levata, peste toate cărțile pe care le-ar putea avea.
    static func foreheadBid(for p: Int, engine: GameEngine, allowed: [Int]) -> Int {
        var seen = Set<Card>()
        if let t = engine.trump { seen.insert(t) }
        for q in engine.players where q.id != p { q.hand.forEach { seen.insert($0) } }
        let unseen = Deck.make(players: engine.n).filter { !seen.contains($0) }
        guard !unseen.isEmpty else { return allowed.first ?? 0 }

        let leader = (engine.dealer + 1) % engine.n
        var wins = 0
        for mine in unseen {
            var best: (player: Int, card: Card)?
            for k in 0..<engine.n {
                let q = (leader + k) % engine.n
                // după ce s-a jucat, cartea nu mai e în mână: o luăm din levata curentă
                let c: Card
                if q == p { c = mine }
                else if let h = engine.players[q].hand.first { c = h }
                else if let pc = engine.playedThisHand.first(where: { $0.player == q }) { c = pc.card }
                else { continue }
                if let b = best {
                    if engine.beats(c, b.card) { best = (q, c) }
                } else {
                    best = (q, c)
                }
            }
            if best?.player == p { wins += 1 }
        }
        let prob = Double(wins) / Double(unseen.count)
        return allowed.min {
            let da = abs(Double($0) - prob), db = abs(Double($1) - prob)
            return da == db ? $0 > $1 : da < db
        } ?? 0
    }

    // MARK: Joc

    static func strength(_ c: Card, trump: Suit?) -> Int {
        c.rank + (c.suit == trump ? 100 : 0)
    }

    static func chooseCard(legal: [Card], engine: GameEngine, wantsMore: Bool) -> Card? {
        let t = engine.trumpSuit
        let sorted = legal.sorted { strength($0, trump: t) < strength($1, trump: t) }
        guard let lowest = sorted.first, let highest = sorted.last else { return nil }

        // Deschidere
        guard let best = engine.currentWinner() else {
            if wantsMore {
                // as de culoare non-atu dacă avem, altfel cea mai mare carte
                if let ace = legal.first(where: { $0.rank == 14 && $0.suit != t }) { return ace }
                return highest
            }
            // nu vrem levate: deschidem cu cea mai mică carte non-atu
            return sorted.first(where: { $0.suit != t }) ?? lowest
        }

        let winners = sorted.filter { engine.beats($0, best.card) }
        let losers = sorted.filter { !engine.beats($0, best.card) }
        let isLast = engine.trick.count == engine.n - 1

        if wantsMore {
            if let w = isLast ? winners.first : winners.last { return w }
            return losers.first ?? lowest
        } else {
            if let dump = losers.last { return dump }       // scăpăm de cea mai mare carte care pierde
            return winners.last ?? highest
        }
    }
}
