import Foundation

enum MeldKind: Hashable, Codable {
    case run   // suită: aceeași culoare, numere consecutive
    case set   // terță: același număr, culori diferite
}

/// O poziție dintr-o formație etalată.
struct MeldSlot: Identifiable, Hashable, Codable {
    var tile: Tile
    /// Pentru suită: poziția 1...14 (14 = piesa 1 pusă după 13). Pentru terță: numărul.
    var value: Int
    /// Pentru Joker: culoarea pe care o înlocuiește (nil dacă nu se poate ști, ex. terță 2 piese + Joker).
    var representedColor: TileColor?
    /// Jucătorul care a pus piesa — el primește punctele ei la final.
    var placedBy: Int
    /// Locul unde a stat un Joker înlocuit se numără 50 de puncte (pentru cel care pusese Jokerul).
    var fixedScore: Int? = nil
    /// Joker re-folosit: nu mai poate fi înlocuit și se numără 0 puncte.
    var jokerReused: Bool = false

    var id: Int { tile.id }
    var representedNumber: Int { value == 14 ? 1 : value }
}

struct Meld: Identifiable, Hashable, Codable {
    let id: Int
    let kind: MeldKind
    var owner: Int
    var slots: [MeldSlot]
    /// Culoarea suitei (doar pentru .run).
    var color: TileColor?
    /// Numărul terței (doar pentru .set).
    var number: Int?

    // MARK: - Punctaj

    /// Valoarea unei poziții în timpul jocului (folosită la etalarea de 45 de puncte).
    static func gamePoints(kind: MeldKind, value: Int) -> Int {
        switch kind {
        case .run:
            if value == 14 { return 10 }   // 12-13-1
            if value == 1 { return 5 }     // 1-2-3
            return value >= 10 ? 10 : 5
        case .set:
            if value == 1 { return 25 }    // 1-1-1(-1)
            return value >= 10 ? 10 : 5
        }
    }

    /// Valoarea formației în timpul jocului (Jokerul ia valoarea piesei înlocuite).
    var points: Int {
        slots.reduce(0) { $0 + Meld.gamePoints(kind: kind, value: $1.value) }
    }

    /// Punctele de la finalul mâinii care revin unui jucător din această formație.
    func finalScore(for player: Int) -> Int {
        slots.filter { $0.placedBy == player }.reduce(0) { acc, slot in
            if let fixed = slot.fixedScore { return acc + fixed }
            if slot.tile.isJoker { return acc + (slot.jokerReused ? 0 : 50) }
            return acc + Meld.gamePoints(kind: kind, value: slot.value)
        }
    }

    var isSetOfOnes: Bool { kind == .set && number == 1 }
    var jokerCount: Int { slots.filter { $0.tile.isJoker }.count }
    var realCount: Int { slots.count - jokerCount }

    // MARK: - Reguli Joker

    /// O formație cu 1 Joker trebuie să aibă minim 2 piese reale; cu 2 Jokeri, minim 4 piese reale.
    static func jokerRuleOK(real: Int, jokers: Int) -> Bool {
        switch jokers {
        case 0: return real >= 3
        case 1: return real >= 2
        case 2: return real >= 4
        default: return false
        }
    }

    // MARK: - Construire

    /// Încearcă să construiască o formație validă din piesele date (ordinea nu contează).
    static func make(id: Int, tiles: [Tile], owner: Int, reusedJokers: Set<Int>) -> Meld? {
        guard tiles.count >= 3 else { return nil }
        let jokers = tiles.filter { $0.isJoker }
        let real = tiles.filter { !$0.isJoker }
        guard jokerRuleOK(real: real.count, jokers: jokers.count) else { return nil }
        if let set = makeSet(id: id, real: real, jokers: jokers, owner: owner, reused: reusedJokers) {
            return set
        }
        return makeRun(id: id, real: real, jokers: jokers, owner: owner, reused: reusedJokers)
    }

    private static func makeSet(id: Int, real: [Tile], jokers: [Tile], owner: Int, reused: Set<Int>) -> Meld? {
        guard jokers.count <= 1, real.count + jokers.count <= 4 else { return nil }
        guard let n = real.first?.number, real.allSatisfy({ $0.number == n }) else { return nil }
        let colors = real.compactMap { $0.color }
        guard Set(colors).count == colors.count else { return nil }

        var slots = real
            .sorted { $0.color!.rawValue < $1.color!.rawValue }
            .map { MeldSlot(tile: $0, value: n, representedColor: $0.color, placedBy: owner) }
        if let j = jokers.first {
            let missing = TileColor.allCases.filter { !colors.contains($0) }
            let represented: TileColor? = real.count == 3 ? missing.first : nil
            slots.append(MeldSlot(tile: j, value: n, representedColor: represented, placedBy: owner,
                                  jokerReused: reused.contains(j.id)))
        }
        return Meld(id: id, kind: .set, owner: owner, slots: slots, color: nil, number: n)
    }

