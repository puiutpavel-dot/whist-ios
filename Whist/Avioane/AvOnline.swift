import Foundation
import GameKit
import UIKit

// MARK: - Protocolul de rețea
//
// Fiecare telefon își păstrează avioanele doar la el. Se trimit numai:
//   ready  → „am plasat avioanele” + un număr aleator pentru cine trage primul
//   fire   → coordonata la care trag
//   result → răspunsul apărătorului (apă / lovit / distrus + schița avionului doborât)
//   reveal → la final, fiecare își arată avioanele rămase
//   leave  → am ieșit din meci

enum NetResult: String, Codable {
    case miss, hit, destroyed
}

struct NetPlane: Codable, Equatable {
    let row: Int
    let col: Int
    let orientation: Int

    init(_ p: Plane) {
        row = p.head.row
        col = p.head.col
        orientation = p.orientation.rawValue
    }

    var plane: Plane {
        Plane(id: 0, head: Coord(row: row, col: col), orientation: Orientation(rawValue: orientation) ?? .up)
    }
}

enum NetMessage: Codable {
    case config(planes: Int)       // câte avioane a ales jucătorul (1–3)
    case ready(roll: Int)
    case fire(row: Int, col: Int)
    case result(row: Int, col: Int, kind: NetResult, plane: NetPlane?, gameOver: Bool)
    case reveal(planes: [NetPlane])
    case leave

    func encoded() -> Data? { try? JSONEncoder().encode(self) }
    static func decode(_ data: Data) -> NetMessage? { try? JSONDecoder().decode(NetMessage.self, from: data) }
}

// MARK: - Game Center

/// Autentificare, matchmaking (prieteni sau adversari aleatorii), invitații și trimiterea mesajelor.
@MainActor
final class GameCenter: NSObject, ObservableObject {
    static let shared = GameCenter()

    @Published private(set) var isAuthenticated = false

    private(set) var match: GKMatch?
    private var listenerRegistered = false
    private var pendingAuth: [(Bool) -> Void] = []
    private var matchAnnounced = false

    /// Evenimentele din rețea trec printr-o singură coadă, ca să fie tratate strict în ordinea sosirii
    /// (ex.: `ready` înainte de primul `fire`, `result` înainte de următorul `fire`).
    private enum InboxEvent {
        case message(NetMessage)
        case connected
        case disconnected
    }
    nonisolated private let inbox: AsyncStream<InboxEvent>.Continuation

    private override init() {
        var continuation: AsyncStream<InboxEvent>.Continuation!
        let stream = AsyncStream<InboxEvent> { continuation = $0 }
        inbox = continuation
        super.init()
        Task { @MainActor [weak self] in
            for await event in stream {
                self?.process(event)
            }
        }
    }

    private func process(_ event: InboxEvent) {
        switch event {
        case .message(let m):
            onMessage?(m)
        case .connected:
            announceMatchIfReady()
        case .disconnected:
            onOpponentLeft?()
        }
    }

    var onMatchFound: (@MainActor () -> Void)?
    var onMatchmakingCancelled: (@MainActor () -> Void)?
    var onMessage: (@MainActor (NetMessage) -> Void)?
    var onOpponentLeft: (@MainActor () -> Void)?
    var onError: (@MainActor (String) -> Void)?

    var opponentName: String {
        match?.players.first?.displayName ?? String(localized: "Opponent")
    }
    var localPlayerID: String { GKLocalPlayer.local.gamePlayerID }
    var opponentID: String { match?.players.first?.gamePlayerID ?? "" }

    // MARK: Autentificare

