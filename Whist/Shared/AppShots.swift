import SwiftUI

/// Capturile din App Store (`-shot N -AppleLanguages "(de)"`) și testul de anduranță (`-stress`).
/// 1 meniul · 2 Whist: licitația cu sfat · 3 Whist: levată · 4 Remi: masa · 5 Remi: etalare sugerată
/// 6 Renț: alegerea jocului · 7 Renț: levată la Dame · 8 Renț: rândurile din Renț
/// 9 Avioane: hangarul · 10 Avioane: bătălia
@MainActor
enum AppShots {
    static var shot: Int? { WhistShots.shot }

    @ViewBuilder
    static func screen(for shot: Int) -> some View {
        switch shot {
        case 2: GameView(engine: WhistShots.engine(for: 2))
        case 3: GameView(engine: WhistShots.engine(for: 3))
        case 4: RemiShotScreen(shot: 2)
        case 5: RemiShotScreen(shot: 3)
        case 6, 7, 8: RentzGameView(engine: rentzEngine(for: shot))
        case 9, 10: AvioaneShotScreen(scene: shot == 9 ? "hangar" : "battle")
        case 11, 12: AvioaneShotScreen(scene: shot == 11 ? "home" : "victory") // doar pentru verificări
        case 13: CastelGameView(engine: castelEngine())
        case 14:
            let e = castelEngine()
            CastelGameView(engine: e, selected: e.legalActions(for: e.human).first { if case .attack = $0 { return true }; return false }?.card)
        default: HubView()
        }
    }

    /// Castelul la mijlocul rundei: tu la rând, cu o minge în mână și castele pe jumătate ridicate.
    static func castelEngine() -> CastelEngine {
        for _ in 0..<200 {
            let e = CastelEngine(players: 3)
            let ok = e.fastForward { g in
                g.phase == .playing && g.current == g.human
                    && g.players[g.human].castle.count >= 3
                    && g.players.dropFirst().allSatisfy { $0.castle.count >= 2 }
                    && g.legalActions(for: g.human).contains { if case .attack = $0 { return true }; return false }
            }
            if ok { return e }
        }
        return CastelEngine(players: 3)
    }

    static func rentzEngine(for shot: Int) -> RentzEngine {
        for _ in 0..<80 {
            let e = RentzEngine(players: 4)
            let ok: Bool
            switch shot {
            case 6:
                ok = e.fastForward { $0.phase == .choosing && $0.chooser == $0.human && $0.dealIndex >= 4 }
            case 7:
                ok = e.fastForward { g in
                    g.phase == .playing && (g.game == .queens || g.game == .totals) && g.current == g.human
                        && g.trick.count >= 2 && g.players[g.human].hand.count >= 5
                }
            default:
                ok = e.fastForward { g in
                    g.phase == .playing && g.game == .rentz && g.current == g.human && g.rows.count >= 3
                        && g.players[g.human].hand.count >= 4 && !g.legalCards(for: g.human).isEmpty
                }
            }
            if ok { return e }
        }
        return RentzEngine(players: 4)
    }

    // MARK: Test de anduranță

    static func runStress() {
        var lines = [WhistShots.runStress(), rentzStress(), remiStress(), avioaneStress(), castelStress()]
        let ok = lines.allSatisfy { $0.contains(" OK") }
        lines.insert(ok ? "STRESS OK" : "STRESS FAIL", at: 0)
        let text = lines.joined(separator: "\n")
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("stress.txt")
        try? text.write(to: url, atomically: true, encoding: .utf8)
        print(text)
    }

    private static func rentzStress() -> String {
        var games = 0, steps = 0
        var errors: [String] = []
        func fail(_ s: String) { if errors.count < 20 { errors.append(s) } }
        for players in 3...6 {
            for _ in 0..<30 {
                let e = RentzEngine(players: players)
                let done = e.fastForward(maxSteps: 100_000) { g in
                    steps += 1
                    _ = RentzBot.chooseGameTip(engine: g)
                    _ = g.legalCards(for: g.human)
                    if g.phase == .playing, g.game != .rentz, g.legalCards(for: g.current).isEmpty {
                        fail("fără cărți legale: joc \(g.dealIndex)")
                    }
                    return g.phase == .gameOver
                }
                games += 1
                if !done { fail("neterminat: \(players)p, jocul \(e.dealIndex), \(e.game?.rawValue ?? "-")") }
                if e.history.count != e.totalDeals { fail("istoric \(e.history.count) ≠ \(e.totalDeals)") }
                for p in e.players where p.chosen.count != RentzGame.allCases.count {
                    fail("\(p.name) a ales \(p.chosen.count) jocuri")
                }
                for r in e.history where r.game == .rentz {
                    if r.deltas.sorted(by: >) != (1...players).map({ RentzScore.rentzPlace($0, of: players) }) {
                        fail("Renț: locuri greșite \(r.deltas)")
                    }
                }
                for r in e.history where r.game == .tricks {
                    let sum = r.deltas.reduce(0, +)
                    if sum != 8 * RentzScore.trickMinus { fail("Levate: suma \(sum)") }
                }
            }
        }
        return errors.isEmpty ? "RENTZ OK: \(games) jocuri, \(steps) pași"
                              : "RENTZ FAIL: \(games) jocuri\n" + errors.joined(separator: "\n")
    }

