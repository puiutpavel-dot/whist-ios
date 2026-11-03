import Foundation

/// Logica de joc pentru ambele moduri: contra botului și online (Game Center).
@MainActor
final class GameViewModel: ObservableObject {
    /// O singură instanță pentru toată aplicația: invitațiile Game Center pot sosi și din meniul principal.
    static let shared = GameViewModel()
    /// Cheie: jucătorul a folosit deja Game Center în Avioane (atunci ne conectăm din pornire, pentru invitații).
    static let gameCenterUsedKey = "avioane.gameCenterUsed"

    enum Phase: Equatable { case home, placement, battle }
    enum Outcome: Equatable { case won, lost }
    enum Mode: Equatable { case bot, online }
    enum OnlineStatus: Equatable { case idle, negotiating, placing, waitingForOpponent, playing }

    struct AlertInfo: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    // Ritmul animațiilor (secunde)
    private enum Timing {
        static let flight = 0.28        // proiectilul până la țintă
        static let botThink = 0.75      // pauza botului înainte să tragă
        static let finishDelay = 1.0    // lași explozia să se vadă înainte de ecranul final
    }

    @Published var phase: Phase = .home
    @Published private(set) var mode: Mode = .bot
    @Published private(set) var onlineStatus: OnlineStatus = .idle
    @Published private(set) var opponentGone = false
    @Published var difficulty: Difficulty = .medium
    /// Câte avioane alege jucătorul (1–3), pentru bot și pentru online.
    @Published var planeChoice: Int = {
        let v = UserDefaults.standard.integer(forKey: "avioane.planeChoice")
        return (1...3).contains(v) ? v : 3
    }() {
        didSet { UserDefaults.standard.set(planeChoice, forKey: "avioane.planeChoice") }
    }
    @Published var alert: AlertInfo?

    /// Online: numărul convenit cu adversarul (cel mai mic dintre cele două alegeri).
    @Published private(set) var onlinePlanes: Int?
    private var opponentPlaneChoice: Int?

    /// Numărul de avioane din meciul curent.
    var planeCount: Int { mode == .online ? (onlinePlanes ?? planeChoice) : planeChoice }

    // MARK: Hangar

    @Published var playerPlanes: [Plane] = []
    @Published var selectedPlaneID = 0
    private var dragOffset: (row: Int, col: Int)?
    private var dragStartedOnSelected = false

    // MARK: Bătălie

    @Published private(set) var playerBoard = Board(planes: [])
    @Published private(set) var enemyBoard = Board(planes: [])
    @Published private(set) var isPlayerTurn = true
    @Published private(set) var shotInFlight = false
    @Published private(set) var playerMessage = ""
    @Published private(set) var enemyMessage = ""
    @Published private(set) var outcome: Outcome?
    @Published private(set) var shots = 0
    @Published private(set) var hits = 0
    @Published private(set) var stats = Stats.load()

    // Animații
    @Published private(set) var radarFX: ShotFX?
    @Published private(set) var ownFX: ShotFX?
    @Published private(set) var radarShake = 0
    @Published private(set) var ownShake = 0

    private var gameID = UUID()
    private let gc = GameCenter.shared
    private var myRoll = 0
    private var opponentRoll: Int?
    private var launchTime = Date()
    private var finishing = false
    private var noseKills = 0 // avioane doborâte direct din bot, fără alte lovituri înainte

    init() {
        gc.onMatchFound = { [weak self] in self?.matchFound() }
        gc.onMatchmakingCancelled = { [weak self] in
            guard let self, self.mode == .online, self.phase == .home else { return }
            self.mode = .bot
            self.onlineStatus = .idle
        }
        gc.onMessage = { [weak self] in self?.handle($0) }
        gc.onOpponentLeft = { [weak self] in self?.opponentLeft() }
        gc.onError = { [weak self] text in
            self?.alert = AlertInfo(title: String(localized: "Connection error"), message: text)
        }
        // Modul de capturi pornește direct pe ecranul cerut, fără tranziție animată.
        if let scene = Self.screenshotScene { stageScreenshot(scene) }
    }

    func onAppear() {
        guard Self.screenshotScene == nil else { return } // fără Game Center și fără muzică în modul de capturi
        gc.authenticate()
        SoundManager.shared.updateMusic()
    }

