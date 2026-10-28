import SwiftUI

struct ResultView: View {
    @Environment(GameModel.self) private var game
    @State private var appeared = false
    @State private var appearDate = Date.now

    private var record: GameRecord? { game.lastRecord }
    private var completed: Bool { record?.completed ?? false }
    private var position: Int? { record.flatMap { game.ranking.position(of: $0) } }
    private var isRecord: Bool { completed && position == 1 }

    var body: some View {
        HStack(spacing: 40) {
            summary
                .frame(width: 500)
            leaderboard
                .popIn(appeared, delay: 0.2, from: 0.92)
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if completed {
                ConfettiView(mode: .rain, count: isRecord ? 230 : 140)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            appearDate = .now
            appeared = true
        }
        .task {
            // Modo kiosco: regresar solo al inicio.
            try? await Task.sleep(for: .seconds(GameConfig.resultAutoResetSeconds))
            if !Task.isCancelled && game.screen == .result { game.reset() }
        }
    }

    // MARK: - Resumen del jugador

    private var summary: some View {
        VStack(spacing: 20) {
            if isRecord {
                Text("¡NUEVO RÉCORD!")
                    .font(.fiesta(26))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .sticker(fill: Theme.orange, radius: 999, border: 3, shadow: 4)
                    .wobble(4, base: -4, duration: 0.6)
                    .popIn(appeared, delay: 0.35, from: 0.2)
            }

            VStack(spacing: -12) {
                Text(completed ? "¡LO" : "¡SE ACABÓ")
                Text(completed ? "LOGRASTE!" : "EL TIEMPO!")
            }
            .font(.fiesta(completed ? 84 : 70))
            .foregroundStyle(completed ? Theme.yellow : Theme.cream)
            .shadow(color: Theme.ink, radius: 0, x: 5, y: 5)
            .multilineTextAlignment(.center)
            .popIn(appeared, from: 0.4)

            HStack(spacing: 22) {
                if let product = game.product {
                    Image(product.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 130, height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(caption)
                        .font(.fiesta(19, .bold))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                    if completed {
                        CountUpTime(finalMs: record?.timeMs ?? 0, start: appearDate)
                    } else {
                        Text("\(record?.piecesPlaced ?? 0) de 9")
                            .font(.fiesta(60))
                    }
                    Text(stats)
                        .font(.fiesta(19, .bold))
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .sticker()
            .rotationEffect(.degrees(-2))
            .popIn(appeared, delay: 0.1, from: 0.7)

            if let position {
                Text("Lugar #\(position) de \(game.ranking.leaderboard.count)")
                    .font(.fiesta(30))
                    .padding(.horizontal, 26)
                    .padding(.vertical, 10)
                    .sticker(fill: Theme.yellow, radius: 999, border: 4, shadow: 5)
                    .popIn(appeared, delay: 0.5, from: 0.3)
            }

            VStack(spacing: 8) {
                Button("Jugar de nuevo") { game.reset() }
                    .buttonStyle(StickerButtonStyle(fill: Theme.cream, height: 76, fontSize: 30))
                    .frame(width: 320)
                TimelineView(.periodic(from: appearDate, by: 1)) { context in
                    let left = max(0, GameConfig.resultAutoResetSeconds - Int(context.date.timeIntervalSince(appearDate)))
                    Text("Regresa al inicio en \(left) s")
                        .font(.fiesta(16, .medium))
                        .foregroundStyle(Theme.mint)
                        .monospacedDigit()
                }
            }
            .padding(.top, 4)
            .popIn(appeared, delay: 0.6, from: 0.9)
        }
    }

    private var caption: String {
        let name = record?.name.flatMap { $0.isEmpty ? nil : $0 }
        if completed { return name.map { "\($0), tu tiempo" } ?? "Tu tiempo" }
        return name.map { "\($0), colocaste" } ?? "Colocaste"
    }

    private var stats: String {
        guard let record else { return "" }
        let errors = record.wrongDrops == 1 ? "1 error" : "\(record.wrongDrops) errores"
        return "\(errors) · \(Int((record.accuracy * 100).rounded()))% precisión"
    }

    // MARK: - Top 20

    private var leaderboard: some View {
        let entries = game.ranking.top
        let half = (GameConfig.rankingLimit + 1) / 2

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Top \(GameConfig.rankingLimit)").font(.fiesta(32))
                Spacer(minLength: 12)
                Text(game.ranking.currentEvent.name)
                    .font(.fiesta(17, .bold))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }

            if entries.isEmpty {
                Text("Todavía no hay tiempos registrados.")
                    .font(.fiesta(20, .bold))
                    .foregroundStyle(Theme.muted)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    column(Array(entries.prefix(half)), offset: 0)
                    column(Array(entries.dropFirst(half)), offset: half)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sticker()
    }

    private func column(_ list: [GameRecord], offset: Int) -> some View {
        VStack(spacing: 6) {
            ForEach(0..<list.count, id: \.self) { i in
                let entry = list[i]
                let pos = i + offset + 1
                let isMe = entry.id == record?.id
                HStack(spacing: 10) {
                    Text("\(pos)")
                        .font(.fiesta(15))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.medal(pos)))
                    Text(entry.displayName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 6)
                    Text(entry.completed ? entry.timeText : "\(entry.piecesPlaced)/9")
                        .monospacedDigit()
                        .foregroundStyle(entry.completed ? Theme.ink : Theme.muted)
                }
                .font(.fiesta(19, isMe ? .heavy : .bold))
                .padding(.horizontal, 10)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isMe ? Theme.yellow : (pos % 2 == 0 ? Theme.cream2 : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isMe ? Theme.ink : Color.clear, lineWidth: 3)
                )
                .popIn(appeared, delay: 0.3 + Double(pos) * 0.03, from: 0.85)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

/// El tiempo "corre" de 0 al resultado al entrar.
private struct CountUpTime: View {
    let finalMs: Int
    let start: Date
    private let duration: Double = 0.9

    var body: some View {
        TimelineView(.animation) { context in
            let t = min(1, max(0, (context.date.timeIntervalSince(start) - 0.2) / duration))
            let eased = 1 - pow(1 - t, 3)
            Text(formatTime(ms: Int(Double(finalMs) * eased)))
                .font(.fiesta(60).monospacedDigit())
        }
    }
}
