import Foundation
import Observation

enum Screen: Equatable {
    case register, preview, game, result
}

enum DropResult {
    case correct, wrong, ignored
}

@Observable
final class GameModel {
    let ranking: RankingStore

    private(set) var screen: Screen = .register
    private(set) var phone = ""
    private(set) var product: Product?
    private(set) var previewRemaining = GameConfig.previewSeconds

    /// Las 20 piezas de la charola, en orden fijo durante la partida.
    private(set) var trayPieces: [Piece] = []
    /// Piezas ya colocadas: posicion -> pieza.
    private(set) var placed: [Int: Piece] = [:]

    private(set) var startDate: Date?
    private(set) var finalMs: Int?
    private(set) var lastEntry: RankingEntry?

    private var loopTask: Task<Void, Never>?

    init(ranking: RankingStore) {
        self.ranking = ranking
    }

    /// Tiempo transcurrido en ms (congelado al terminar).
    var elapsedMs: Int {
        if let finalMs { return finalMs }
        guard let startDate else { return 0 }
        return min(GameConfig.maxGameMs, Int(Date.now.timeIntervalSince(startDate) * 1000))
    }

    func isPlaced(_ piece: Piece) -> Bool {
        placed[piece.position] == piece
    }

    // MARK: - Flujo

    func start(phone: String) {
        loopTask?.cancel()
        self.phone = phone
        product = GameConfig.productIds.randomElement().map { Product(id: $0) }
        previewRemaining = GameConfig.previewSeconds
        screen = .preview

        loopTask = Task { @MainActor [self] in
            while previewRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                previewRemaining -= 1
            }
            startGame()
        }
    }

    private func startGame() {
        guard let product else { return }
        let correct = Piece.all.filter { $0.productId == product.id }
        let distractors = Piece.all.filter { $0.productId != product.id }
            .shuffled()
            .prefix(GameConfig.distractorCount)

        trayPieces = (correct + distractors).shuffled()
        placed = [:]
        finalMs = nil
        lastEntry = nil
        startDate = .now
        screen = .game

        loopTask = Task { @MainActor [self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                if Task.isCancelled { return }
                if elapsedMs >= GameConfig.maxGameMs {
                    finish(completed: false)
                    return
                }
            }
        }
    }

    /// Intenta soltar una pieza en una posicion del tablero (nil = fuera del tablero).
    func drop(_ piece: Piece, on position: Int?) -> DropResult {
        guard screen == .game, finalMs == nil, let product,
              let position, placed[position] == nil, !isPlaced(piece) else { return .ignored }

        guard piece.productId == product.id, piece.position == position else { return .wrong }

        placed[position] = piece
        if placed.count == 9 {
            finish(completed: true)
        }
        return .correct
    }

    private func finish(completed: Bool) {
        guard screen == .game, finalMs == nil, let product else { return }
        loopTask?.cancel()
        loopTask = nil

        let ms = completed ? elapsedMs : GameConfig.maxGameMs
        finalMs = ms

        let entry = RankingEntry(
            phone: phone,
            timeMs: ms,
            productId: product.id,
            completed: completed,
            playedAt: .now
        )
        ranking.add(entry)
        lastEntry = entry

        // Pausa corta para que se vea la ultima pieza entrar.
        Task { @MainActor [self] in
            try? await Task.sleep(for: .milliseconds(completed ? 600 : 0))
            if screen == .game { screen = .result }
        }
    }

    func reset() {
        loopTask?.cancel()
        loopTask = nil
        phone = ""
        product = nil
        previewRemaining = GameConfig.previewSeconds
        trayPieces = []
        placed = [:]
        startDate = nil
        finalMs = nil
        lastEntry = nil
        screen = .register
    }
}
