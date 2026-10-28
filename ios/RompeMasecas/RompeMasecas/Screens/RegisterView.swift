import SwiftUI

struct RegisterView: View {
    @Environment(GameModel.self) private var game
    @State private var digits = ""
    @State private var showAdmin = false
    @State private var shakes: CGFloat = 0

    private var isValid: Bool { digits.count == 10 }

    var body: some View {
        HStack(spacing: 48) {
            // Marca
            VStack(spacing: 20) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 230, maxHeight: 290)
                    // Mantener presionado 3 s: panel de administracion.
                    .onLongPressGesture(minimumDuration: 3) { showAdmin = true }

                Text("ROMPE-MASECAS")
                    .font(.system(size: 52, weight: .black))
                    .foregroundStyle(Theme.green)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text("Memoriza el producto y ármalo\nen menos de 1 minuto")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            // Captura de celular
            VStack(spacing: 18) {
                Text("Introduce tu número celular")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.muted)

                Text(displayPhone)
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(digits.isEmpty ? Theme.muted.opacity(0.5) : Theme.text)
                    .frame(maxWidth: .infinity, minHeight: 70)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isValid ? Theme.green : Theme.line, lineWidth: 2.5)
                    )
                    .modifier(Shake(animatableData: shakes))

                Keypad(digits: $digits)

                Button("Empezar") {
                    if isValid {
                        game.start(phone: digits)
                    } else {
                        withAnimation(.linear(duration: 0.3)) { shakes += 1 }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .opacity(isValid ? 1 : 0.5)
            }
            .frame(width: 380)
        }
        .padding(40)
        .frame(maxWidth: 940)
        .card(padding: 8)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showAdmin) {
            AdminView()
        }
    }

    /// "81 2345 6789" con guiones bajos para lo que falta.
    private var displayPhone: String {
        if digits.isEmpty { return "10 dígitos" }
        let padded = Array(digits.padding(toLength: 10, withPad: "_", startingAt: 0))
        return String(padded[0..<2]) + " " + String(padded[2..<6]) + " " + String(padded[6..<10])
    }
}

private struct Keypad: View {
    @Binding var digits: String

    private let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["borrar", "0", "limpiar"]
    ]

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { key in
                        Button {
                            tap(key)
                        } label: {
                            label(for: key)
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Theme.line, lineWidth: 2)
                                )
                        }
                        .buttonStyle(KeyStyle())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func label(for key: String) -> some View {
        switch key {
        case "borrar":
            Image(systemName: "delete.left.fill").font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.muted)
        case "limpiar":
            Text("Limpiar").font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.muted)
        default:
            Text(key).font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text)
        }
    }

    private func tap(_ key: String) {
        switch key {
        case "borrar":
            if !digits.isEmpty { digits.removeLast() }
        case "limpiar":
            digits = ""
        default:
            if digits.count < 10 { digits.append(key) }
        }
    }
}

private struct KeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
