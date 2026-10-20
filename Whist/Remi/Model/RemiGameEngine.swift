import SwiftUI
import UIKit

enum SortMode { case color, number }

/// Leagă starea jocului de interfață: acțiunile jucătorului, turele boților, scorul pe mai multe mâini.
@MainActor
final class RemiEngine: ObservableObject {
    @Published private(set) var state: RemiState
    @Published var selected: Set<Int> = []
    @Published var message: String?
    @Published private(set) var totals: [Int]
    @Published private(set) var handNumber = 1
    @Published var showResult = false
    @Published private(set) var botThinking = false
    @Published var sortMode: SortMode = .color

    let names: [String]
    let handsToPlay: Int
    let human = 0

    private var starter: Int
    private var preDrawSnapshot: RemiState?
    private var postDrawSnapshot: RemiState?
    private var botTask: Task<Void, Never>?
    private var handScored = false
    private var resultTask: Task<Void, Never>?

    /// Jocul stă pe loc (fără ture ale boților) — folosit pentru capturile din App Store.
    private let frozen: Bool

    init(playerCount: Int, hands: Int, playerName: String) {
        let botNames = [L("bot.1"), L("bot.2"), L("bot.3")]
        let name = playerName.trimmingCharacters(in: .whitespaces)
        names = [name.isEmpty ? L("name.you") : name] + Array(botNames.prefix(max(1, playerCount - 1)))
        handsToPlay = hands
        frozen = false
        starter = Int.random(in: 0..<names.count)
        state = RemiState.newHand(names: names, humanIndex: 0, starter: starter)
        totals = Array(repeating: 0, count: names.count)
        afterStateChange()
    }

    /// Joc „înghețat” într-o stare pregătită (capturi App Store).
    init(frozenState: RemiState, hands: Int, handNumber: Int, totals: [Int]) {
        names = frozenState.players.map(\.name)
        handsToPlay = hands
        frozen = true
        starter = 0
        state = frozenState
        self.totals = totals
        self.handNumber = handNumber
        handScored = frozenState.phase == .handOver
        if frozenState.phase == .play && frozenState.current == 0 { postDrawSnapshot = frozenState }
    }

    // MARK: - Stare pentru interfață

    var isHumanTurn: Bool { state.current == human && state.phase != .handOver && !botThinking }
    var me: RemiPlayer { state.players[human] }
    var isMatchOver: Bool { handNumber >= handsToPlay }

    var humanHand: [Tile] {
        me.hand.sorted { a, b in
            if a.isJoker != b.isJoker { return !a.isJoker }
            if a.isJoker { return a.id < b.id }
            switch sortMode {
            case .color:
                if a.color != b.color { return a.color!.rawValue < b.color!.rawValue }
                return a.number < b.number
            case .number:
                if a.number != b.number { return a.number < b.number }
                return a.color!.rawValue < b.color!.rawValue
            }
        }
    }

    var statusText: String {
        if state.phase == .handOver { return L("status.handOver") }
        if state.current != human { return L("status.botPlaying", state.currentPlayer.name) }
        switch state.phase {
        case .draw:
            if state.isFirstRound { return L("status.drawFirstRound") }
            if state.handCountAtTurnStart <= 2 { return L("status.drawLow") }
            return L("status.draw")
        case .play:
            if state.isFirstRound { return L("status.firstRoundDiscard") }
            if !state.canCreateNewMelds { return L("status.addOnly") }
            if !me.opened { return L("status.openFirst") }
            return L("status.play")
        case .handOver:
            return ""
        }
    }

    /// Piesa selectată poate fi lipită / poate înlocui un Joker în formația asta?
    func canPlaceSelected(on meld: Meld) -> Bool {
        guard isHumanTurn, state.phase == .play, selected.count == 1,
              let id = selected.first, let tile = me.hand.first(where: { $0.id == id }) else { return false }
        if state.openedAtTurnStart, meld.replaceableJokerIndex(for: tile) != nil { return true }
        guard state.openedAtTurnStart || state.meldsCreatedThisTurn.contains(meld.id) else { return false }
        if tile.isJoker && meld.owner != human { return false }
        return meld.adding(tile, by: human, reused: false) != nil
    }

    var canUndo: Bool { isHumanTurn && state.phase == .play && (postDrawSnapshot != nil || preDrawSnapshot != nil) }

