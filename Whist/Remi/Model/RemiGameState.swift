import Foundation

struct RemiPlayer: Identifiable, Hashable, Codable {
    let id: Int
    var name: String
    var isHuman: Bool
    var hand: [Tile] = []
    /// S-a etalat (a trecut de prima etalare de 45 de puncte).
    var opened: Bool = false
    /// Câte ture a terminat în mâna curentă (0 = încă în prima rundă).
    var turnsTaken: Int = 0
    /// A avut de la început piesa identică cu atuul (+50 la final).
    var hasAtuBonus: Bool = false
}

enum RemiPhase: Hashable, Codable {
    case draw      // trebuie să ia o piesă
    case play      // poate etala / lipi, apoi aruncă
    case handOver  // mâna s-a terminat
}

struct PlayerResult: Identifiable, Hashable, Codable {
    let id: Int
    let name: String
    let melded: Int
    let inHand: Int
    let bonus: Int
    let total: Int
    let note: String
}

struct HandResult: Hashable, Codable {
    let closer: Int?
    let closingTile: Tile?
    let doubleGame: Bool
    let players: [PlayerResult]
}

/// Starea completă a unei mâini de Remi etalat. Tip valoare, ca să putem face ușor
/// copii (anularea turei, simulări pentru AI).
struct RemiState: Codable {
    var players: [RemiPlayer]
    var stock: [Tile]
    var row: [Tile] = []           // șirul de piese aruncate; prima nu se poate lua
    var atu: Tile?
    let atuTile: Tile
    var melds: [Meld] = []
    var current: Int
    var phase: RemiPhase = .draw
    var nextMeldID = 1
    var doubleGame: Bool
    var reusedJokers: Set<Int> = []
    var result: HandResult?
    var log: [String] = []

    // Contabilitatea turei curente
    var openedAtTurnStart = false
    var handCountAtTurnStart = 0
    var mustUseTileID: Int?
    var tookAtu = false
    var meldsCreatedThisTurn: Set<Int> = []

    // MARK: - Împărțire

    static func newHand(names: [String], humanIndex: Int, starter: Int) -> RemiState {
        var deck = Tile.fullSet().shuffled()
        let atu = deck.removeLast()
        var players = names.enumerated().map { RemiPlayer(id: $0.offset, name: $0.element, isHuman: $0.offset == humanIndex) }
        for i in players.indices {
            let count = i == starter ? 15 : 14
            players[i].hand = Array(deck.suffix(count))
            deck.removeLast(count)
            if let key = atu.key {
                players[i].hasAtuBonus = players[i].hand.contains { $0.key == key }
            }
        }
        let double = atu.isJoker || atu.number == 1
        var state = RemiState(players: players, stock: deck, atu: atu, atuTile: atu,
                              current: starter, doubleGame: double)
        // Jucătorul cu 15 piese doar aruncă în prima tură.
        state.phase = .play
        state.beginTurnBookkeeping()
        state.log.append(double ? L("log.atuDouble", atu.label) : L("log.atu", atu.label))
        for p in state.players where p.hasAtuBonus {
            state.log.append(L("log.hasAtu", p.name))
        }
        return state
    }

    // MARK: - Utilitare

    var currentPlayer: RemiPlayer { players[current] }
    var isFirstRound: Bool { players[current].turnsTaken == 0 }

    func handIndex(of tileID: Int, player: Int) -> Int? {
        players[player].hand.firstIndex { $0.id == tileID }
    }

    func meldIndex(_ id: Int) -> Int? { melds.firstIndex { $0.id == id } }

    private mutating func beginTurnBookkeeping() {
        openedAtTurnStart = players[current].opened
        handCountAtTurnStart = players[current].hand.count
        mustUseTileID = nil
        tookAtu = false
        meldsCreatedThisTurn = []
    }

    /// Cu 1–2 piese pe tablă la începutul turei nu se mai pot face formații noi, doar lipiri.
    var canCreateNewMelds: Bool { !isFirstRound && handCountAtTurnStart > 2 }

    // MARK: - Luarea piesei

