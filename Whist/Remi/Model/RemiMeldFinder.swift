import Foundation

/// Caută cea mai bună combinație de formații dintr-o mână (folosit de AI și pentru sugestii).
enum MeldFinder {
    struct Candidate {
        let kind: MeldKind
        let keys: [TileKey]
        let jokers: Int
        let points: Int
        var size: Int { keys.count + jokers }
    }

    private struct Plan {
        var picks: [Int] = []
        var tiles = 0
        var points = 0
        var hasRun = false
        var hasOnes = false
    }

    static func candidates(for hand: [Tile]) -> [Candidate] {
        var counts: [TileKey: Int] = [:]
        var jokers = 0
        for t in hand {
            if let k = t.key { counts[k, default: 0] += 1 } else { jokers += 1 }
        }
        var result: [Candidate] = []

        // Suite
        for color in TileColor.allCases {
            for start in 1...12 {
                var keys: [TileKey] = []
                var jokerPositions: [Int] = []
                var points = 0
                for end in start...14 {
                    if start == 1 && end == 14 { break }
                    let key = TileKey(color: color, number: end == 14 ? 1 : end)
                    if counts[key, default: 0] > 0 { keys.append(key) } else { jokerPositions.append(end) }
                    points += Meld.gamePoints(kind: .run, value: end)
                    if jokerPositions.count > min(2, jokers) { break }
                    guard end - start + 1 >= 3 else { continue }
                    guard Meld.jokerRuleOK(real: keys.count, jokers: jokerPositions.count) else { continue }
                    if jokerPositions.count == 2 && jokerPositions[1] - jokerPositions[0] == 1 { continue }
                    result.append(Candidate(kind: .run, keys: keys, jokers: jokerPositions.count, points: points))
                }
            }
        }

        // Terțe
        for n in 1...13 {
            let available = TileColor.allCases.filter { counts[TileKey(color: $0, number: n), default: 0] > 0 }
            let value = Meld.gamePoints(kind: .set, value: n)
            guard available.count >= 2 else { continue }
            for mask in 1..<(1 << available.count) {
                let subset = available.enumerated().filter { mask & (1 << $0.offset) != 0 }.map { $0.element }
                guard subset.count >= 2 else { continue }
                let keys = subset.map { TileKey(color: $0, number: n) }
                if subset.count >= 3 {
                    result.append(Candidate(kind: .set, keys: keys, jokers: 0, points: value * keys.count))
                }
                if jokers > 0 && subset.count <= 3 {
                    result.append(Candidate(kind: .set, keys: keys, jokers: 1, points: value * (keys.count + 1)))
                }
            }
        }
        return result
    }

    /// Cea mai bună combinație de formații disjuncte.
    /// - opening: trebuie să îndeplinească condiția de primă etalare (45p + suită, sau terță de 1).
    /// - mustUse: piesă care trebuie inclusă (piesa luată din șir / atuul).
    static func bestPlan(hand: [Tile], maxTiles: Int, opening: Bool, mustUse: Tile?) -> [[Tile]] {
        let cands = candidates(for: hand)
        guard !cands.isEmpty, maxTiles >= 3 else { return [] }

        var counts: [TileKey: Int] = [:]
        var jokers = 0
        for t in hand {
            if let k = t.key { counts[k, default: 0] += 1 } else { jokers += 1 }
        }
        var remaining = counts
        var jokersLeft = jokers
        var plan = Plan()
        var best: Plan?
        var bestScore = Int.min
        var nodes = 0

        func evaluate() -> Int? {
            guard !plan.picks.isEmpty else { return nil }
            if let must = mustUse {
                if let key = must.key {
                    if remaining[key, default: 0] >= counts[key, default: 0] { return nil }
                } else if jokersLeft >= jokers {
                    return nil
                }
            }
            if opening && !(plan.hasOnes || (plan.points >= 45 && plan.hasRun)) { return nil }
            return opening ? plan.points * 100 + plan.tiles : plan.tiles * 1000 + plan.points
        }

        func dfs(_ start: Int) {
            nodes += 1
            if nodes > 30_000 { return }
            if let s = evaluate(), s > bestScore {
                bestScore = s
                best = plan
            }
            for i in start..<cands.count {
                let c = cands[i]
                if plan.tiles + c.size > maxTiles || c.jokers > jokersLeft { continue }
                if c.keys.contains(where: { remaining[$0, default: 0] == 0 }) { continue }
                for k in c.keys { remaining[k, default: 0] -= 1 }
                jokersLeft -= c.jokers
                let saved = plan
                plan.picks.append(i)
                plan.tiles += c.size
                plan.points += c.points
                if c.kind == .run { plan.hasRun = true }
                if c.kind == .set && c.keys.first?.number == 1 { plan.hasOnes = true }
                dfs(i)
                plan = saved
                for k in c.keys { remaining[k, default: 0] += 1 }
                jokersLeft += c.jokers
            }
        }
        dfs(0)

        guard let chosen = best else { return [] }

        // Transformăm cheile în piese concrete (piesa obligatorie are prioritate).
        var pool: [TileKey: [Tile]] = [:]
        var jokerPool: [Tile] = []
        let ordered = hand.sorted { a, b in (a.id == mustUse?.id ? 0 : 1) < (b.id == mustUse?.id ? 0 : 1) }
        for t in ordered {
            if let k = t.key { pool[k, default: []].append(t) } else { jokerPool.append(t) }
        }
        var groups: [[Tile]] = []
        for i in chosen.picks {
            let c = cands[i]
            var g: [Tile] = []
            for k in c.keys { g.append(pool[k]!.removeFirst()) }
            for _ in 0..<c.jokers { g.append(jokerPool.removeFirst()) }
            groups.append(g)
        }
        return groups
    }
}
