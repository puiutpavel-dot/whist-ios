import SwiftUI

/// Ecrane scurte (iPhone SE, mini): totul se strânge ca să încapă fără scroll.
private struct CompactLayoutKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var compactLayout: Bool {
        get { self[CompactLayoutKey.self] }
        set { self[CompactLayoutKey.self] = newValue }
    }
}

/// „Masa de seară” (v1.1): fundal negru, accent roșu intens, butoane-pastilă turcoaz,
/// titluri condensate foarte groase, etichete aurii. Cărțile rămân albe, ca la masă.
enum Theme {
    // Interfață
    static let bg        = Color(hex: 0x0C0C0F)
    static let surface   = Color(hex: 0x18181D)
    static let raised    = Color(hex: 0x222229)
    static let soft      = Color(hex: 0x2A2A32)
    static let line      = Color(hex: 0x30303A)
    static let ink       = Color.white
    static let muted     = Color(hex: 0x9C9CA8)

    static let primary   = Color(hex: 0x02BD9C)   // turcoaz: acțiunea principală
    static let primaryDk = Color(hex: 0x019A80)
    static let onPrimary = Color.black
    static let accent    = Color(hex: 0xE3132B)   // roșu: identitate, highlight
    static let accentDk  = Color(hex: 0x9E0718)

    static let red       = Color(hex: 0xFF4D5E)   // stări negative pe fundal închis
    static let green     = Color(hex: 0x2FD58C)
    static let gold      = Color(hex: 0xF5B92E)

    // Cărțile (fețe albe)
    static let cardFace  = Color.white
    static let cardInk   = Color(hex: 0x17171C)
    static let cardRed   = Color(hex: 0xD3122A)
    static let cardEdge  = Color(hex: 0xDADAE0)

    static let avatarColors: [Color] = [
        primary,
        Color(hex: 0xE3132B),
        Color(hex: 0xF5B92E),
        Color(hex: 0x7B6CF6),
        Color(hex: 0x3AA0F0),
        Color(hex: 0xF0732E)
    ]

    static func font(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Titluri: condensat, foarte gros, cu majuscule (stil „afiș”).
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .default).width(.compressed)
    }

    static var backdrop: some View {
        ZStack {
            bg
            RadialGradient(colors: [accent.opacity(0.28), .clear],
                           center: .top, startRadius: 0, endRadius: 520)
        }
        .ignoresSafeArea()
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

struct PanelStyle: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Theme.line, lineWidth: 1))
            )
    }
}

extension View {
    func panel(padding: CGFloat = 16) -> some View { modifier(PanelStyle(padding: padding)) }
}

/// Buton principal: pastilă turcoaz, text negru.
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.primary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(17, .bold))
            .foregroundStyle(color == Theme.primary ? Theme.onPrimary : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Capsule().fill(color))
            .shadow(color: color.opacity(0.35), radius: 12, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}

/// Buton secundar: pastilă albă, text negru.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(17, .bold))
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Capsule().fill(Color.white))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}

struct IconButton: View {
    let system: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Theme.raised))
                .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Etichetă aurie mică, ca un „tag”.
struct GoldTag: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(Color.black)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(Theme.gold))
    }
}
