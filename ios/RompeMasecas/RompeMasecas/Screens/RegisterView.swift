import SwiftUI

struct RegisterView: View {
    @Environment(GameModel.self) private var game
    @State private var name = ""
    @State private var digits = ""
    @State private var showAdmin = false
    @State private var shakes: CGFloat = 0
    @FocusState private var nameFocused: Bool

    private var mode: PlayerMode { game.ranking.mode }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var nameValid: Bool { !mode.asksName || trimmedName.count >= 2 }
    private var phoneValid: Bool { !mode.asksPhone || digits.count == 10 }
    private var isValid: Bool { nameValid && phoneValid }

    var body: some View {
        HStack(spacing: 48) {
            brand
            form.frame(width: 380)
        }
        .padding(40)
        .frame(maxWidth: 940)
        .card(padding: 8)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.keyboard)
        .contentShape(Rectangle())
        .onTapGesture { nameFocused = false }
        .sheet(isPresented: $showAdmin) {
            AdminView()
        }
    }

    // MARK: - Marca

    private var brand: some View {
        VStack(spacing: 20) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 230, maxHeight: 290)
                // Mantener presionado 3 s: panel de administracion.
                .onLongPressGesture(minimumDuration: 3) {
                    nameFocused = false
                    showAdmin = true
                }

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
    }

    // MARK: - Captura

    private var form: some View {
        VStack(spacing: 14) {
            if mode.asksName {
                fieldLabel(mode == .nickname ? "¿Cómo te llamamos en el ranking?" : "Tu nombre o apodo")

                TextField("Nombre o apodo", text: $name)
                    .focused($nameFocused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(mode.asksPhone ? .done : .go)
                    .onSubmit {
                        if !mode.asksPhone { startTapped() }
                    }
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 64)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(borderColor(valid: trimmedName.count >= 2, focused: nameFocused), lineWidth: 2.5)
                    )
                    .modifier(Shake(animatableData: nameValid ? 0 : shakes))
                    .onChange(of: name) { _, newValue in
                        if newValue.count > GameConfig.nameMaxLength {
                            name = String(newValue.prefix(GameConfig.nameMaxLength))
                        }
                    }
            }

            if mode.asksPhone {
                fieldLabel(mode == .phone ? "Introduce tu número celular" : "Tu celular")

                Text(displayPhone)
                    .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(digits.isEmpty ? Theme.muted.opacity(0.5) : Theme.text)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(digits.count == 10 ? Theme.green : Theme.line, lineWidth: 2.5)
                    )
                    .modifier(Shake(animatableData: phoneValid ? 0 : shakes))

                Keypad(digits: $digits, keyHeight: mode == .both ? 52 : 60) {
                    nameFocused = false
                }
            }

            if mode == .nickname {
                Text("Aparecerás en el Top \(GameConfig.rankingLimit)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }

            Button("Empezar") { startTapped() }
                .buttonStyle(PrimaryButtonStyle())
                .opacity(isValid ? 1 : 0.5)
                .padding(.top, 4)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Theme.muted)
    }

    private func borderColor(valid: Bool, focused: Bool) -> Color {
        if valid { return Theme.green }
        return focused ? Theme.green.opacity(0.5) : Theme.line
    }

    private func startTapped() {
        guard isValid else {
            withAnimation(.linear(duration: 0.3)) { shakes += 1 }
            return
        }
        nameFocused = false
        game.start(
            name: mode.asksName ? trimmedName : nil,
            phone: mode.asksPhone ? digits : nil
        )
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
    var keyHeight: CGFloat = 60
    var onKey: () -> Void = {}

    private let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["borrar", "0", "limpiar"]
    ]

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 10) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { key in
                        Button {
                            onKey()
                            tap(key)
                        } label: {
                            label(for: key)
                                .frame(maxWidth: .infinity, minHeight: keyHeight)
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
