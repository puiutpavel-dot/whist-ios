import Foundation

// MARK: - Cards

enum Suit: Int, CaseIterable, Hashable {
    case spades, hearts, diamonds, clubs

    var symbol: String {
        switch self {
        case .spades: return "♠"
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .clubs: return "♣"
        }
    }

    var name: String {
        switch self {
        case .spades: return "Pică"
        case .hearts: return "Inimă roșie"
        case .diamonds: return "Caro"
        case .clubs: return "Treflă"
        }
    }

    var isRed: Bool { self == .hearts || self == .diamonds }
}

struct Card: Identifiable, Hashable {
    let suit: Suit
    /// 2...14 (11 = J, 12 = Q, 13 = K, 14 = A)
    let rank: Int

    var id: Int { suit.rawValue * 100 + rank }

    var rankLabel: String {
        switch rank {
        case 14: return "A"
        case 13: return "K"
        case 12: return "Q"
        case 11: return "J"
        default: return "\(rank)"
        }
    }

    var label: String { rankLabel + suit.symbol }
}

enum Deck {
    /// 8 cărți pentru fiecare jucător: cele mai mari 2×N valori din fiecare culoare.
    /// 3 jucători → A…9 (24 cărți), 4 → A…7 (32), 6 → A…3 (48).
    static func lowestRank(players: Int) -> Int { 15 - 2 * players }

    static func make(players: Int) -> [Card] {
        let low = lowestRank(players: players)
        var cards: [Card] = []
        for suit in Suit.allCases {
            for rank in low...14 { cards.append(Card(suit: suit, rank: rank)) }
        }
        return cards
    }
}

// MARK: - Settings

enum GameFormat: String, CaseIterable, Identifiable {
    case oneEightOne = "1-8-1"
    case eightOneEight = "8-1-8"
    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .oneEightOne: return "Începe cu mâini de o carte"
        case .eightOneEight: return "Începe cu mâini de 8 cărți"
        }
    }
}

struct GameSettings {
    var playerCount: Int = 4
    var format: GameFormat = .oneEightOne
    var streakBonus: Bool = true
    var forehead: Bool = true
    var coach: Bool = true
    var speed: Double = 1.0

    static func handSizes(players n: Int, format: GameFormat) -> [Int] {
        let ones = Array(repeating: 1, count: n)
        let eights = Array(repeating: 8, count: n)
        let up = Array(2...7)
        let down = Array(up.reversed())
        switch format {
        case .oneEightOne: return ones + up + eights + down + ones
        case .eightOneEight: return eights + down + ones + up + eights
        }
    }
}

// MARK: - Players & records

struct Player: Identifiable {
    let id: Int
    var name: String
    var isHuman: Bool
    var hand: [Card] = []
    var bid: Int? = nil
    var tricks: Int = 0
    var score: Int = 0
    /// >0 contracte reușite consecutive, <0 ratate consecutive
    var streak: Int = 0
}

struct PlayedCard: Identifiable, Hashable {
    let player: Int
    let card: Card
    var id: Int { card.id }
}

struct HandRecord: Identifiable {
    struct Entry {
        let bid: Int
        let tricks: Int
        let delta: Int
        let bonus: Int
        let total: Int
        var made: Bool { bid == tricks }
    }
    let id: Int
    let size: Int
    let trump: Card?
    let dealer: Int
    let entries: [Entry]
}