    // MARK: - Acțiunile jucătorului

    func toggle(_ tile: Tile) {
        guard isHumanTurn else { return }
        if selected.contains(tile.id) { selected.remove(tile.id) } else { selected.insert(tile.id) }
        RemiHaptics.tap()
    }

    func drawStock() {
        guard isHumanTurn else { return }
        perform { try $0.drawFromStock() }
    }

    func tapRow(index: Int) {
        guard isHumanTurn else { return }
        if state.phase == .play {
            message = L("err.alreadyDrew")
            return
        }
        perform { try $0.takeFromRow(index: index) }
    }

    func takeAtu() {
        guard isHumanTurn else { return }
        perform { try $0.takeAtu() }
    }

    func makeMeld() {
        guard isHumanTurn else { return }
        let ids = Array(selected)
        if perform({ _ = try $0.createMeld(tileIDs: ids) }) {
            selected = []
            RemiHaptics.success()
        }
    }

    func tapMeld(_ meld: Meld) {
        guard isHumanTurn else { return }
        guard !selected.isEmpty else {
            message = L("msg.selectForAdd")
            return
        }
        let hand = me.hand
        var pending = selected.compactMap { id in hand.first { $0.id == id } }
        var progressed = true
        var anySuccess = false
        var lastError: String?
        var tookJoker = false
        // Lipim pe rând, cât timp se potrivește ceva (ex. 4 și 5 la o suită 6-7-8).
        while progressed && !pending.isEmpty {
            progressed = false
            for tile in pending {
                let current = state.melds.first { $0.id == meld.id } ?? meld
                let replace = state.openedAtTurnStart && current.replaceableJokerIndex(for: tile) != nil
                var copy = state
                do {
                    if replace {
                        try copy.replaceJoker(tileID: tile.id, meldID: meld.id)
                    } else {
                        try copy.addToMeld(tileID: tile.id, meldID: meld.id)
                    }
                    state = copy
                    pending.removeAll { $0.id == tile.id }
                    selected.remove(tile.id)
                    progressed = true
                    anySuccess = true
                    if replace { tookJoker = true }
                    break
                } catch let e as RuleError {
                    lastError = e.message
                } catch {}
            }
        }
        if anySuccess {
            message = tookJoker ? L("msg.tookJoker") : nil
            RemiHaptics.success()
        } else {
            message = lastError
            RemiHaptics.error()
        }
        afterStateChange()
    }

    func discardSelected() {
        guard isHumanTurn else { return }
        guard selected.count == 1, let id = selected.first else {
            message = L("err.selectOneDiscard")
            return
        }
        if perform({ try $0.discard(tileID: id) }) {
            selected = []
            RemiHaptics.success()
        }
    }

    func undoTurn() {
        guard isHumanTurn else { return }
        if state.mustUseTileID != nil, let pre = preDrawSnapshot {
            state = pre
            postDrawSnapshot = nil
        } else if let post = postDrawSnapshot {
            state = post
        }
        selected = []
        message = nil
    }

    func suggest() {
        guard isHumanTurn, state.phase == .play else { return }
        let hand = me.hand
        if state.canCreateNewMelds {
            let must = state.mustUseTileID.flatMap { id in hand.first { $0.id == id } }
            let plan = MeldFinder.bestPlan(hand: hand, maxTiles: hand.count - 1,
                                           opening: !state.openedAtTurnStart, mustUse: must)
            if let first = plan.first {
                selected = Set(first.map { $0.id })
                message = state.openedAtTurnStart || plan.count == 1
                    ? L("msg.canMeld")
                    : L("msg.openingPlan", plan.count)
                return
            }
        }
        if state.openedAtTurnStart,
           let tile = hand.first(where: { t in state.melds.contains { canFit(t, $0) } }) {
            selected = [tile.id]
            message = L("msg.canAdd", tile.label)
            return
        }
        if let d = RemiBot.chooseDiscard(state) {
            selected = [d.id]
            message = L("msg.discardHint", d.label)
        }
    }

    private func canFit(_ tile: Tile, _ meld: Meld) -> Bool {
        if meld.replaceableJokerIndex(for: tile) != nil { return true }
        if tile.isJoker && meld.owner != human { return false }
        return meld.adding(tile, by: human, reused: false) != nil
    }

