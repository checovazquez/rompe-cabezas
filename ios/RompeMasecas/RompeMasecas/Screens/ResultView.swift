import SwiftUI

struct ResultView: View {
    @Environment(GameModel.self) private var game

    private var completed: Bool { game.lastEntry?.completed ?? false }

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            // Resultado del jugador
            VStack(spacing: 18) {
                Text(completed ? "¡Lo lograste!" : "Tiempo agotado")
                    .font(.system(size: 50, weight: .black))
                    .foregroundStyle(completed ? Theme.green : Theme.wrong)
                    .multilineTextAlignment(.center)

                if let product = game.product {
                    Image(product.imageName)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .frame(maxHeight: 260)
                }

                VStack(spacing: 2) {
                    Text("Tu tiempo")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.muted)
                    Text(formatTime(ms: game.lastEntry?.timeMs ?? 0))
                        .font(.system(size: 46, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.greenDark)
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Theme.yellow, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Theme.green, lineWidth: 3)
                )

                if let entry = game.lastEntry, let pos = game.ranking.position(of: entry) {
                    Text("Lugar #\(pos) de \(game.ranking.entries.count)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.muted)
                }

                Spacer(minLength: 0)

                Button("Jugar de nuevo") { game.reset() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .frame(width: 340)

            // Top 20
            VStack(alignment: .leading, spacing: 12) {
                Text("Top \(GameConfig.rankingLimit)")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(Theme.green)

                RankingColumns(entries: game.ranking.top, highlight: game.lastEntry?.id)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(32)
        .frame(maxWidth: 1060, maxHeight: 660)
        .card(padding: 8)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            // Modo kiosco: regresar solo al inicio.
            try? await Task.sleep(for: .seconds(GameConfig.resultAutoResetSeconds))
            if !Task.isCancelled && game.screen == .result { game.reset() }
        }
    }
}

private struct RankingColumns: View {
    let entries: [RankingEntry]
    let highlight: UUID?

    var body: some View {
        if entries.isEmpty {
            Text("Todavía no hay tiempos registrados.")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.muted)
        } else {
            let half = (GameConfig.rankingLimit + 1) / 2
            HStack(alignment: .top, spacing: 16) {
                column(Array(entries.prefix(half)), offset: 0)
                column(Array(entries.dropFirst(half)), offset: half)
            }
        }
    }

    private func column(_ list: [RankingEntry], offset: Int) -> some View {
        VStack(spacing: 6) {
            ForEach(0..<list.count, id: \.self) { i in
                let entry = list[i]
                let isMe = entry.id == highlight
                HStack {
                    Text("\(i + offset + 1).")
                        .frame(width: 36, alignment: .leading)
                        .foregroundStyle(Theme.muted)
                    Text(entry.maskedPhone)
                    Spacer()
                    Text(entry.timeText)
                        .foregroundStyle(entry.completed ? Theme.greenDark : Theme.muted)
                }
                .font(.system(size: 17, weight: isMe ? .heavy : .semibold).monospacedDigit())
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(
                    isMe ? Theme.yellow : Theme.bg.opacity(0.7),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
