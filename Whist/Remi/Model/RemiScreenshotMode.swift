import SwiftUI

/// Capturile pentru App Store se fac în simulator cu:
/// `xcrun simctl launch booted <bundle> -shot N -AppleLanguages "(de)"`.
/// Fără argumentul -shot, aplicația pornește normal.
///  1 meniul · 2 masa în plin joc · 3 prima etalare sugerată · 4 rezultatul unei mâini · 5 regulile
@MainActor
enum RemiShots {
    static var shot: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-shot"), i + 1 < args.count else { return nil }
        return Int(args[i + 1])
    }

    private static var names: [String] {
        [L("name.you"), L("bot.1"), L("bot.2"), L("bot.3")]
    }

    static func engine(for shot: Int) -> RemiEngine {
        switch shot {
        case 3: return openingEngine()
        case 4: return resultEngine()
        default: return midGameEngine()
        }
    }

    /// Simulează ture până când condiția e îndeplinită sau mâna se termină.
    private static func fastForward(_ s: inout RemiState, maxTurns: Int = 300,
                                    until cond: (RemiState) -> Bool) -> Bool {
        for _ in 0..<maxTurns {
            if cond(s) { return true }
            if s.phase == .handOver { return false }
            RemiBot.playTurn(&s)
        }
        return cond(s)
    }

    private static func newState() -> RemiState {
        RemiState.newHand(names: names, humanIndex: 0, starter: Int.random(in: 0..<4))
    }

    /// Rândul tău, după tragere: masa plină de formații, tu etalat, cu o piesă de lipit.
    private static func midGameEngine() -> RemiEngine {
        var fallback: RemiState?
        for _ in 0..<40 {
            var s = newState()
            let ok = fastForward(&s) { st in
                st.current == 0 && st.phase == .draw && st.players[0].opened
                    && st.melds.count >= 6 && st.players[0].hand.count >= 6
                    && st.melds.contains { $0.jokerCount > 0 }
            }
            guard ok else { continue }
            try? s.drawFromStock()
            if fallback == nil { fallback = s }
            let canAdd = s.players[0].hand.contains { t in s.melds.contains { $0.adding(t, by: 0, reused: false) != nil } }
            if canAdd { return suggesting(s) }
        }
        if let f = fallback { return suggesting(f) }
        var s = newState()
        try? s.drawFromStock()
        return RemiEngine(frozenState: s, hands: 3, handNumber: 2, totals: [0, 0, 0, 0])
    }

    /// Rândul tău, încă neetalat, cu o etalare de 45+ puncte gata selectată.
    private static func openingEngine() -> RemiEngine {
        for _ in 0..<40 {
            var s = newState()
            var found = false
            while !found {
                let reached = fastForward(&s) { st in
                    st.current == 0 && st.phase == .draw && !st.isFirstRound && !st.players[0].opened
                        && st.melds.count >= 3
                }
                guard reached else { break }
                var t = s
                try? t.drawFromStock()
                let plan = MeldFinder.bestPlan(hand: t.players[0].hand, maxTiles: t.players[0].hand.count - 1,
                                               opening: true, mustUse: nil)
                if !plan.isEmpty {
                    s = t
                    found = true
                } else {
                    RemiBot.playTurn(&s)
                }
            }
            if found { return suggesting(s) }
        }
        return midGameEngine()
    }

    /// Ecranul de final al unei mâini pe care ai închis-o tu.
    private static func resultEngine() -> RemiEngine {
        var last: RemiState?
        for _ in 0..<60 {
            var s = newState()
            _ = fastForward(&s, maxTurns: 400) { $0.phase == .handOver }
            guard s.phase == .handOver, let r = s.result else { continue }
            last = s
            if r.closer == 0 { break }
        }
        let s = last ?? newState()
        let totals = s.result?.players.map { $0.total + 180 } ?? [0, 0, 0, 0]
        return RemiEngine(frozenState: s, hands: 3, handNumber: 2, totals: totals)
    }

    private static func suggesting(_ s: RemiState) -> RemiEngine {
        let e = RemiEngine(frozenState: s, hands: 3, handNumber: 2, totals: [235, 140, -60, 95])
        e.suggest()
        e.message = nil
        return e
    }
}
