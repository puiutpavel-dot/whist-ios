import SwiftUI

/// Capturile pentru App Store se fac în simulator cu: `xcrun simctl launch booted <bundle> -shot N`.
/// Fără acest argument, aplicația pornește normal.
@MainActor
enum ScreenshotMode {
    static var shot: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-shot"), i + 1 < args.count else { return nil }
        return Int(args[i + 1])
    }

    static func prepareHomeStats() {
        let d = UserDefaults.standard
        d.set(27, forKey: "gamesPlayed")
        d.set(11, forKey: "gamesWon")
        d.set(146, forKey: "bestScore")
        d.set(4, forKey: "players")
        d.set(312, forKey: "contractsMade")
        d.set(431, forKey: "contractsTotal")
    }

    /// Construiește un joc adus în starea potrivită capturii N.
    static func engine(for shot: Int) -> GameEngine {
        let settings = GameSettings(playerCount: 4, format: .oneEightOne, streakBonus: true, forehead: true, speed: 1)
        for _ in 0..<60 {
            let e = GameEngine(settings: settings)
            e.frozen = true
            let ok: Bool
            switch shot {
            case 2:   // licitația ta, mână cu atu și multe cărți
                ok = e.fastForward { $0.phase == .bidding && $0.handSize == 6 && $0.current == $0.human && $0.trump != nil && $0.dealer != $0.human }
            case 3:   // levată câștigată de tine
                ok = e.fastForward { $0.phase == .trickEnd && $0.handSize >= 6 && $0.trickWinner == $0.human && $0.trump != nil
                    && $0.trick.contains { $0.card.rank >= 12 } }
            case 4:   // rezumatul unei mâini reușite
                ok = e.fastForward { $0.phase == .handEnd && $0.handIndex >= 9 && ($0.history.last?.entries[$0.human].made ?? false)
                    && ($0.history.last?.entries[$0.human].bid ?? 0) >= 2 }
            case 5:   // tabela de scor la jumătatea jocului
                ok = e.fastForward { $0.phase == .handEnd && $0.handIndex >= 13 }
            case 6:   // cartea pe frunte
                ok = e.fastForward { $0.isForeheadHand && $0.phase == .bidding && $0.current == $0.human && $0.players[$0.human].bid == nil
                    && $0.players.contains { $0.bid != nil } }
            case 8:   // contorul de cărți ieșite, la jumătatea unei mâini cu atu
                ok = e.fastForward { $0.phase == .playing && $0.current == $0.human && $0.handSize >= 6
                    && $0.trump != nil && $0.playedThisHand.count >= $0.n * 2 }
            case 7:   // victorie
                ok = e.fastForward { $0.phase == .gameOver }
                    && e.players[e.human].score == e.players.map(\.score).max()
            default:
                ok = true
            }
            if ok { return e }
        }
        return GameEngine(settings: settings)
    }

    // MARK: Test de anduranță (doar în CI): `-stress`

    static var isStress: Bool { ProcessInfo.processInfo.arguments.contains("-stress") }

    /// Joacă multe partide în toate configurațiile și verifică regulile la fiecare pas.
    /// Rezultatul se scrie în Documents/stress.txt („STRESS OK …” sau „STRESS FAIL …”).
    static func runStress() {
        var games = 0, steps = 0
        var errors: [String] = []
        func fail(_ s: String) { if errors.count < 20 { errors.append(s) } }
        for players in 3...6 {
            for format in GameFormat.allCases {
                for forehead in [true, false] {
                    for _ in 0..<40 {
                        var settings = GameSettings()
                        settings.playerCount = players
                        settings.format = format
                        settings.forehead = forehead
                        settings.streakBonus = Bool.random()
                        let e = GameEngine(settings: settings)
                        var lastHistory = 0
                        let done = e.fastForward(maxSteps: 200_000) { g in
                            steps += 1
                            // ce face interfața la fiecare redesenare, inclusiv în tranziții
                            _ = g.coachBid(); _ = g.coachCard(); _ = g.humanContractStats
                            _ = g.legalCards(for: g.human); _ = g.isForeheadHand
                            if g.isForeheadHand {
                                _ = BotAI.foreheadBid(for: g.human, engine: g, allowed: g.allowedBids(for: g.human))
                            }
                            if g.phase == .playing && g.legalCards(for: g.current).isEmpty {
                                fail("fără cărți legale: mâna \(g.handIndex), jucător \(g.current)")
                            }
                            if g.history.count != lastHistory {
                                lastHistory = g.history.count
                                if let r = g.history.last {
                                    let bids = r.entries.map(\.bid).reduce(0, +)
                                    let tricks = r.entries.map(\.tricks).reduce(0, +)
                                    if bids == r.size { fail("suma licitațiilor = \(r.size) la mâna \(r.id)") }
                                    if tricks != r.size { fail("levate \(tricks) ≠ \(r.size) la mâna \(r.id)") }
                                }
                            }
                            return g.phase == .gameOver
                        }
                        games += 1
                        if !done { fail("joc neterminat: \(players)p \(format.rawValue) frunte=\(forehead), mâna \(e.handIndex), faza \(e.phase)") }
                        if e.history.count != e.handSizes.count { fail("istoric \(e.history.count) ≠ \(e.handSizes.count)") }
                    }
                }
            }
        }
        let text = errors.isEmpty
            ? "STRESS OK: \(games) jocuri, \(steps) pași"
            : "STRESS FAIL: \(games) jocuri\n" + errors.joined(separator: "\n")
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("stress.txt")
        try? text.write(to: url, atomically: true, encoding: .utf8)
        print(text)
    }
}
