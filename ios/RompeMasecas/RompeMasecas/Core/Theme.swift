import SwiftUI

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
    static let green = Color(hex: 0x0F7A3A)
    static let greenDark = Color(hex: 0x0B5F2D)
    static let yellow = Color(hex: 0xF3DD8A)
    static let bg = Color(hex: 0xF3F0EB)
    static let card = Color.white
    static let line = Color(hex: 0xD9CFC5)
    static let dashed = Color(hex: 0xD8CBBF)
    static let text = Color(hex: 0x2A2A2A)
    static let muted = Color(hex: 0x6E6A66)
    static let pieceBorder = Color(hex: 0x444444)
    static let wrong = Color(hex: 0xD62828)
    static let radius: CGFloat = 24
}

struct CardModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.08), radius: 15, y: 10)
    }
}

extension View {
    func card(padding: CGFloat = 20) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration)
    }

    private struct PrimaryButtonBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .frame(minWidth: 260, minHeight: 64)
                .background(
                    Theme.green.opacity(isEnabled ? 1 : 0.35),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .shadow(color: .black.opacity(isEnabled ? 0.12 : 0), radius: 10, y: 6)
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