    /// Avioane: botul trage pe table aleatorii până doboară toate avioanele (fără tragere de două ori, max 100 de focuri).
    private static func avioaneStress() -> String {
        var games = 0, shots = 0
        var errors: [String] = []
        for diff in Difficulty.allCases {
            for _ in 0..<60 {
                let planes = Board.randomLayout()
                if !Board.invalidPlaneIDs(planes).isEmpty && errors.count < 20 { errors.append("așezare invalidă") }
                var board = Board(planes: planes)
                var n = 0
                while !board.allDestroyed && n < 100 {
                    let c = Bot.chooseTarget(on: board, difficulty: diff)
                    if case .alreadyShot = board.receiveShot(at: c) {
                        if errors.count < 20 { errors.append("\(diff.rawValue): a tras de două ori în \(c.row),\(c.col)") }
                        break
                    }
                    n += 1
                }
                if !board.allDestroyed && errors.count < 20 { errors.append("\(diff.rawValue): joc neterminat după \(n) focuri") }
                games += 1; shots += n
            }
        }
        return errors.isEmpty ? "AVIOANE OK: \(games) jocuri, \(shots) focuri"
                              : "AVIOANE FAIL: \(games) jocuri\n" + errors.joined(separator: "\n")
    }

    private static func castelStress() -> String {
        var games = 0, rounds = 0
        var errors: [String] = []
        func fail(_ s: String) { if errors.count < 20 { errors.append(s) } }
        for players in 2...4 {
            for diff in CastelDifficulty.allCases {
                for _ in 0..<20 {
                    let e = CastelEngine(players: players, difficulty: diff)
                    let done = e.fastForward(maxSteps: 60_000) { g in
                        let cards = g.deck.count + g.discardPile.count
                            + g.players.reduce(0) { $0 + $1.hand.count + $1.castle.count }
                        if cards != 52 { fail("\(cards) cărți în joc în loc de 52") }
                        for p in g.players {
                            for (i, c) in p.castle.enumerated() where !CastelRules.isQueen(c) && CastelRules.value(c) != i + 1 {
                                fail("\(p.name): nivelul \(i + 1) e \(c.label)")
                            }
                            if p.castle.count > CastelRules.levels { fail("castel prea înalt") }
                        }
                        if g.phase == .playing && g.legalActions(for: g.current).isEmpty { fail("fără mutări pentru \(g.current)") }
                        return g.phase == .gameOver
                    }
                    games += 1; rounds += e.history.count
                    if !done { fail("partidă neterminată: \(players)p") }
                    if !e.players.contains(where: { $0.score >= CastelRules.targetScore }) { fail("nimeni n-a ajuns la \(CastelRules.targetScore)") }
                }
            }
        }
        return errors.isEmpty ? "CASTEL OK: \(games) partide, \(rounds) runde"
                              : "CASTEL FAIL: \(games) partide\n" + errors.joined(separator: "\n")
    }

    private static func remiStress() -> String {
        var hands = 0, turns = 0
        var errors: [String] = []
        for players in 2...4 {
            let names = Array(["Tu", "A", "B", "C"].prefix(players))
            for _ in 0..<40 {
                var s = RemiState.newHand(names: names, humanIndex: 0, starter: Int.random(in: 0..<players))
                var t = 0
                while s.phase != .handOver && t < 2000 {
                    RemiBot.playTurn(&s)
                    t += 1
                }
                turns += t
                hands += 1
                if s.phase != .handOver && errors.count < 20 { errors.append("mână neterminată (\(players)p)") }
            }
        }
        return errors.isEmpty ? "REMI OK: \(hands) mâini, \(turns) ture"
                              : "REMI FAIL: \(hands) mâini\n" + errors.joined(separator: "\n")
    }
}

/// Ecranele Remi pentru capturi (păstrează motorul pe durata ecranului).
private struct RemiShotScreen: View {
    @StateObject private var engine: RemiEngine
    init(shot: Int) { _engine = StateObject(wrappedValue: RemiShots.engine(for: shot)) }
    var body: some View { RemiGameView(engine: engine) }
}

/// Ecranele Avioane pentru capturi: modelul pornește direct pe scena cerută.
private struct AvioaneShotScreen: View {
    init(scene: String) { GameViewModel.forcedScene = scene }
    var body: some View { AvioaneRootView() }
}
