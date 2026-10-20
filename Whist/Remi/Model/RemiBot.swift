import Foundation

enum BotAction: Hashable {
    case drawStock
    case takeRow(Int)
    case takeAtu
    case meld([Int])
    case add(tile: Int, meld: Int)
    case replace(tile: Int, meld: Int)
    case discard(Int)
}

/// Adversar controlat de calculator. Planifică întreaga tură pe o copie a stării,
/// folosind exact aceleași funcții de reguli ca jucătorul uman.
enum RemiBot {
    static func plan(_ state: RemiState) -> [BotAction] {
        // Primul jucător, în prima tură: doar aruncă.
        if state.phase == .play {
            var sim = state
            var actions: [BotAction] = []
            if playAfterDraw(&sim, &actions) { return actions }
            return fallbackDiscard(state)
        }

        let canTakeSpecial = !state.isFirstRound && state.handCountAtTurnStart > 2

        // 1. Atuul — doar dacă închide cu el.
        if canTakeSpecial, state.atu != nil {
            var sim = state
            var actions: [BotAction] = [.takeAtu]
            if (try? sim.takeAtu()) != nil, playAfterDraw(&sim, &actions) { return actions }
        }

        // 2. Ultima piesă din șir sau ruperea șirului.
        if canTakeSpecial, state.row.count > 1 {
            var indices = [state.row.count - 1]
            if state.openedAtTurnStart && state.handCountAtTurnStart >= 4 && state.row.count > 2 {
                let lowest = max(1, state.row.count - 4)
                indices += Array(stride(from: state.row.count - 2, through: lowest, by: -1))
            }
            for idx in indices {
                var sim = state
                var actions: [BotAction] = [.takeRow(idx)]
                if (try? sim.takeFromRow(index: idx)) != nil, playAfterDraw(&sim, &actions) { return actions }
            }
        }

        // 3. Din grămadă.
        var afterDraw = state
        try? afterDraw.drawFromStock()
        if afterDraw.phase == .handOver { return [.drawStock] }
        var sim = afterDraw
        var actions: [BotAction] = [.drawStock]
        if playAfterDraw(&sim, &actions) { return actions }
        return [.drawStock] + fallbackDiscard(afterDraw)
    }

    private static func playAfterDraw(_ sim: inout RemiState, _ actions: inout [BotAction]) -> Bool {
        let me = sim.current

        // a) Schimbă Jokerii de pe masă când are piesa potrivită.
        if sim.openedAtTurnStart {
            var changed = true
            while changed {
                changed = false
                search: for meld in sim.melds {
                    for tile in sim.players[me].hand where !tile.isJoker && meld.replaceableJokerIndex(for: tile) != nil {
                        if (try? sim.replaceJoker(tileID: tile.id, meldID: meld.id)) != nil {
                            actions.append(.replace(tile: tile.id, meld: meld.id))
                            changed = true
                            break search
                        }
                    }
                }
            }
        }

        // b) Formații noi.
        if sim.canCreateNewMelds {
            let hand = sim.players[me].hand
            let must = sim.mustUseTileID.flatMap { id in hand.first { $0.id == id } }
            let groups = MeldFinder.bestPlan(hand: hand, maxTiles: hand.count - 1,
                                             opening: !sim.openedAtTurnStart, mustUse: must)
            for g in groups {
                let ids = g.map { $0.id }
                guard (try? sim.createMeld(tileIDs: ids)) != nil else { return false }
                actions.append(.meld(ids))
            }
        }

        // c) Lipiri (doar dacă era etalat la începutul turei).
        if sim.openedAtTurnStart {
            var changed = true
            while changed && sim.players[me].hand.count > 1 {
                changed = false
                let hand = sim.players[me].hand.sorted { !$0.isJoker && $1.isJoker }
                search: for tile in hand {
                    // Jokerul îl păstrăm, decât dacă suntem aproape de închidere.
                    if tile.isJoker && sim.players[me].hand.count > 2 { continue }
                    for meld in sim.melds where !(tile.isJoker && meld.owner != me) {
                        guard meld.adding(tile, by: me, reused: false) != nil else { continue }
                        if (try? sim.addToMeld(tileID: tile.id, meldID: meld.id)) != nil {
                            actions.append(.add(tile: tile.id, meld: meld.id))
                            changed = true
                            break search
                        }
                    }
                }
            }
        }

        // d) Aruncă.
        guard let tile = chooseDiscard(sim) else { return false }
        guard (try? sim.discard(tileID: tile.id)) != nil else { return false }
        actions.append(.discard(tile.id))
        return true
    }

    /// Aplică o acțiune pe stare, cu aceleași reguli ca jucătorul uman.
    static func apply(_ action: BotAction, to s: inout RemiState) throws {
        switch action {
        case .drawStock: try s.drawFromStock()
        case .takeRow(let i): try s.takeFromRow(index: i)
        case .takeAtu: try s.takeAtu()
        case .meld(let ids): _ = try s.createMeld(tileIDs: ids)
        case .add(let t, let m): try s.addToMeld(tileID: t, meldID: m)
        case .replace(let t, let m): try s.replaceJoker(tileID: t, meldID: m)
        case .discard(let t): try s.discard(tileID: t)
        }
    }

    /// Joacă o tură completă pentru jucătorul curent (folosit la simulări și capturi).
    static func playTurn(_ s: inout RemiState) {
        let who = s.current
        for action in plan(s) {
            guard s.current == who, s.phase != .handOver else { break }
            try? apply(action, to: &s)
        }
        guard s.current == who, s.phase != .handOver else { return }
        if s.phase == .draw { try? s.drawFromStock() }
        if s.phase == .play {
            for t in s.players[who].hand where (try? s.discard(tileID: t.id)) != nil { return }
        }
        if s.current == who && s.phase != .handOver { s.endHand(closer: nil, closingTile: nil) }
    }

    private static func fallbackDiscard(_ state: RemiState) -> [BotAction] {
        let hand = state.players[state.current].hand
        let ordered = hand.sorted { usefulness($0, state: state) < usefulness($1, state: state) }
        for t in ordered {
            var s = state
            if (try? s.discard(tileID: t.id)) != nil { return [.discard(t.id)] }
        }
        return []
    }

    static func chooseDiscard(_ state: RemiState) -> Tile? {
        let hand = state.players[state.current].hand
        if hand.count == 1 { return hand.first }
        return hand.min { a, b in
            let ua = usefulness(a, state: state), ub = usefulness(b, state: state)
            if ua != ub { return ua < ub }
            return a.nominalValue > b.nominalValue
        }
    }

    /// Cât de utilă e o piesă pentru formații viitoare (mai mic = de aruncat).
    static func usefulness(_ t: Tile, state: RemiState) -> Double {
        if t.isJoker { return 1000 }
        let me = state.current
        let hand = state.players[me].hand
        var u = 0.0
        var seenSetColors: Set<TileColor> = []
        for o in hand where o.id != t.id && !o.isJoker {
            if o.color == t.color {
                var dist = abs(o.number - t.number)
                if t.number == 1 { dist = min(dist, abs(14 - o.number)) }
                if o.number == 1 { dist = min(dist, abs(14 - t.number)) }
                if dist == 1 { u += 3 } else if dist == 2 { u += 1.5 }
            } else if o.number == t.number, let c = o.color, !seenSetColors.contains(c) {
                seenSetColors.insert(c)
                u += 2
            }
        }
        if state.melds.contains(where: { $0.adding(t, by: me, reused: false) != nil }) {
            u += state.players[me].opened ? 6 : 3
        }
        return u
    }
}
