import SwiftUI

struct ResultView: View {
    @Environment(GameModel.self) private var game

    private var record: GameRecord? { game.lastRecord }
    private var completed: Bool { record?.completed ?? false }

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            // Resultado del jugador
            VStack(spacing: 16) {
                Text(completed ? "¡Lo lograste!" : "Tiempo agotado")
                    .font(.system(size: 50, weight: .black))
                    .foregroundStyle(completed ? Theme.green : Theme.wrong)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)

                if let name = record?.name, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(Theme.text)
                }

                if let product = game.product {
                    Image(product.imageName)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .frame(maxHeight: 220)
                }

                VStack(spacing: 2) {
                    Text(completed ? "Tu tiempo" : "Piezas colocadas")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.muted)
                    Text(completed ? formatTime(ms: record?.timeMs ?? 0) : "\(record?.piecesPlaced ?? 0) de 9")
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

                if let record, let pos = game.ranking.position(of: record) {
                    Text("Lugar #\(pos) de \(game.ranking.leaderboard.count)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.muted)
                }

                Spacer(minLength: 0)

                Button("Jugar de nuevo") { game.reset() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .frame(width: 340)

            // Top 20 del evento actual
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Top \(GameConfig.rankingLimit)")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(Theme.green)
                    Text(game.ranking.currentEvent.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }

                RankingColumns(entries: game.ranking.top, highlight: record?.id)
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
    let entries: [GameRecord]
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

    private func column(_ list: [GameRecord], offset: Int) -> some View {
        VStack(spacing: 6) {
            ForEach(0..<list.count, id: \.self) { i in
                let entry = list[i]
                let isMe = entry.id == highlight
                HStack {
                    Text("\(i + offset + 1).")
                        .frame(width: 36, alignment: .leading)
                        .foregroundStyle(Theme.muted)
                    Text(entry.displayName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                    Text(entry.completed ? entry.timeText : "\(entry.piecesPlaced)/9")
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