    // MARK: Text afișat

    var opponentName: String { mode == .bot ? String(localized: "Bot") : gc.opponentName }

    var accuracy: Int { shots == 0 ? 0 : Int((Double(hits) / Double(shots) * 100).rounded()) }

    var canFire: Bool { phase == .battle && outcome == nil && !finishing && isPlayerTurn && !shotInFlight }

    var turnText: String {
        if outcome != nil || finishing { return String(localized: "Match over") }
        return isPlayerTurn
            ? String(localized: "Your turn — pick a target")
            : String(localized: "\(opponentName) is aiming…")
    }

    var resultTitle: String {
        outcome == .won ? String(localized: "VICTORY!") : String(localized: "DEFEAT")
    }

    var resultSubtitle: String {
        if outcome == .won {
            return opponentGone && mode == .online
                ? String(localized: "\(opponentName) left the match. You win!")
                : String(localized: "You shot down all the enemy planes.")
        }
        return String(localized: "All your planes are down. The enemy planes are now visible on the radar.")
    }

    var canRematch: Bool { mode == .bot || !opponentGone }

    // MARK: Navigare

    /// Meci nou contra botului.
    func playBot() {
        leaveOnlineMatch()
        mode = .bot
        enterPlacement()
    }

    /// Deschide matchmaking-ul Game Center (prieten sau adversar aleatoriu).
    func playOnline() {
        UserDefaults.standard.set(true, forKey: Self.gameCenterUsedKey)
        guard gc.isAuthenticated else {
            gc.authenticate { [weak self] ok in
                guard let self else { return }
                if ok {
                    self.gc.findMatch(planes: self.planeChoice)
                } else {
                    self.alert = AlertInfo(
                        title: String(localized: "Game Center"),
                        message: String(localized: "Sign in to Game Center in Settings to play online.")
                    )
                }
            }
            return
        }
        gc.findMatch(planes: planeChoice)
    }

    func rematch() {
        if mode == .bot { enterPlacement(); return }
        guard !opponentGone else { return }
        onlineStatus = .placing
        enterPlacement()
    }

    func goHome() {
        leaveOnlineMatch()
        gameID = UUID() // anulează orice acțiune programată
        outcome = nil
        finishing = false
        mode = .bot
        onlineStatus = .idle
        onlinePlanes = nil
        opponentPlaneChoice = nil
        phase = .home
    }

    func resetStats() {
        Stats.reset()
        stats = Stats()
    }

    private func enterPlacement() {
        gameID = UUID()
        outcome = nil
        finishing = false
        playerPlanes = Board.randomLayout(count: planeCount)
        selectedPlaneID = 0
        phase = .placement
    }

    private func leaveOnlineMatch() {
        guard mode == .online, gc.match != nil else { return }
        gc.send(.leave)
        gc.disconnect()
    }

