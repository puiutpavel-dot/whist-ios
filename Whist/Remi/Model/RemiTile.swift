import Foundation

/// Cele patru culori ale pieselor de remi.
enum TileColor: Int, CaseIterable, Hashable, Codable {
    case red, yellow, blue, black

    var name: String {
        switch self {
        case .red: return L("color.red")
        case .yellow: return L("color.yellow")
        case .blue: return L("color.blue")
        case .black: return L("color.black")
        }
    }
}

/// Identifică o piesă numerotată după culoare și număr (există câte două copii din fiecare).
struct TileKey: Hashable, Codable {
    let color: TileColor
    let number: Int
}

/// O piesă de remi. `color == nil` înseamnă Joker (Joly).
struct Tile: Identifiable, Hashable, Codable {
    let id: Int
    let color: TileColor?
    let number: Int

    var isJoker: Bool { color == nil }

    var key: TileKey? {
        guard let color else { return nil }
        return TileKey(color: color, number: number)
    }

    /// Valoarea cu care se scade piesa rămasă pe tablă la final.
    var handPenalty: Int {
        if isJoker { return 50 }
        if number == 1 { return 25 }
        return number >= 10 ? 10 : 5
    }

    /// Valoare folosită de AI la alegerea piesei aruncate.
    var nominalValue: Int {
        if isJoker { return 50 }
        if number == 1 { return 10 }
        return number >= 10 ? 10 : 5
    }

    var label: String {
        guard let color else { return L("tile.joker") }
        return L("tile.label", number, color.name)
    }

    /// Setul complet: 104 piese numerotate (2 serii × 4 culori × 13) + 2 Jokeri.
    static func fullSet() -> [Tile] {
        var tiles: [Tile] = []
        var id = 0
        for _ in 0..<2 {
            for color in TileColor.allCases {
                for n in 1...13 {
                    tiles.append(Tile(id: id, color: color, number: n))
                    id += 1
                }
            }
        }
        tiles.append(Tile(id: id, color: nil, number: 0)); id += 1
        tiles.append(Tile(id: id, color: nil, number: 0))
        return tiles
    }
}

struct RuleError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}
