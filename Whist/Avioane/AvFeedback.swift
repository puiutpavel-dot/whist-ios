import AVFoundation
import CoreHaptics
import UIKit

// MARK: - Setări (citite și din ecranul Setări prin @AppStorage)

enum SettingsKey {
    static let sound = "settings.sound"
    static let music = "settings.music"
    static let haptics = "settings.haptics"

    static func isOn(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }
}

// MARK: - Evenimente de joc → sunet + vibrație

enum GameEvent {
    case tap, rotate, invalid
    case fire
    case ownMiss, ownHit, ownDestroy
    case incomingMiss, incomingHit, incomingDestroy
    case yourTurn
    case victory, defeat
}

@MainActor
enum Feedback {
    static func play(_ event: GameEvent) {
        let sound = SoundManager.shared
        let haptic = HapticEngine.shared
        switch event {
        case .tap:             sound.play(.tap, volume: 0.5);       haptic.tap()
        case .rotate:          sound.play(.rotate, volume: 0.6);    haptic.tap()
        case .invalid:                                              haptic.warning()
        case .fire:            sound.play(.fire, volume: 0.8); sound.play(.whistle, volume: 0.5); haptic.fire()
        case .ownMiss:         sound.play(.splash);                 haptic.splash()
        case .ownHit:          sound.play(.hit);                    haptic.hit()
        case .ownDestroy:      sound.play(.destroyed);              haptic.destroyed()
        case .incomingMiss:    sound.play(.splash, volume: 0.5);    haptic.splash()
        case .incomingHit:     sound.play(.hit, volume: 0.7);       haptic.incomingHit()
        case .incomingDestroy: sound.play(.destroyed, volume: 0.8); haptic.lostPlane()
        case .yourTurn:        sound.play(.turn, volume: 0.6)
        case .victory:         sound.play(.victory);                haptic.victory()
        case .defeat:          sound.play(.defeat);                 haptic.defeat()
        }
    }
}

// MARK: - Sunete

enum Sound: String, CaseIterable {
    case tap, rotate, fire, whistle, splash, hit, destroyed, turn, victory, defeat
}

@MainActor
final class SoundManager {
    static let shared = SoundManager()

    private var pools: [Sound: [AVAudioPlayer]] = [:]
    private var music: AVAudioPlayer?

    private init() {
        // .ambient: respectă butonul de silențios și se amestecă cu muzica utilizatorului.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for s in Sound.allCases {
            guard let url = Bundle.main.url(forResource: s.rawValue, withExtension: "m4a") else { continue }
            pools[s] = (0..<3).compactMap { _ in
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.prepareToPlay()
                return p
            }
        }
    }

    func play(_ sound: Sound, volume: Float = 1) {
        guard SettingsKey.isOn(SettingsKey.sound), let pool = pools[sound] else { return }
        let player = pool.first { !$0.isPlaying } ?? pool.first
        player?.currentTime = 0
        player?.volume = volume
        player?.play()
    }

    /// Pornește/oprește muzica de fundal în funcție de setare și de starea aplicației.
    func updateMusic(appActive: Bool = true) {
        guard appActive, SettingsKey.isOn(SettingsKey.music) else {
            music?.pause()
            return
        }
        if music == nil, let url = Bundle.main.url(forResource: "music", withExtension: "m4a") {
            music = try? AVAudioPlayer(contentsOf: url)
            music?.numberOfLoops = -1
            music?.volume = 0.3
        }
        if music?.isPlaying == false { music?.play() }
    }
}

// MARK: - Vibrații (CoreHaptics, cu rezervă pe UIKit)

@MainActor
final class HapticEngine {
    static let shared = HapticEngine()

    private var engine: CHHapticEngine?
    private let supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    private init() {
        guard supported else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        engine?.resetHandler = { [weak self] in
            Task { @MainActor in try? self?.engine?.start() }
        }
        try? engine?.start()
    }

    private var enabled: Bool { SettingsKey.isOn(SettingsKey.haptics) }

    // Tipare personalizate

    func tap() {
        run([tr(0, 0.4, 0.8)]) { UISelectionFeedbackGenerator().selectionChanged() }
    }

    func warning() {
        run([tr(0, 0.6, 0.6), tr(0.12, 0.6, 0.6)]) {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    func fire() {
        run([tr(0, 0.7, 0.3), ct(0, 0.12, 0.4, 0.1)]) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    func splash() {
        run([tr(0, 0.35, 0.2), ct(0.02, 0.25, 0.25, 0.05)]) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    func hit() {
        run([tr(0, 1, 0.9), ct(0.01, 0.3, 0.6, 0.3)]) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    func destroyed() {
        run([tr(0, 1, 1), ct(0.02, 0.5, 1, 0.2), tr(0.3, 0.8, 0.5), ct(0.35, 0.4, 0.5, 0.1), tr(0.6, 0.5, 0.3)]) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func incomingHit() {
        run([tr(0, 0.8, 0.4), ct(0.01, 0.2, 0.5, 0.2)]) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
    }

    func lostPlane() {
        run([ct(0, 0.6, 1, 0.1), tr(0.1, 1, 0.2), tr(0.4, 0.6, 0.2)]) {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    func victory() {
        run([tr(0, 0.5, 0.5), tr(0.15, 0.7, 0.6), tr(0.3, 0.9, 0.7), ct(0.45, 0.4, 0.8, 0.5)]) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func defeat() {
        run([ct(0, 0.5, 0.8, 0.1), ct(0.5, 0.5, 0.4, 0.05)]) {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // Ajutătoare

    private func run(_ events: [CHHapticEvent], fallback: () -> Void) {
        guard enabled else { return }
        guard supported, let engine else { fallback(); return }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            fallback()
        }
    }

    /// Impuls scurt.
    private func tr(_ time: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ], relativeTime: time)
    }

    /// Vibrație continuă.
    private func ct(_ time: TimeInterval, _ duration: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ], relativeTime: time, duration: duration)
    }
}