    func authenticate(completion: ((Bool) -> Void)? = nil) {
        if GKLocalPlayer.local.isAuthenticated {
            isAuthenticated = true
            registerListener()
            completion?(true)
            return
        }
        if let completion { pendingAuth.append(completion) }

        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    UIApplication.topViewController?.present(viewController, animated: true)
                    return
                }
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                if self.isAuthenticated { self.registerListener() }
                if let error, !self.pendingAuth.isEmpty { self.onError?(error.localizedDescription) }
                let callbacks = self.pendingAuth
                self.pendingAuth.removeAll()
                callbacks.forEach { $0(self.isAuthenticated) }
            }
        }
    }

    private func registerListener() {
        guard !listenerRegistered else { return }
        GKLocalPlayer.local.register(self)
        listenerRegistered = true
    }

    // MARK: Matchmaking

    /// Deschide ecranul Game Center: invită un prieten sau „Auto-Match” cu un jucător aleatoriu.
    /// `planes` devine grupul de matchmaking: Auto-Match împerechează doar jucători cu aceeași alegere.
    func findMatch(planes: Int) {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.playerGroup = planes
        guard let vc = GKMatchmakerViewController(matchRequest: request) else { return }
        vc.matchmakerDelegate = self
        UIApplication.topViewController?.present(vc, animated: true)
    }

    private func accept(_ match: GKMatch) {
        disconnect()
        self.match = match
        matchAnnounced = false
        match.delegate = self
        announceMatchIfReady()
    }

    /// Meciul începe doar când adversarul e conectat de-a binelea (altfel `ready` s-ar pierde).
    private func announceMatchIfReady() {
        guard let match, !matchAnnounced, match.expectedPlayerCount == 0, !match.players.isEmpty else { return }
        matchAnnounced = true
        onMatchFound?()
    }

    /// Trimite un mesaj; întoarce `false` dacă n-a plecat.
    @discardableResult
    func send(_ message: NetMessage) -> Bool {
        guard let match, let data = message.encoded() else { return false }
        do {
            try match.sendData(toAllPlayers: data, with: .reliable)
            return true
        } catch {
            onError?(error.localizedDescription)
            return false
        }
    }

    func disconnect() {
        match?.delegate = nil
        match?.disconnect()
        match = nil
        matchAnnounced = false
    }

    // MARK: Clasamente și trofee

    private let reportedKey = "avioane.reportedAchievements"

    /// Raportează un trofeu. Cele deja câștigate nu se mai trimit (fără bannere repetate).
    /// În „Jocuri de Cărți Românești” Avioane nu are (încă) clasamente și trofee Game Center.
    static let reportsEnabled = false

    /// Crește când jucătorul acceptă o invitație; meniul principal deschide atunci Avioane.
    @Published var inviteAccepted = 0

    func report(_ achievement: Achievement, percent: Double = 100) {
        guard Self.reportsEnabled, isAuthenticated else { return }
        var reported = Set(UserDefaults.standard.stringArray(forKey: reportedKey) ?? [])
        guard !reported.contains(achievement.rawValue) else { return }

        let a = GKAchievement(identifier: achievement.rawValue)
        a.percentComplete = min(percent, 100)
        a.showsCompletionBanner = true
        GKAchievement.report([a]) { _ in }

        if percent >= 100 {
            reported.insert(achievement.rawValue)
            UserDefaults.standard.set(Array(reported), forKey: reportedKey)
        }
    }

    func submit(_ score: Int, to leaderboard: Leaderboard) {
        guard Self.reportsEnabled, isAuthenticated else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [leaderboard.rawValue]) { _ in }
    }

    /// Ecranul Game Center: clasamente, trofee sau tabloul general.
    func showDashboard(_ state: GKGameCenterViewControllerState = .default) {
        guard isAuthenticated else {
            onError?(String(localized: "Sign in to Game Center in Settings to play online."))
            return
        }
        let vc = GKGameCenterViewController(state: state)
        vc.gameCenterDelegate = self
        UIApplication.topViewController?.present(vc, animated: true)
    }
}

// MARK: - ID-urile din App Store Connect

/// Trebuie create identic în App Store Connect → Game Center (vezi GAME_CENTER.md).
enum Achievement: String, CaseIterable {
    case firstWin = "avioane.first_win"
    case firstOnlineWin = "avioane.first_online_win"
    case noseShot = "avioane.nose_shot"
    case tripleNose = "avioane.triple_nose"
    case sharpshooter = "avioane.sharpshooter"
    case flawless = "avioane.flawless"
    case beatHardBot = "avioane.beat_hard_bot"
    case veteran = "avioane.veteran_10"
}

enum Leaderboard: String {
    case onlineWins = "avioane.online_wins"     // cele mai multe victorii online (descrescător)
    case fewestShots = "avioane.fewest_shots"   // cele mai puține lovituri pentru o victorie online (crescător)
}

extension GameCenter: GKGameCenterControllerDelegate {
    nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        Task { @MainActor in gameCenterViewController.dismiss(animated: true) }
    }
}

extension GameCenter: GKMatchmakerViewControllerDelegate {
    nonisolated func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        Task { @MainActor in
            viewController.dismiss(animated: true)
            self.onMatchmakingCancelled?()
        }
    }

    nonisolated func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        let text = error.localizedDescription
        Task { @MainActor in
            viewController.dismiss(animated: true)
            self.onError?(text)
            self.onMatchmakingCancelled?()
        }
    }

    nonisolated func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        Task { @MainActor in
            viewController.dismiss(animated: true)
            self.accept(match)
        }
    }
}

extension GameCenter: GKMatchDelegate {
    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        guard let message = NetMessage.decode(data) else { return }
        inbox.yield(.message(message))
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        switch state {
        case .connected: inbox.yield(.connected)
        case .disconnected: inbox.yield(.disconnected)
        default: break
        }
    }
}

extension GameCenter: GKLocalPlayerListener {
    /// Un prieten te-a invitat (din notificare sau din aplicația Game Center).
    nonisolated func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        Task { @MainActor in
            guard let vc = GKMatchmakerViewController(invite: invite) else { return }
            self.inviteAccepted += 1
            // lasă meniul principal să deschidă întâi ecranul Avioane
            try? await Task.sleep(nanoseconds: 700_000_000)
            vc.matchmakerDelegate = self
            UIApplication.topViewController?.present(vc, animated: true)
        }
    }
}

extension UIApplication {
    /// Controller-ul vizibil, ca să putem prezenta ecranele Game Center dintr-o aplicație SwiftUI.
    static var topViewController: UIViewController? {
        let scenes = shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