    mutating func drawFromStock() throws {
        guard phase == .draw else { throw RuleError(L("err.alreadyDrew")) }
        guard let tile = stock.popLast() else {
            endHand(closer: nil, closingTile: nil)
            return
        }
        players[current].hand.append(tile)
        phase = .play
    }

    mutating func takeFromRow(index: Int) throws {
        guard phase == .draw else { throw RuleError(L("err.alreadyDrew")) }
        guard row.indices.contains(index) else { throw RuleError(L("err.notInRow")) }
        guard !isFirstRound else { throw RuleError(L("err.firstRoundStockOnly")) }
        guard index > 0 else { throw RuleError(L("err.firstRowTile")) }
        guard handCountAtTurnStart > 2 else {
            throw RuleError(L("err.lowTilesStockOnly"))
        }
        let isLast = index == row.count - 1
        if !isLast {
            guard openedAtTurnStart else { throw RuleError(L("err.breakNeedsOpen")) }
            guard handCountAtTurnStart >= 4 else {
                throw RuleError(L("err.threeTilesLastOnly"))
            }
        }
        let taken = Array(row[index...])
        row.removeSubrange(index...)
        players[current].hand.append(contentsOf: taken)
        mustUseTileID = taken.first?.id
        phase = .play
    }

    mutating func takeAtu() throws {
        guard phase == .draw else { throw RuleError(L("err.alreadyDrew")) }
        guard let tile = atu else { throw RuleError(L("err.atuTaken")) }
        guard !isFirstRound else { throw RuleError(L("err.firstRoundStockOnly")) }
        guard handCountAtTurnStart > 2 else {
            throw RuleError(L("err.lowTilesStockOnly"))
        }
        atu = nil
        players[current].hand.append(tile)
        mustUseTileID = tile.id
        tookAtu = true
        phase = .play
    }

    // MARK: - Etalare și lipire

    @discardableResult
    mutating func createMeld(tileIDs: [Int]) throws -> Int {
        guard phase == .play else { throw RuleError(L("err.drawFirst")) }
        guard !isFirstRound else { throw RuleError(L("err.noMeldFirstRound")) }
        guard canCreateNewMelds else {
            throw RuleError(L("err.noNewMeldsLow"))
        }
        let hand = players[current].hand
        let tiles = tileIDs.compactMap { id in hand.first { $0.id == id } }
        guard tiles.count == tileIDs.count, tiles.count >= 3 else {
            throw RuleError(L("err.selectThree"))
        }
        guard hand.count - tiles.count >= 1 else {
            throw RuleError(L("err.keepClosingTile"))
        }
        guard let meld = Meld.make(id: nextMeldID, tiles: tiles, owner: current, reusedJokers: reusedJokers) else {
            throw RuleError(Self.invalidMeldMessage(tiles))
        }
        nextMeldID += 1
        melds.append(meld)
        meldsCreatedThisTurn.insert(meld.id)
        players[current].hand.removeAll { tileIDs.contains($0.id) }
        return meld.id
    }

    private static func invalidMeldMessage(_ tiles: [Tile]) -> String {
        let jokers = tiles.filter { $0.isJoker }.count
        if jokers == 2 && tiles.count < 6 {
            return L("err.twoJokers")
        }
        return L("err.invalidMeld")
    }

    mutating func addToMeld(tileID: Int, meldID: Int) throws {
        guard phase == .play else { throw RuleError(L("err.drawFirst")) }
        guard let hi = handIndex(of: tileID, player: current), let mi = meldIndex(meldID) else { return }
        let tile = players[current].hand[hi]
        let meld = melds[mi]
        let ownNewMeld = meldsCreatedThisTurn.contains(meldID)
        guard openedAtTurnStart || ownNewMeld else {
            throw RuleError(L("err.addNeedsOpen"))
        }
        guard players[current].hand.count > 1 else {
            throw RuleError(L("err.keepClosingTile"))
        }
        if tile.isJoker && meld.owner != current {
            throw RuleError(L("err.jokerOthers"))
        }
        guard let updated = meld.adding(tile, by: current, reused: reusedJokers.contains(tile.id)) else {
            throw RuleError(L("err.doesntFit", tile.label))
        }
        melds[mi] = updated
        players[current].hand.remove(at: hi)
    }

