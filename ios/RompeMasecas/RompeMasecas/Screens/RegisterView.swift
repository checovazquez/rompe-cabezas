import SwiftUI

struct RegisterView: View {
    @Environment(GameModel.self) private var game
    @State private var name = ""
    @State private var digits = ""
    @State private var showAdmin = false
    @State private var shakes: CGFloat = 0
    @State private var appeared = false
    @FocusState private var nameFocused: Bool

    private var mode: PlayerMode { game.ranking.mode }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var nameValid: Bool { !mode.asksName || trimmedName.count >= 2 }
    private var phoneValid: Bool { !mode.asksPhone || digits.count == 10 }
    private var isValid: Bool { nameValid && phoneValid }

    var body: some View {
        HStack(spacing: 48) {
            brand
            form
                .frame(width: 440)
                .popIn(appeared, delay: 0.25, from: 0.85)
        }
        .padding(.horizontal, 56)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.keyboard)
        .contentShape(Rectangle())
        .onTapGesture { nameFocused = false }
        .onAppear { appeared = true }
        .sheet(isPresented: $showAdmin) {
            AdminView()
        }
    }

    // MARK: - Marca + top 3

    private var brand: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 80)
                .frame(width: 128, height: 128)
                .background(Circle().fill(Theme.yellow))
                .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 4))
                .background(Circle().fill(Theme.ink).offset(x: 6, y: 6))
                .wobble(5, base: -6, duration: 1.8)
                // Mantener presionado 3 s: panel de administracion.
                .onLongPressGesture(minimumDuration: 3) {
                    nameFocused = false
                    showAdmin = true
                }
                .popIn(appeared, from: 0.3)

            VStack(alignment: .leading, spacing: -18) {
                Text("ROMPE-")
                Text("MASECAS")
            }
            .font(.fiesta(102))
            .foregroundStyle(Theme.yellow)
            .shadow(color: Theme.ink, radius: 0, x: 5, y: 5)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .popIn(appeared, delay: 0.08, from: 0.6)

            HStack(spacing: 12) {
                chip("1. Memoriza", fill: Theme.cream)
                chip("2. Arma", fill: Theme.cream)
                chip("3. Gana", fill: Theme.yellow)
            }
            .popIn(appeared, delay: 0.16, from: 0.8)

            leaders
                .popIn(appeared, delay: 0.32, from: 0.9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chip(_ text: String, fill: Color) -> some View {
        Text(text)
            .font(.fiesta(22, .bold))
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 3))
    }

    private var leaders: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOY VAN GANANDO")
                .font(.fiesta(17, .bold))
                .tracking(1.5)
                .foregroundStyle(Theme.yellow)

            let top = Array(game.ranking.top.prefix(3))
            if top.isEmpty {
                Text("¡Sé el primero del ranking!")
                    .font(.fiesta(22, .bold))
                    .foregroundStyle(Theme.cream)
            } else {
                ForEach(0..<top.count, id: \.self) { i in
                    let r = top[i]
                    HStack(spacing: 14) {
                        Text("\(i + 1)")
                            .font(.fiesta(17))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Theme.medal(i + 1)))
                        Text(r.displayName)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(r.completed ? r.timeText : "\(r.piecesPlaced)/9")
                            .monospacedDigit()
                    }
                    .font(.fiesta(22, .bold))
                    .foregroundStyle(Theme.cream)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: 460, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.ink))
    }

    // MARK: - Captura

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            if mode.asksName {
                Text(mode == .nickname ? "¿Cómo te llamamos?" : "Tu nombre o apodo")
                    .font(.fiesta(mode == .nickname ? 30 : 24))

                TextField("Nombre o apodo", text: $name)
                    .focused($nameFocused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(mode.asksPhone ? .done : .go)
                    .onSubmit {
                        if !mode.asksPhone { startTapped() }
                    }
                    .font(.fiesta(32, .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 20)
                    .frame(height: 70)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.ink, lineWidth: nameFocused ? 4 : 3)
                    )
                    .modifier(Shake(animatableData: nameValid ? 0 : shakes))
                    .onChange(of: name) { _, newValue in
                        if newValue.count > GameConfig.nameMaxLength {
                            name = String(newValue.prefix(GameConfig.nameMaxLength))
                        }
                    }
            }

            if mode.asksPhone {
                Text(mode == .phone ? "Tu número celular" : "Tu celular")
                    .font(.fiesta(mode == .phone ? 30 : 24))

                Text(displayPhone)
                    .font(.fiesta(32, .bold).monospacedDigit())
                    .foregroundStyle(digits.isEmpty ? Theme.muted.opacity(0.6) : Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.ink, lineWidth: digits.count == 10 ? 4 : 3)
                    )
                    .modifier(Shake(animatableData: phoneValid ? 0 : shakes))

                Keypad(digits: $digits, keyHeight: mode == .both ? 50 : 58) {
                    nameFocused = false
                }
            }

            Button("¡A jugar!") { startTapped() }
                .buttonStyle(StickerButtonStyle(height: mode == .both ? 74 : 84))
                .pulse(isValid)
                .padding(.top, 6)
        }
        .padding(28)
        .sticker()
    }

    private func startTapped() {
        guard isValid else {
            SoundManager.shared.play(.wrong)
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
    var keyHeight: CGFloat = 58
    var onKey: () -> Void = {}

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
                            SoundManager.shared.play(.tap)
                            onKey()
                            tap(key)
                        } label: {
                            label(for: key)
                        }
                        .buttonStyle(StickerButtonStyle(fill: Theme.cream, height: keyHeight, fontSize: 30, radius: 14, depth: 4))
                        .accessibilityLabel(accessibility(for: key))
                    }
                }
            }
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func label(for key: String) -> some View {
        switch key {
        case "borrar":
            Image(systemName: "delete.left.fill").font(.system(size: 24, weight: .bold))
        case "limpiar":
            Text("Limpiar").font(.fiesta(18, .bold))
        default:
            Text(key)
        }
    }

    private func accessibility(for key: String) -> String {
        switch key {
        case "borrar": return "Borrar"
        case "limpiar": return "Limpiar"
        default: return key
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
