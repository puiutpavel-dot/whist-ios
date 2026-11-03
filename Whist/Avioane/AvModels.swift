import Foundation

// MARK: - Coordonate

/// O căsuță din grila 10×10. `row` 0...9 (afișat 1–10), `col` 0...9 (afișat A–J).
struct Coord: Hashable {
    let row: Int
    let col: Int

    var isValid: Bool {
        (0..<Board.size).contains(row) && (0..<Board.size).contains(col)
    }

    /// Ex: "C-4"
    var label: String { "\(Board.letters[col])-\(row + 1)" }
}

// MARK: - Orientare

/// Direcția în care arată botul avionului.
enum Orientation: Int, CaseIterable, Hashable {
    case up, right, down, left

    var next: Orientation { Orientation(rawValue: (rawValue + 1) % 4)! }

    /// Unghiul pentru simbolul SF "airplane" (care, implicit, arată spre dreapta).
    var symbolAngle: Double {
        switch self {
        case .up: return -90
        case .right: return 0
        case .down: return 90
        case .left: return 180
        }
    }

    /// Transformă un offset definit pentru orientarea „bot în sus” în orientarea curentă.
    func transform(_ dr: Int, _ dc: Int) -> (Int, Int) {
        switch self {
        case .up: return (dr, dc)
        case .down: return (-dr, -dc)
        case .left: return (dc, dr)      // corpul se întinde spre dreapta botului
        case .right: return (-dc, -dr)   // corpul se întinde spre stânga botului
        }
    }
}

// MARK: - Avion

/// Avionul clasic de 10 pătrățele (bot în sus):
///
///         ■            ← botul (carlinga)
///     ■ ■ ■ ■ ■        ← aripile (5)
///         ■            ← corpul
///       ■ ■ ■          ← coada (3)
struct Plane: Identifiable, Hashable {
    let id: Int
    var head: Coord
    var orientation: Orientation

    static let shapeUp: [(Int, Int)] = [
        (0, 0),                                   // bot
        (1, -2), (1, -1), (1, 0), (1, 1), (1, 2), // aripi
        (2, 0),                                   // corp
        (3, -1), (3, 0), (3, 1)                   // coadă
    ]

    var cells: [Coord] {
        Plane.shapeUp.map { dr, dc in
            let (r, c) = orientation.transform(dr, dc)
            return Coord(row: head.row + r, col: head.col + c)
        }
    }
}

// MARK: - Stări

enum CellMark: Equatable {
    case miss       // 🌊 Apă
    case hit        // 💥 Lovit
    case destroyed  // ✈️ Avion doborât
}

enum ShotResult {
    case miss
    case hit
    case destroyed(Plane)
    case alreadyShot
}

enum Difficulty: String, CaseIterable, Identifiable {
    case easy, medium, hard
    var id: Self { self }
    var title: String {
        switch self {
        case .easy: return String(localized: "Easy")
        case .medium: return String(localized: "Medium")
        case .hard: return String(localized: "Hard")
        }
    }
}

// MARK: - Tabla

struct Board {
    static let size = 10
    static let letters = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
    static let allCoords: [Coord] = (0..<size).flatMap { r in (0..<size).map { c in Coord(row: r, col: c) } }

    var planes: [Plane]
    var marks: [Coord: CellMark] = [:]
    var destroyedIDs: Set<Int> = []
    /// Câte avioane are tabla în total (online nu cunoaștem pozițiile, doar numărul).
    var totalPlanes: Int

    /// `totalPlanes` implicit = câte avioane cunoaștem; online (tabla inamică goală) e 3.
    init(planes: [Plane], totalPlanes: Int? = nil) {
        self.planes = planes
        self.totalPlanes = totalPlanes ?? (planes.isEmpty ? 3 : planes.count)
    }

    var remaining: Int { totalPlanes - destroyedIDs.count }
    var allDestroyed: Bool { destroyedIDs.count >= totalPlanes }

