import Foundation

// MARK: - Bot (hunt & target pe bază de densitate)

/// Botul vede doar ce ar vedea un jucător real: marcajele de pe tablă și câte avioane mai sunt.
/// Nu „trișează” uitându-se la poziția avioanelor.
enum Bot {
    static func chooseTarget(on board: Board, difficulty: Difficulty) -> Coord {
        let unknown = Board.allCoords.filter { board.marks[$0] == nil }
        guard let fallback = unknown.randomElement() else { return Coord(row: 0, col: 0) }

        switch difficulty {
        case .easy:
            return fallback
        case .medium:
            if Double.random(in: 0...1) < 0.4 { return fallback }
        case .hard:
            break
        }

        // Pentru fiecare poziție posibilă a unui avion, verificăm dacă e compatibilă cu ce știm.
        var score: [Coord: Double] = [:]
        for coord in Board.allCoords {
            for o in Orientation.allCases {
                let p = Plane(id: -1, head: coord, orientation: o)
                let cells = p.cells
                guard cells.allSatisfy(\.isValid) else { continue }
                // Un bot deja lovit ar fi însemnat avion distrus, deci botul trebuie să fie necunoscut.
                guard board.marks[p.head] == nil else { continue }

                var hitsCovered = 0
                var blocked = false
                for cell in cells {
                    switch board.marks[cell] {
                    case .miss?, .destroyed?: blocked = true
                    case .hit?: hitsCovered += 1
                    case nil: break
                    }
                    if blocked { break }
                }
                if blocked { continue }

                // Pozițiile care explică loviturile existente contează mult mai mult.
                let weight = hitsCovered == 0 ? 1.0 : pow(30.0, Double(hitsCovered))
                // Botul valorează dublu: o lovitură acolo doboară avionul instant.
                score[p.head, default: 0] += weight * 2.5
                for cell in cells where cell != p.head && board.marks[cell] == nil {
                    score[cell, default: 0] += weight
                }
            }
        }

        let ranked = unknown.map { ($0, score[$0] ?? 0) }
        guard let best = ranked.map(\.1).max(), best > 0 else { return fallback }
        let top = ranked.filter { $0.1 >= best * 0.999 }.map(\.0)
        return top.randomElement() ?? fallback
    }
}

// MARK: - Efecte vizuale pe grilă

/// O animație pe o grilă: proiectilul în zbor sau impactul (apă / explozie / avion doborât).
struct ShotFX: Identifiable, Equatable {
    enum Kind: Equatable {
        case launch
        case impact(NetResult)
    }
    let id = UUID()
    let coord: Coord
    let kind: Kind
    var cells: [Coord] = [] // pentru avion doborât: toate pătrățelele lui
}

// MARK: - Stările vizuale ale unei căsuțe

enum ShipState { case normal, selected, invalid }

enum CellStyle: Equatable {
    case water
    case ship(head: Bool, state: ShipState)   // avionul tău (sau în hangar)
    case shipHit(head: Bool)                   // avionul tău, lovit
    case miss                                  // 🌊
    case hit                                   // 💥
    case wreck(head: Bool)                     // ✈️ doborât
    case ghost(head: Bool)                     // avion inamic dezvăluit la final
}