    private static func makeRun(id: Int, real: [Tile], jokers: [Tile], owner: Int, reused: Set<Int>) -> Meld? {
        guard let color = real.first?.color, real.allSatisfy({ $0.color == color }) else { return nil }
        let numbers = real.map { $0.number }
        guard Set(numbers).count == numbers.count else { return nil }
        let length = real.count + jokers.count
        guard length <= 14 else { return nil }
        let hasAce = numbers.contains(1)

        for aceHigh in (hasAce ? [true, false] : [false]) {
            let values = numbers.map { ($0 == 1 && aceHigh) ? 14 : $0 }
            let valueSet = Set(values)
            guard let minV = values.min(), let maxV = values.max() else { continue }
            guard maxV - minV + 1 <= length else { continue }
            let upper = min(minV, 15 - length)
            let lower = max(1, maxV - length + 1)
            guard upper >= lower else { continue }

            for start in stride(from: upper, through: lower, by: -1) {
                let end = start + length - 1
                guard end <= 14, !(start == 1 && end == 14) else { continue }
                let jokerPositions = (start...end).filter { !valueSet.contains($0) }
                guard jokerPositions.count == jokers.count else { continue }
                if jokerPositions.count == 2, abs(jokerPositions[0] - jokerPositions[1]) == 1 { continue }

                var slots: [MeldSlot] = []
                for (tile, value) in zip(real, values) {
                    slots.append(MeldSlot(tile: tile, value: value, representedColor: color, placedBy: owner))
                }
                for (joker, pos) in zip(jokers, jokerPositions) {
                    slots.append(MeldSlot(tile: joker, value: pos, representedColor: color, placedBy: owner,
                                          jokerReused: reused.contains(joker.id)))
                }
                slots.sort { $0.value < $1.value }
                return Meld(id: id, kind: .run, owner: owner, slots: slots, color: color, number: nil)
            }
        }
        return nil
    }

    // MARK: - Lipire

    /// Returnează formația după lipirea piesei sau nil dacă lipirea nu e permisă.
    func adding(_ tile: Tile, by player: Int, reused: Bool) -> Meld? {
        switch kind {
        case .run: return addingToRun(tile, by: player, reused: reused)
        case .set: return addingToSet(tile, by: player, reused: reused)
        }
    }

    private func addingToRun(_ tile: Tile, by player: Int, reused: Bool) -> Meld? {
        guard let color, let start = slots.first?.value, let end = slots.last?.value else { return nil }
        var result = self

        if tile.isJoker {
            guard Meld.jokerRuleOK(real: realCount, jokers: jokerCount + 1) else { return nil }
            let jokerPositions = slots.filter { $0.tile.isJoker }.map { $0.value }
            var candidates: [Int] = []
            if end < 14, !(start == 1 && end + 1 == 14) { candidates.append(end + 1) }
            if start > 1, !(start - 1 == 1 && end == 14) { candidates.append(start - 1) }
            for pos in candidates where !jokerPositions.contains(where: { abs($0 - pos) == 1 }) {
                result.slots.append(MeldSlot(tile: tile, value: pos, representedColor: color,
                                             placedBy: player, jokerReused: reused))
                result.slots.sort { $0.value < $1.value }
                return result
            }
            return nil
        }

        guard tile.color == color else { return nil }
        let possible = tile.number == 1 ? [1, 14] : [tile.number]
        for v in possible {
            let fitsLow = v == start - 1 && v >= 1 && !(v == 1 && end == 14)
            let fitsHigh = v == end + 1 && v <= 14 && !(start == 1 && v == 14)
            if fitsLow || fitsHigh {
                result.slots.append(MeldSlot(tile: tile, value: v, representedColor: color, placedBy: player))
                result.slots.sort { $0.value < $1.value }
                return result
            }
        }
        return nil
    }

    private func addingToSet(_ tile: Tile, by player: Int, reused: Bool) -> Meld? {
        guard let number, slots.count < 4 else { return nil }
        var result = self
        let realColors = slots.filter { !$0.tile.isJoker }.compactMap { $0.tile.color }

        if tile.isJoker {
            guard jokerCount == 0, realCount >= 2 else { return nil }
            let missing = TileColor.allCases.filter { !realColors.contains($0) }
            result.slots.append(MeldSlot(tile: tile, value: number,
                                         representedColor: realCount == 3 ? missing.first : nil,
                                         placedBy: player, jokerReused: reused))
            return result
        }

        guard tile.number == number, let c = tile.color, !realColors.contains(c) else { return nil }
        result.slots.insert(MeldSlot(tile: tile, value: number, representedColor: c, placedBy: player),
                            at: result.realCount)
        // Dacă acum sunt 3 piese reale + Joker, se știe ce culoare înlocuiește Jokerul.
        let newReal = realColors + [c]
        if newReal.count == 3, let idx = result.slots.firstIndex(where: { $0.tile.isJoker }) {
            result.slots[idx].representedColor = TileColor.allCases.first { !newReal.contains($0) }
        }
        return result
    }

    // MARK: - Înlocuire Joker

    /// Index-ul Jokerului pe care piesa îl poate înlocui, dacă există.
    func replaceableJokerIndex(for tile: Tile) -> Int? {
        guard !tile.isJoker, let tc = tile.color else { return nil }
        return slots.firstIndex { slot in
            slot.tile.isJoker && !slot.jokerReused &&
            slot.representedColor == tc && slot.representedNumber == tile.number
        }
    }

    /// Înlocuiește Jokerul cu piesa dată; returnează formația nouă și Jokerul eliberat.
    func replacingJoker(with tile: Tile) -> (Meld, Tile)? {
        guard let idx = replaceableJokerIndex(for: tile) else { return nil }
        var result = self
        let old = slots[idx]
        result.slots[idx] = MeldSlot(tile: tile, value: old.value, representedColor: tile.color,
                                     placedBy: old.placedBy, fixedScore: 50)
        return (result, old.tile)
    }
}
