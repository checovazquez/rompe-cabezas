import SwiftUI
import CoreText

// MARK: - Colores (v2 · Fiesta de mercado)

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum Theme {
    static let green = Color(hex: 0x0E6B33)    // fondo
    static let ink = Color(hex: 0x0A3D1E)      // bordes, sombras y texto
    static let yellow = Color(hex: 0xFFD60A)
    static let cream = Color(hex: 0xFFF8E6)
    static let cream2 = Color(hex: 0xF4ECD6)
    static let boardBg = Color(hex: 0xF1E9D2)
    static let dashed = Color(hex: 0xC9BFA6)
    static let muted = Color(hex: 0x4A6B55)
    static let mint = Color(hex: 0xE8F5EC)
    static let orange = Color(hex: 0xFF8A3D)
    static let wrong = Color(hex: 0xE5383B)
    static let silver = Color(hex: 0xE6E1D3)
    static let bronze = Color(hex: 0xE0A458)

    static let confetti: [Color] = [yellow, cream, orange, Color(hex: 0x7ED957), Color(hex: 0x4CC9F0)]

    static func medal(_ position: Int) -> Color {
        switch position {
        case 1: return yellow
        case 2: return silver
        case 3: return bronze
        default: return .clear
        }
    }
}

// MARK: - Tipografia (Bricolage Grotesque, OFL)

enum AppFonts {
    static let files = ["BricolageGrotesque-Medium", "BricolageGrotesque-Bold", "BricolageGrotesque-ExtraBold"]

    /// Registra las fuentes del bundle (no hace falta tocar Info.plist).
    static func register() {
        for name in files {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    /// Fuente de la app. .medium / .bold / .heavy (ExtraBold).
    static func fiesta(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        let name: String
        if weight == .medium || weight == .regular {
            name = "BricolageGrotesque-Medium"
        } else if weight == .bold || weight == .semibold {
            name = "BricolageGrotesque-Bold"
        } else {
            name = "BricolageGrotesque-ExtraBold"
        }
        return .custom(name, size: size)
    }
}

// MARK: - Sticker: relleno + borde grueso + sombra solida desplazada

struct StickerModifier: ViewModifier {
    var fill: Color = Theme.cream
    var radius: CGFloat = 28
    var border: CGFloat = 4
    var shadow: CGFloat = 8

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(Theme.ink, lineWidth: border))
            .background(shape.fill(Theme.ink).offset(x: shadow, y: shadow))
    }
}

extension View {
    func sticker(fill: Color = Theme.cream, radius: CGFloat = 28, border: CGFloat = 4, shadow: CGFloat = 8) -> some View {
        modifier(StickerModifier(fill: fill, radius: radius, border: border, shadow: shadow))
    }
}

/// Boton que se "hunde" al presionarlo.
struct StickerButtonStyle: ButtonStyle {
    var fill: Color = Theme.yellow
    var height: CGFloat = 84
    var fontSize: CGFloat = 34
    var radius: CGFloat = 22
    var depth: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, style: self)
    }

    private struct StyledBody: View {
        let configuration: ButtonStyleConfiguration
        let style: StickerButtonStyle
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: style.radius, style: .continuous)
            let pressed = configuration.isPressed
            configuration.label
                .font(.fiesta(style.fontSize))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, minHeight: style.height)
                .background(shape.fill(style.fill))
                .overlay(shape.strokeBorder(Theme.ink, lineWidth: 4))
                .offset(y: pressed ? style.depth : 0)
                .background(shape.fill(Theme.ink).offset(y: style.depth))
                .opacity(isEnabled ? 1 : 0.55)
                .animation(.spring(response: 0.18, dampingFraction: 0.55), value: pressed)
        }
    }
}

/// Sacudida horizontal para piezas incorrectas.
struct Shake: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: amount * sin(animatableData * .pi * shakesPerUnit), y: 0)
        )
    }
}