    /// Rulează o acțiune după o pauză, doar dacă între timp nu s-a schimbat meciul.
    private func after(_ seconds: Double, _ action: @escaping @MainActor (GameViewModel) -> Void) {
        let id = gameID
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, self.gameID == id else { return }
            action(self)
        }
    }

    // MARK: Hangar

    var invalidPlaneIDs: Set<Int> { Board.invalidPlaneIDs(playerPlanes) }
    var layoutIsValid: Bool { invalidPlaneIDs.isEmpty }

    private var selectedIndex: Int? { playerPlanes.firstIndex { $0.id == selectedPlaneID } }

    func selectPlane(_ id: Int) {
        selectedPlaneID = id
        Feedback.play(.tap)
    }

    func randomizeLayout() {
        playerPlanes = Board.randomLayout(count: planeCount)
        Feedback.play(.rotate)
    }

    func rotateSelected() {
        guard let i = selectedIndex else { return }
        playerPlanes[i].orientation = playerPlanes[i].orientation.next
        Feedback.play(.rotate)
    }

    /// Avionul de sub deget; avionul selectat are prioritate când se suprapun.
    private func planeCovering(_ c: Coord) -> Plane? {
        playerPlanes.first { $0.id == selectedPlaneID && $0.cells.contains(c) }
            ?? playerPlanes.first { $0.cells.contains(c) }
    }

    // Drag & drop: apuci avionul de orice pătrățel și îl tragi.
    func dragBegan(at c: Coord) {
        if let p = planeCovering(c) {
            dragStartedOnSelected = p.id == selectedPlaneID
            if p.id != selectedPlaneID { selectPlane(p.id) }
            dragOffset = (p.head.row - c.row, p.head.col - c.col)
        } else {
            dragOffset = nil
            dragStartedOnSelected = false
        }
    }

    func dragChanged(to c: Coord) {
        guard let off = dragOffset, let i = selectedIndex else { return }
        let newHead = Coord(row: c.row + off.row, col: c.col + off.col)
        if newHead != playerPlanes[i].head {
            playerPlanes[i].head = newHead
            Feedback.play(.tap)
        }
    }

    /// Atingere fără mișcare: pe avionul deja selectat → rotește; pe căsuță liberă → mută botul acolo.
    func dragEnded(at c: Coord, moved: Bool) {
        defer { dragOffset = nil; dragStartedOnSelected = false }
        guard !moved, c.isValid else { return }
        if planeCovering(c) != nil {
            if dragStartedOnSelected { rotateSelected() }
        } else if let i = selectedIndex {
            playerPlanes[i].head = c
            Feedback.play(.tap)
        }
    }

    func placementStyle(for c: Coord) -> CellStyle {
        let invalid = invalidPlaneIDs
        let ordered = playerPlanes.filter { $0.id == selectedPlaneID } + playerPlanes.filter { $0.id != selectedPlaneID }
        for p in ordered where p.cells.contains(c) {
            let state: ShipState = invalid.contains(p.id) ? .invalid : (p.id == selectedPlaneID ? .selected : .normal)
            return .ship(head: p.head == c, state: state)
        }
        return .water
    }

    func confirmPlacement() {
        guard layoutIsValid else { Feedback.play(.invalid); return }
        switch mode {
        case .bot:
            startBattle(enemy: Board(planes: Board.randomLayout(count: planeCount)), playerStarts: true)
        case .online:
            myRoll = Int.random(in: 0...Int(Int32.max))
            gc.send(.ready(roll: myRoll))
            onlineStatus = .waitingForOpponent
            tryStartOnlineBattle()
        }
    }

    // MARK: Bătălie

    private func startBattle(enemy: Board, playerStarts: Bool) {
        gameID = UUID()
        playerBoard = Board(planes: playerPlanes)
        enemyBoard = enemy
        isPlayerTurn = playerStarts
        shotInFlight = false
        finishing = false
        outcome = nil
        shots = 0
        hits = 0
        noseKills = 0
        radarFX = nil
        ownFX = nil
        playerMessage = playerStarts
            ? String(localized: "You fire first!")
            : String(localized: "\(opponentName) fires first.")
        enemyMessage = ""
        phase = .battle
        if playerStarts { Feedback.play(.yourTurn) }
    }

    /// Atingi o căsuță pe radar: pleacă proiectilul.
    func fire(at c: Coord) {
        guard phase == .battle, enemyBoard.marks[c] == nil else {
            if phase == .battle, canFire { Feedback.play(.invalid) }
            return
        }
        guard canFire else { return }

        shotInFlight = true
        launchTime = Date()
        radarFX = ShotFX(coord: c, kind: .launch)
        playerMessage = String(localized: "Firing at \(c.label)…")
        Feedback.play(.fire)

        switch mode {
        case .bot:
            after(Timing.flight) { vm in vm.resolveShotAtBot(c) }
        case .online:
            if !gc.send(.fire(row: c.row, col: c.col)) {
                // N-a plecat: lași jucătorul să încerce din nou.
                shotInFlight = false
                radarFX = nil
                playerMessage = String(localized: "Your turn — pick a target")
            }
        }
    }

    /// Rezultatul propriei lovituri: animație, sunet, mesaj, trofeul „din bot”.
    private func landOwnShot(_ kind: NetResult, at c: Coord, plane: Plane?, marksBefore: [Coord: CellMark]) {
        shotInFlight = false
        shots += 1
        var fx = ShotFX(coord: c, kind: .impact(kind))
        switch kind {
        case .miss:
            playerMessage = String(localized: "🌊 Water at \(c.label)")
            Feedback.play(.ownMiss)
        case .hit:
            hits += 1
            playerMessage = String(localized: "💥 Hit at \(c.label)!")
            Feedback.play(.ownHit)
            radarShake += 1
        case .destroyed:
            hits += 1
            playerMessage = String(localized: "✈️ Destroyed at \(c.label)! Planes left: \(enemyBoard.remaining).")
            Feedback.play(.ownDestroy)
            radarShake += 1
            if let plane {
                fx.cells = plane.cells
                // Doborât direct din bot, fără ca restul avionului să fi fost lovit înainte?
                let clean = plane.cells.filter { $0 != plane.head }.allSatisfy { marksBefore[$0] == nil }
                if clean && c == plane.head {
                    noseKills += 1
                    gc.report(.noseShot)
                }
            }
        }
        radarFX = fx
    }

    /// Lovitura adversarului pe tabla ta.
    private func landEnemyShot(_ kind: NetResult, at c: Coord, plane: Plane?) {
        var fx = ShotFX(coord: c, kind: .impact(kind))
        switch kind {
        case .miss:
            enemyMessage = String(localized: "\(opponentName) fired at \(c.label): water.")
            Feedback.play(.incomingMiss)
        case .hit:
            enemyMessage = String(localized: "\(opponentName) hit you at \(c.label)!")
            Feedback.play(.incomingHit)
            ownShake += 1
        case .destroyed:
            enemyMessage = String(localized: "\(opponentName) shot down one of your planes (\(c.label))!")
            Feedback.play(.incomingDestroy)
            ownShake += 1
            fx.cells = plane?.cells ?? []
        }
        ownFX = fx
    }

    private func kind(of result: ShotResult) -> NetResult? {
        switch result {
        case .miss: return .miss
        case .hit: return .hit
        case .destroyed: return .destroyed
        case .alreadyShot: return nil
        }
    }

    private func plane(of result: ShotResult) -> Plane? {
        if case .destroyed(let p) = result { return p }
        return nil
    }

    private func finishSoon(_ result: Outcome) {
        finishing = true
        isPlayerTurn = false
        after(Timing.finishDelay) { vm in vm.finish(result) }
    }

    // MARK: Contra botului

    private func resolveShotAtBot(_ c: Coord) {
        let before = enemyBoard.marks
        let result = enemyBoard.receiveShot(at: c)
        guard let k = kind(of: result) else { shotInFlight = false; return }
        landOwnShot(k, at: c, plane: plane(of: result), marksBefore: before)

        if enemyBoard.allDestroyed { finishSoon(.won); return }

        isPlayerTurn = false
        enemyMessage = String(localized: "\(opponentName) is aiming…")
        after(Timing.botThink) { vm in vm.botFire() }
    }

    private func botFire() {
        guard outcome == nil, !finishing, mode == .bot else { return }
        let c = Bot.chooseTarget(on: playerBoard, difficulty: difficulty)
        Feedback.play(.fire)
        after(Timing.flight) { vm in
            let result = vm.playerBoard.receiveShot(at: c)
            guard let k = vm.kind(of: result) else { vm.isPlayerTurn = true; return }
            vm.landEnemyShot(k, at: c, plane: vm.plane(of: result))
            if vm.playerBoard.allDestroyed { vm.finishSoon(.lost); return }
            vm.isPlayerTurn = true
            vm.after(0.35) { _ in Feedback.play(.yourTurn) }
        }
    }

    // MARK: Online

    private func matchFound() {
        mode = .online
        opponentGone = false
        opponentRoll = nil
        onlinePlanes = nil
        onlineStatus = .negotiating
        gc.send(.config(planes: planeChoice))
        tryAgreePlanes()
        // Un adversar cu o versiune mai veche nu trimite alegerea: după 4 s se joacă clasic, cu 3.
        after(4) { vm in
            guard vm.mode == .online, vm.onlineStatus == .negotiating else { return }
            vm.opponentPlaneChoice = 3
            vm.tryAgreePlanes()
        }
    }

    /// Ambele telefoane au trimis alegerea: se joacă cu numărul mai mic (același rezultat pe ambele).
    private func tryAgreePlanes() {
        guard mode == .online, onlineStatus == .negotiating, let theirs = opponentPlaneChoice else { return }
        opponentPlaneChoice = nil
        onlinePlanes = max(1, min(3, min(planeChoice, theirs)))
        onlineStatus = .placing
        enterPlacement()
    }

    private func tryStartOnlineBattle() {
        guard mode == .online, onlineStatus == .waitingForOpponent, let theirs = opponentRoll else { return }
        opponentRoll = nil
        let iStart = myRoll != theirs ? myRoll > theirs : gc.localPlayerID > gc.opponentID
        onlineStatus = .playing
        startBattle(enemy: Board(planes: [], totalPlanes: planeCount), playerStarts: iStart)
    }

    private func handle(_ message: NetMessage) {
        // Alegerea adversarului poate sosi înainte ca meciul să fie anunțat aici: o păstrăm.
        if case .config(let planes) = message {
            opponentPlaneChoice = planes
            tryAgreePlanes()
            return
        }
        guard mode == .online else { return }
        switch message {
        case .config:
            break

        case .ready(let roll):
            opponentRoll = roll
            tryStartOnlineBattle()

        case let .fire(row, col):
            // Adversarul trage: răspundem imediat, animăm la noi.
            guard phase == .battle, outcome == nil, !finishing else { return }
            let c = Coord(row: row, col: col)
            guard c.isValid else { return }
            let result = playerBoard.receiveShot(at: c)
            guard let k = kind(of: result) else { return }
            let downed = plane(of: result)
            let over = playerBoard.allDestroyed
            guard gc.send(.result(row: row, col: col, kind: k, plane: downed.map(NetPlane.init), gameOver: over)) else {
                // Adversarul n-ar mai primi răspunsul și ar aștepta la nesfârșit: închidem meciul.
                goHome()
                return
            }
            landEnemyShot(k, at: c, plane: downed)
            if over {
                finishSoon(.lost)
            } else {
                isPlayerTurn = true
                after(0.35) { _ in Feedback.play(.yourTurn) }
            }

        case let .result(row, col, k, plane, over):
            guard phase == .battle, outcome == nil, !finishing else { return }
            let c = Coord(row: row, col: col)
            guard c.isValid else { return }
            // Tura trece imediat la adversar (el poate trage chiar înainte să se termine animația noastră).
            isPlayerTurn = false
            if over { finishing = true }
            // Proiectilul zboară cel puțin `flight` secunde, chiar dacă răspunsul vine mai repede.
            let wait = max(0, Timing.flight - Date().timeIntervalSince(launchTime))
            after(wait) { vm in
                let before = vm.enemyBoard.marks
                vm.enemyBoard.applyRemote(k, at: c, plane: plane?.plane)
                let downed = plane.map { vm.enemyBoard.plane(at: c) ?? $0.plane }
                vm.landOwnShot(k, at: c, plane: downed, marksBefore: before)
                if over { vm.finishSoon(.won) }
            }

        case .reveal(let planes):
            enemyBoard.reveal(planes.map(\.plane))

        case .leave:
            opponentLeft()
        }
    }

    private func opponentLeft() {
        guard mode == .online, !opponentGone else { return }
        opponentGone = true
        if phase == .battle && outcome == nil && !finishing {
            finish(.won)
        } else if phase != .battle {
            let name = opponentName
            goHome()
            alert = AlertInfo(title: String(localized: "Opponent left"),
                              message: String(localized: "\(name) left the match."))
        }
    }

    // MARK: Final

    private func finish(_ result: Outcome) {
        guard outcome == nil else { return }
        outcome = result
        finishing = false
        isPlayerTurn = false
        shotInFlight = false

        if mode == .online {
            onlineStatus = .placing
            if !opponentGone { gc.send(.reveal(planes: playerBoard.planes.map(NetPlane.init))) }
        }

        if result == .won { stats.wins += 1 } else { stats.losses += 1 }
        if mode == .online {
            if result == .won { stats.onlineWins += 1 } else { stats.onlineLosses += 1 }
        }
        stats.shots += shots
        stats.hits += hits
        stats.save()

        reportAchievements(for: result)
        Feedback.play(result == .won ? .victory : .defeat)
    }

    private func reportAchievements(for result: Outcome) {
        guard result == .won else { return }
        gc.report(.firstWin)
        // Trofeele de performanță contează doar în jocul clasic, cu 3 avioane.
        guard planeCount == 3 else { return }
        if noseKills >= 3 { gc.report(.tripleNose) }
        if accuracy >= 50 { gc.report(.sharpshooter) }
        if playerBoard.destroyedIDs.isEmpty { gc.report(.flawless) }

        switch mode {
        case .bot:
            if difficulty == .hard { gc.report(.beatHardBot) }
        case .online:
            gc.report(.firstOnlineWin)
            gc.report(.veteran, percent: Double(stats.onlineWins) / 10 * 100)
            gc.submit(stats.onlineWins, to: .onlineWins)
            if !opponentGone && planeCount == 3 { gc.submit(shots, to: .fewestShots) }
        }
    }

    // MARK: Capturi pentru App Store

    /// Pornește aplicația direct pe un ecran demonstrativ, pentru capturile automate din CI.
    /// Se activează doar cu argumentul de lansare `-screenshot <home|hangar|battle|victory>`.
    static var forcedScene: String?
    static var screenshotScene: String? { forcedScene ?? UserDefaults.standard.string(forKey: "screenshot") }

    func stageScreenshot(_ scene: String) {
        mode = .bot
        difficulty = .hard
        stats = Stats()
        stats.wins = 27; stats.losses = 9; stats.shots = 512; stats.hits = 313

        let mine = [
            Plane(id: 0, head: Coord(row: 0, col: 2), orientation: .up),
            Plane(id: 1, head: Coord(row: 3, col: 9), orientation: .right),
            Plane(id: 2, head: Coord(row: 9, col: 3), orientation: .down)
        ]
        playerPlanes = Board.invalidPlaneIDs(mine).isEmpty ? mine : Board.randomLayout()
        selectedPlaneID = 1

        switch scene {
        case "hangar":
            phase = .placement
        case "battle", "victory":
            let enemyPlanes = [
                Plane(id: 0, head: Coord(row: 0, col: 4), orientation: .up),
                Plane(id: 1, head: Coord(row: 5, col: 1), orientation: .left),
                Plane(id: 2, head: Coord(row: 6, col: 7), orientation: .up)
            ]
            var enemy = Board(planes: Board.invalidPlaneIDs(enemyPlanes).isEmpty ? enemyPlanes : Board.randomLayout())
            var own = Board(planes: playerPlanes)
            let myShots = [(0, 4), (3, 0), (2, 9), (8, 3), (6, 6), (7, 7), (4, 4), (9, 9), (1, 1), (5, 5)]
            for (r, c) in myShots { _ = enemy.receiveShot(at: Coord(row: r, col: c)) }
            let botShots = [(0, 0), (5, 5), (2, 7), (9, 1), (4, 8), (7, 4)]
            for (r, c) in botShots { _ = own.receiveShot(at: Coord(row: r, col: c)) }
            if scene == "victory" {
                for p in enemy.planes { _ = enemy.receiveShot(at: p.head) }
            }
            enemyBoard = enemy
            playerBoard = own
            shots = 23
            hits = 14
            isPlayerTurn = true
            playerMessage = String(localized: "💥 Hit at \(Coord(row: 7, col: 7).label)!")
            enemyMessage = String(localized: "\(opponentName) fired at \(Coord(row: 9, col: 1).label): water.")
            phase = .battle
            if scene == "victory" { outcome = .won }
        default:
            phase = .home
        }
    }

    // MARK: Stiluri pentru grile

    func enemyStyle(for c: Coord) -> CellStyle {
        switch enemyBoard.marks[c] {
        case .miss?: return .miss
        case .hit?: return .hit
        case .destroyed?: return .wreck(head: enemyBoard.plane(at: c)?.head == c)
        case nil:
            if outcome != nil, let p = enemyBoard.plane(at: c) { return .ghost(head: p.head == c) }
            return .water
        }
    }

    func playerStyle(for c: Coord) -> CellStyle {
        let mark = playerBoard.marks[c]
        if let p = playerBoard.plane(at: c) {
            let head = p.head == c
            switch mark {
            case .destroyed?: return .wreck(head: head)
            case .hit?: return .shipHit(head: head)
            default: return .ship(head: head, state: .normal)
            }
        }
        return mark == .miss ? .miss : .water
    }
}