    /// Online: aplică pe radar rezultatul primit de la adversar.
    mutating func applyRemote(_ kind: NetResult, at c: Coord, plane: Plane?) {
        switch kind {
        case .miss:
            marks[c] = .miss
        case .hit:
            marks[c] = .hit
        case .destroyed:
            guard let plane else { marks[c] = .hit; return }
            let p = Plane(id: planes.count, head: plane.head, orientation: plane.orientation)
            planes.append(p)
            destroyedIDs.insert(p.id)
            for cell in p.cells { marks[cell] = .destroyed }
        }
    }

    /// Online, la final: adversarul își dezvăluie avioanele rămase.
    mutating func reveal(_ all: [Plane]) {
        for p in all where !planes.contains(where: { $0.head == p.head && $0.orientation == p.orientation }) {
            planes.append(Plane(id: planes.count, head: p.head, orientation: p.orientation))
        }
    }

    func plane(at c: Coord) -> Plane? {
        planes.first { $0.cells.contains(c) }
    }

    /// Aplică regulile: apă / lovit / distrus.
    /// Distrus = botul lovit (instant) SAU toate cele 10 pătrățele lovite.
    mutating func receiveShot(at c: Coord) -> ShotResult {
        guard marks[c] == nil else { return .alreadyShot }
        guard let p = plane(at: c) else {
            marks[c] = .miss
            return .miss
        }
        marks[c] = .hit
        let allHit = p.cells.allSatisfy { marks[$0] != nil }
        if c == p.head || allHit {
            destroyedIDs.insert(p.id)
            for cell in p.cells { marks[cell] = .destroyed } // dezvăluie schița pe radar
            return .destroyed(p)
        }
        return .hit
    }

    // MARK: Validare & plasare

    /// Avioanele care ies din grilă sau se suprapun (atingerea pe laturi e permisă).
    static func invalidPlaneIDs(_ planes: [Plane]) -> Set<Int> {
        var bad = Set<Int>()
        for p in planes where !p.cells.allSatisfy(\.isValid) {
            bad.insert(p.id)
        }
        for i in planes.indices {
            for j in planes.indices where j > i {
                if !Set(planes[i].cells).isDisjoint(with: planes[j].cells) {
                    bad.insert(planes[i].id)
                    bad.insert(planes[j].id)
                }
            }
        }
        return bad
    }

    static func randomLayout(count: Int = 3) -> [Plane] {
        while true {
            var planes: [Plane] = []
            var occupied = Set<Coord>()
            var attempts = 0
            while planes.count < count && attempts < 500 {
                attempts += 1
                let p = Plane(
                    id: planes.count,
                    head: Coord(row: .random(in: 0..<size), col: .random(in: 0..<size)),
                    orientation: Orientation.allCases.randomElement()!
                )
                let cells = p.cells
                guard cells.allSatisfy(\.isValid), occupied.isDisjoint(with: cells) else { continue }
                occupied.formUnion(cells)
                planes.append(p)
            }
            if planes.count == count { return planes }
        }
    }
}

// MARK: - Statistici

struct Stats: Codable {
    var wins = 0
    var losses = 0
    var shots = 0
    var hits = 0
    var onlineWins = 0
    var onlineLosses = 0

    init() {}

    // Citire tolerantă: câmpurile noi lipsă din versiuni vechi pornesc de la 0.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        wins = try c.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        losses = try c.decodeIfPresent(Int.self, forKey: .losses) ?? 0
        shots = try c.decodeIfPresent(Int.self, forKey: .shots) ?? 0
        hits = try c.decodeIfPresent(Int.self, forKey: .hits) ?? 0
        onlineWins = try c.decodeIfPresent(Int.self, forKey: .onlineWins) ?? 0
        onlineLosses = try c.decodeIfPresent(Int.self, forKey: .onlineLosses) ?? 0
    }

    var accuracy: Int {
        shots == 0 ? 0 : Int((Double(hits) / Double(shots) * 100).rounded())
    }

    private static let key = "avioane.stats"

    static func load() -> Stats {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stats = try? JSONDecoder().decode(Stats.self, from: data) else { return Stats() }
        return stats
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Stats.key)
        }
    }
}
