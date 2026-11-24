import SwiftUI

/// Capturile din App Store (`-shot N -AppleLanguages "(de)"`) și testul de anduranță (`-stress`).
/// 1 meniul · 2 Whist: licitația cu sfat · 3 Whist: levată · 4 Remi: masa · 5 Remi: etalare sugerată
/// 6 Renț: alegerea jocului · 7 Renț: levată la Dame · 8 Renț: rândurile din Renț
/// 9 Avioane: hangarul · 10 Avioane: bătălia · 13, 14 Castelul · 17 Macao: masa · 18 Macao: cărți alese · 19 meniul Macao · 20 Canasta: masa · 21 meniul Canasta
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
        case 15: IdeaView()                     // doar pentru verificări
        case 16: RentzMenuView()                // doar pentru verificări
        case 17: MacaoGameView(engine: macaoEngine(pending: true))
        case 18:
            let e = macaoEngine(pending: false)
            MacaoGameView(engine: e, selected: macaoPick(e))
        case 19: MacaoMenuView()                // doar pentru verificări
        case 20:
            let e = canastaEngine()
            CanastaGameView(engine: e, selected: canastaPick(e))
        case 21: CanastaMenuView()              // doar pentru verificări
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

    /// Canasta în patru, la mijlocul rundei: e rândul tău, ai tras, iar pe masă sunt etalări de ambele părți.
    static func canastaEngine() -> CanastaEngine {
        for _ in 0..<200 {
            let e = CanastaEngine(settings: CanastaSettings(players: 4))
            let ok = e.fastForward { g in
                guard g.phase == .playing, g.current == g.human, g.stage == .play, !g.turnMelded else { return false }
                guard (7...12).contains(g.players[g.human].hand.count) else { return false }
                return g.melds[0].count >= 3 && g.melds[1].count >= 2 && g.melds[0].contains(where: \.isCanasta)
                    && !canastaPick(g).isEmpty
            }
            if ok { return e }
        }
        return CanastaEngine(settings: CanastaSettings(players: 4))
    }

    /// Cărțile pe care le-ai etala acum.
    static func canastaPick(_ e: CanastaEngine) -> [CanastaCard] {
        guard e.phase == .playing, e.stage == .play, e.current == e.human else { return [] }
        return CanastaBot.bestMeld(for: e.human, engine: e)?.cards ?? []
    }

    /// Macao la mijlocul rundei: tu la rând; cu `pending`, ai de răspuns la un 2 sau 3 și ai cu ce.
    static func macaoEngine(pending: Bool) -> MacaoEngine {
        for _ in 0..<300 {
            let e = MacaoEngine(settings: MacaoSettings(players: 4))
            let ok = e.fastForward { g in
                guard g.phase == .playing, g.current == g.human, g.turnCount >= 6 else { return false }
                let hand = g.players[g.human].hand
                guard (5...8).contains(hand.count), g.players.dropFirst().allSatisfy({ (2...7).contains($0.hand.count) }) else { return false }
                if pending { return g.pendingDraw > 0 && !g.playable(for: g.human).isEmpty }
                return g.pendingDraw == 0 && g.pendingSkip == 0 && macaoPick(g).count >= 2
            }
            if ok { return e }
        }
        return MacaoEngine(settings: MacaoSettings(players: 4))
    }

    /// Două cărți de aceeași valoare care pot fi puse împreună (fără cele care cer alegerea culorii).
    static func macaoPick(_ e: MacaoEngine) -> [Card] {
        let hand = e.players[e.human].hand
        for first in e.playable(for: e.human) where !MacaoRules.isJoker(first) && !e.isChanger(first) {
            let same = hand.filter { $0.rank == first.rank && $0 != first }
            if !same.isEmpty { return [first] + same }
        }
        return []
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
        var lines = [WhistShots.runStress(), rentzStress(), remiStress(), avioaneStress(), castelStress(), macaoStress(), canastaStress()]
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
        let variants = RentzScoring.Style.allCases.flatMap { st in
            [RentzGame.whist, .totalsPlus].map { RentzScoring(style: st, eighth: $0) }
        }
        for players in 3...6 {
            for k in 0..<32 {
                let e = RentzEngine(players: players, scoring: variants[k % variants.count])
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
                for p in e.players where p.chosen.count != e.games.count {
                    fail("\(p.name) a ales \(p.chosen.count) jocuri")
                }
                for r in e.history where r.game == .rentz {
                    if r.deltas.sorted(by: >) != (1...players).map({ RentzScore.rentzPlace($0, of: players) }) {
                        fail("Renț: locuri greșite \(r.deltas)")
                    }
                }
                for r in e.history where r.game == .tricks || r.game == .whist {
                    let sum = r.deltas.reduce(0, +)
                    let want = 8 * (r.game == .tricks ? RentzScore.trickMinus : RentzScore.trickPlus)
                    if sum != want { fail("\(r.game.rawValue): suma \(sum) ≠ \(want)") }
                }
                for r in e.history where r.game == .totals || r.game == .totalsPlus {
                    let s = e.scoring, suit = 15 - e.low
                    let full = s.kingOfHearts + 4 * s.queen + suit * s.diamond + 8 * s.trickMinus
                    let sum = r.deltas.reduce(0, +)
                    if sum != (r.game == .totals ? full : -full) { fail("\(r.game.rawValue): suma \(sum)") }
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

    private static func macaoStress() -> String {
        var games = 0, rounds = 0, steps = 0
        var errors: [String] = []
        func fail(_ s: String) { if errors.count < 20 { errors.append(s) } }
        for players in 2...4 {
            for variant in MacaoVariant.allCases {
                for diff in MacaoDifficulty.allCases {
                    for k in 0..<12 {
                        let target = [1, 3, 5][k % 3]
                        let e = MacaoEngine(settings: MacaoSettings(players: players, variant: variant, targetWins: target, difficulty: diff))
                        let done = e.fastForward(maxSteps: 400_000) { g in
                            steps += 1
                            let cards = g.deck.count + g.discardPile.count + g.players.reduce(0) { $0 + $1.hand.count }
                            if cards != MacaoRules.deckSize { fail("\(cards) cărți în joc în loc de \(MacaoRules.deckSize)") }
                            if g.discardPile.isEmpty { fail("teanc gol") }
                            if g.pendingDraw > 0 && g.pendingSkip > 0 { fail("pedeapsă dublă") }
                            if g.phase == .playing {
                                if g.players[g.current].waits > 0 { fail("la rând e cineva care stă") }
                                if g.players.contains(where: { $0.hand.isEmpty }) { fail("mână goală în timpul rundei") }
                                for c in g.playable(for: g.current) where !g.isLegal([c], for: g.current) { fail("carte permisă, dar refuzată") }
                                if g.current == g.human, case .play(let cs, let suit) = MacaoBot.choose(for: g.human, engine: g, mistakes: false) {
                                    if !g.isLegal(cs, for: g.human) { fail("sfat nepermis") }
                                    if g.needsSuit(cs) && suit == nil { fail("sfat fără culoare") }
                                }
                            }
                            return g.phase == .gameOver
                        }
                        games += 1; rounds += e.history.count
                        if !done { fail("partidă neterminată: \(players)p") }
                        if e.players.map(\.roundsWon).max() != target { fail("nimeni n-a ajuns la \(target) runde") }
                    }
                }
            }
        }
        return errors.isEmpty ? "MACAO OK: \(games) partide, \(rounds) runde, \(steps) mutări"
                              : "MACAO FAIL: \(games) partide\n" + errors.joined(separator: "\n")
    }

    private static func canastaStress() -> String {
        var games = 0, hands = 0, steps = 0, outs = 0
        var errors: [String] = []
        func fail(_ s: String) { if errors.count < 20 { errors.append(s) } }
        for players in 2...4 {
            for diff in MacaoDifficulty.allCases {
                for k in 0..<6 {
                    let target = [1500, 3000, 5000][k % 3]
                    let e = CanastaEngine(settings: CanastaSettings(players: players, target: target, difficulty: diff))
                    let done = e.fastForward(maxSteps: 400_000) { g in
                        steps += 1
                        let melded = g.melds.reduce(0) { $0 + $1.reduce(0) { $0 + $1.cards.count } }
                        let cards = g.stock.count + g.pile.count + melded + g.redThrees.reduce(0) { $0 + $1.count }
                            + g.players.reduce(0) { $0 + $1.hand.count }
                        if cards != CanastaRules.deckSize { fail("\(cards) cărți în joc în loc de \(CanastaRules.deckSize)") }
                        for t in 0..<g.teamCount {
                            for m in g.melds[t] {
                                if m.naturals < 2 || m.wilds > CanastaRules.maxWilds || m.cards.count < 3 { fail("etalare greșită la \(m.rank)") }
                                if m.cards.contains(where: { !$0.isWild && $0.rank != m.rank }) { fail("etalare amestecată") }
                            }
                            if Set(g.melds[t].map(\.rank)).count != g.melds[t].count { fail("două etalări de aceeași valoare") }
                        }
                        if g.players.contains(where: { $0.hand.contains(where: \.isRedThree) }) { fail("trei roșu în mână") }
                        if g.phase == .playing {
                            if g.players[g.current].hand.isEmpty { fail("la rând e cineva fără cărți") }
                            if g.stage == .play, g.current == g.human,
                               case .meld(let cs, let r) = CanastaBot.next(for: g.human, engine: g, mistakes: false),
                               g.meldRank(for: cs, onto: r, by: g.human) == nil { fail("sfat nepermis") }
                        }
                        return g.phase == .gameOver
                    }
                    games += 1; hands += e.history.count
                    outs += e.history.filter { $0.out != nil }.count
                    if !done { fail("partidă neterminată: \(players)p") }
                    for h in e.history {
                        if let o = h.out, h.teams[e.team(of: o)].canastaBonus == 0 {
                            fail("închidere fără canastă")
                        }
                    }
                }
            }
        }
        return errors.isEmpty ? "CANASTA OK: \(games) partide, \(hands) runde (\(outs) închise), \(steps) pași"
                              : "CANASTA FAIL: \(games) partide\n" + errors.joined(separator: "\n")
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