    // MARK: - Mâini

    func nextHand() {
        guard !isMatchOver else { return }
        handNumber += 1
        starter = (starter + 1) % names.count
        state = RemiState.newHand(names: names, humanIndex: human, starter: starter)
        resetHandUI()
        afterStateChange()
    }

    func restartMatch() {
        botTask?.cancel()
        botTask = nil
        botThinking = false
        handNumber = 1
        totals = Array(repeating: 0, count: names.count)
        starter = Int.random(in: 0..<names.count)
        state = RemiState.newHand(names: names, humanIndex: human, starter: starter)
        resetHandUI()
        afterStateChange()
    }

    func stop() {
        botTask?.cancel()
        botTask = nil
        resultTask?.cancel()
    }

    private func resetHandUI() {
        resultTask?.cancel()
        resultTask = nil
        selected = []
        message = nil
        showResult = false
        handScored = false
        preDrawSnapshot = nil
        postDrawSnapshot = nil
    }

    // MARK: - Intern

    @discardableResult
    private func perform(silent: Bool = false, _ body: (inout RemiState) throws -> Void) -> Bool {
        var copy = state
        do {
            try body(&copy)
            state = copy
            if !silent { message = nil }
            afterStateChange()
            return true
        } catch let e as RuleError {
            if !silent {
                message = e.message
                RemiHaptics.error()
            }
            return false
        } catch {
            return false
        }
    }

    private func afterStateChange() {
        if state.phase == .handOver {
            scoreHand()
            return
        }
        if state.current == human {
            if state.phase == .draw {
                preDrawSnapshot = state
                postDrawSnapshot = nil
            } else if postDrawSnapshot == nil {
                postDrawSnapshot = state
            }
        } else {
            preDrawSnapshot = nil
            postDrawSnapshot = nil
            runBots()
        }
    }

    private func scoreHand() {
        guard !frozen, !handScored, let result = state.result else { return }
        handScored = true
        for r in result.players { totals[r.id] += r.total }
        selected = []
        resultTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled, self.state.phase == .handOver else { return }
            self.showResult = true
        }
    }

    private func runBots() {
        guard !frozen, botTask == nil else { return }
        botTask = Task { [weak self] in
            guard let self else { return }
            self.botThinking = true
            defer {
                if !Task.isCancelled {
                    self.botThinking = false
                    self.botTask = nil
                }
            }
            while !Task.isCancelled, self.state.phase != .handOver, self.state.current != self.human {
                try? await Task.sleep(nanoseconds: 650_000_000)
                if Task.isCancelled { return }
                let snapshot = self.state
                let actions = await Task.detached(priority: .userInitiated) { RemiBot.plan(snapshot) }.value
                for action in actions {
                    guard !Task.isCancelled, self.state.current == snapshot.current,
                          self.state.phase != .handOver else { break }
                    self.apply(action)
                    let pause: UInt64 = {
                        if case .discard = action { return 250_000_000 }
                        return 550_000_000
                    }()
                    try? await Task.sleep(nanoseconds: pause)
                }
                if !Task.isCancelled && self.state.current == snapshot.current && self.state.phase != .handOver {
                    self.forceEndBotTurn()
                }
            }
            // Dacă acum e rândul jucătorului, pregătim instantaneul pentru „Anulează”.
            if self.state.current == self.human && self.state.phase != .handOver {
                self.preDrawSnapshot = self.state.phase == .draw ? self.state : nil
                self.postDrawSnapshot = self.state.phase == .play ? self.state : nil
            }
        }
    }

    private func apply(_ action: BotAction) {
        perform(silent: true) { try RemiBot.apply(action, to: &$0) }
    }

    /// Plasă de siguranță: dacă planul botului nu a mers, trage și aruncă orice e permis.
    private func forceEndBotTurn() {
        if state.phase == .draw { perform(silent: true) { try $0.drawFromStock() } }
        guard state.phase == .play else { return }
        for tile in state.currentPlayer.hand {
            if perform(silent: true, { try $0.discard(tileID: tile.id) }) { return }
        }
        // Ultima soluție: anulăm etalările nevalide ale turei reconstruind tura din grămadă.
        var s = state
        s.phase = .handOver
        s.endHand(closer: nil, closingTile: nil)
        state = s
        afterStateChange()
    }
}

enum RemiHaptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
