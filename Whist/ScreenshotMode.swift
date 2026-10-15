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
}
