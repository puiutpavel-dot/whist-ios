import SwiftUI

// Stil „card-room”: negru adânc, roșu intens, accente aurii, butoane pilulă.
enum AvTheme {
    static let bg          = Color(avHex: 0x0A0A0C)
    static let surface     = Color(avHex: 0x15161B)
    static let surfaceHigh = Color(avHex: 0x1F2027)
    static let cell        = Color(avHex: 0x101116)
    static let gridLine    = Color.white.opacity(0.07)

    static let red         = Color(avHex: 0xE0102A)
    static let redDeep     = Color(avHex: 0x8A0716)
    static let gold        = Color(avHex: 0xF2C14E)
    static let goldDeep    = Color(avHex: 0xB8862B)

    static let text        = Color.white
    static let textDim     = Color.white.opacity(0.58)

    static let water       = Color(avHex: 0x4A86C5)
    static let hit         = Color(avHex: 0xFF8A1F)
    static let ship        = Color(avHex: 0xC9CED8)
    static let shipDark    = Color(avHex: 0x7D8494)

    static let goldGradient = LinearGradient(colors: [gold, goldDeep], startPoint: .top, endPoint: .bottom)
    static let redGradient  = LinearGradient(colors: [red, redDeep], startPoint: .top, endPoint: .bottom)
}

extension Color {
    init(avHex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((avHex >> 16) & 0xFF) / 255,
            green: Double((avHex >> 8) & 0xFF) / 255,
            blue: Double(avHex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Fundal

struct LoungeBackground: View {
    var body: some View {
        ZStack {
            AvTheme.bg
            RadialGradient(colors: [AvTheme.redDeep.opacity(0.55), .clear],
                           center: .top, startRadius: 0, endRadius: 520)
            RadialGradient(colors: [AvTheme.gold.opacity(0.06), .clear],
                           center: .bottom, startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Butoane

struct AvPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.heavy))
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(AvTheme.redGradient))
            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
            .shadow(color: AvTheme.red.opacity(isEnabled ? 0.45 : 0), radius: 14, y: 6)
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct AvSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .foregroundStyle(AvTheme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Capsule().fill(AvTheme.surfaceHigh))
            .overlay(Capsule().stroke(AvTheme.gold.opacity(0.35), lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Componente comune

struct Panel<Content: View>: View {
    var padding: CGFloat = 10
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AvTheme.surface))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.06), lineWidth: 1))
    }
}

struct SectionLabel: View {
    let text: LocalizedStringKey
    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .rounded).weight(.heavy))
            .tracking(1.6)
            .foregroundStyle(AvTheme.textDim)
    }
}

struct TopBar: View {
    let title: LocalizedStringKey
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundStyle(AvTheme.text)
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AvTheme.text)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(AvTheme.surfaceHigh))
                }
                Spacer()
            }
        }
    }
}

struct PlanesLeft: View {
    let remaining: Int
    let total: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Image(systemName: "airplane")
                    .font(.caption.weight(.bold))
                    .rotationEffect(.degrees(-90))
                    .foregroundStyle(i < remaining ? tint : AvTheme.textDim.opacity(0.3))
            }
        }
    }
}