    mutating func replaceJoker(tileID: Int, meldID: Int) throws {
        guard phase == .play else { throw RuleError(L("err.drawFirst")) }
        guard openedAtTurnStart else { throw RuleError(L("err.replaceNeedsOpen")) }
        guard let hi = handIndex(of: tileID, player: current), let mi = meldIndex(meldID) else { return }
        let tile = players[current].hand[hi]
        guard let replacement = melds[mi].replacingJoker(with: tile) else {
            throw RuleError(L("err.noJokerToReplace", tile.label))
        }
        let (updated, joker) = replacement
        melds[mi] = updated
        players[current].hand[hi] = joker
        reusedJokers.insert(joker.id)
    }

    // MARK: - Aruncare / final de tură

    /// Verifică regulile de sfârșit de tură, fără să modifice starea.
    func validateEndOfTurn(discarding tileID: Int) throws {
        guard phase == .play else { throw RuleError(L("err.drawFirst")) }
        guard handIndex(of: tileID, player: current) != nil else { throw RuleError(L("err.notInHand")) }

        if let must = mustUseTileID {
            let used = melds.contains { meldsCreatedThisTurn.contains($0.id) && $0.slots.contains { $0.tile.id == must } }
            if !used {
                throw RuleError(tookAtu ? L("err.atuMustClose") : L("err.rowTileMustBeUsed"))
            }
        }

        if !openedAtTurnStart && !meldsCreatedThisTurn.isEmpty {
            let newMelds = melds.filter { meldsCreatedThisTurn.contains($0.id) }
            let total = newMelds.reduce(0) { $0 + $1.points }
            let hasRun = newMelds.contains { $0.kind == .run }
            let hasOnes = newMelds.contains { $0.isSetOfOnes }
            if !(hasOnes || (total >= 45 && hasRun)) {
                throw RuleError(L("err.firstMeldRule", total))
            }
        }

        if tookAtu && players[current].hand.count != 1 {
            throw RuleError(L("err.atuCloseNow"))
        }
    }

    mutating func discard(tileID: Int) throws {
        try validateEndOfTurn(discarding: tileID)
        guard let hi = handIndex(of: tileID, player: current) else { return }
        let tile = players[current].hand.remove(at: hi)
        row.append(tile)

        let name = players[current].name
        if !openedAtTurnStart && !meldsCreatedThisTurn.isEmpty {
            players[current].opened = true
            log.append(L("log.opened", name))
        }
        players[current].turnsTaken += 1

        if players[current].hand.isEmpty {
            log.append(L("log.closed", name, tile.label))
            endHand(closer: current, closingTile: tile)
            return
        }
        if stock.isEmpty {
            log.append(L("log.stockEmpty"))
            endHand(closer: nil, closingTile: nil)
            return
        }
        current = (current + 1) % players.count
        phase = .draw
        beginTurnBookkeeping()
    }

    // MARK: - Final de mână

    mutating func endHand(closer: Int?, closingTile: Tile?) {
        phase = .handOver
        var results: [PlayerResult] = []
        for p in players {
            let melded = melds.reduce(0) { $0 + $1.finalScore(for: p.id) }
            let inHand = p.hand.reduce(0) { $0 + $1.handPenalty }
            var bonus = 0
            var notes: [String] = []
            var total: Int

            if p.id == closer {
                bonus += 100
                total = melded + 100
                notes.append(L("note.closed"))
                if let t = closingTile, t.isJoker || t.number == 1 {
                    total *= 2
                    notes.append(t.isJoker ? L("note.closedJoker") : L("note.closedOne"))
                }
            } else if !p.opened {
                total = -100
                notes.append(L("note.notOpened"))
            } else {
                total = melded - inHand
            }
            if p.hasAtuBonus {
                total += 50
                bonus += 50
                notes.append(L("note.atu"))
            }
            if doubleGame {
                total *= 2
                notes.append(L("note.double"))
            }
            results.append(PlayerResult(id: p.id, name: p.name, melded: melded,
                                        inHand: p.opened || p.id == closer ? inHand : 0,
                                        bonus: bonus, total: total, note: notes.joined(separator: ", ")))
        }
        result = HandResult(closer: closer, closingTile: closingTile, doubleGame: doubleGame, players: results)
    }
}
