import SwiftUI

/// Ecrane scurte (iPhone SE, mini): totul se strânge ca să încapă fără scroll.
private struct CompactLayoutKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var compactLayout: Bool {
        get { self[CompactLayoutKey.self] }
        set { self[CompactLayoutKey.self] = newValue }
    }
}

/// Stil curat, luminos, „puzzle de relaxare”: fundal pastel, albastru calm, colțuri rotunjite, font rotunjit.
enum Theme {
    static let bg        = Color(red: 0.945, green: 0.957, blue: 0.988)
    static let surface   = Color.white
    static let primary   = Color(red: 0.231, green: 0.420, blue: 0.890)
    static let primaryDk = Color(red: 0.149, green: 0.278, blue: 0.690)
    static let soft      = Color(red: 0.882, green: 0.914, blue: 0.988)
    static let ink       = Color(red: 0.137, green: 0.176, blue: 0.290)
    static let muted     = Color(red: 0.522, green: 0.565, blue: 0.671)
    static let line      = Color(red: 0.878, green: 0.898, blue: 0.941)
    static let red       = Color(red: 0.902, green: 0.290, blue: 0.345)
    static let green     = Color(red: 0.180, green: 0.690, blue: 0.478)
    static let gold      = Color(red: 0.976, green: 0.749, blue: 0.231)

    static let avatarColors: [Color] = [
        primary,
        Color(red: 0.957, green: 0.502, blue: 0.392),
        Color(red: 0.400, green: 0.733, blue: 0.616),
        Color(red: 0.639, green: 0.494, blue: 0.894),
        Color(red: 0.969, green: 0.678, blue: 0.282),
        Color(red: 0.333, green: 0.678, blue: 0.890)
    ]

    static func font(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct PanelStyle: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.surface)
                    .shadow(color: Theme.primaryDk.opacity(0.08), radius: 14, y: 6)
            )
    }
}

extension View {
    func panel(padding: CGFloat = 16) -> some View { modifier(PanelStyle(padding: padding)) }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.primary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(18, .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(color)
                    .shadow(color: color.opacity(0.35), radius: 10, y: 5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(17, .semibold))
            .foregroundStyle(Theme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.soft))
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
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.primary)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Theme.surface).shadow(color: Theme.primaryDk.opacity(0.08), radius: 8, y: 3))
        }
        .buttonStyle(.plain)
    }
}
