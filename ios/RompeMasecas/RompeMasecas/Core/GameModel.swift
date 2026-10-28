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
    private(set) var playerName: String?
    private(set) var playerPhone: String?
    private(set) var product: Product?
    private(set) var previewRemaining = GameConfig.previewSeconds

    /// Las 20 piezas de la charola, en orden fijo durante la partida.
    private(set) var trayPieces: [Piece] = []
    /// Piezas ya colocadas: posicion -> pieza.
    private(set) var placed: [Int: Piece] = [:]

    private(set) var startDate: Date?
    private(set) var finalMs: Int?
    private(set) var lastRecord: GameRecord?

    // Metricas de la partida
    private var wrongDrops = 0
    private var pieceTimesMs: [Int] = []

    private var loopTask: Task<Void, Never>?
    private var lastUrgentSecond = 0
    private let sound = SoundManager.shared

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

    func start(name: String?, phone: String?) {
        loopTask?.cancel()
        playerName = name
        playerPhone = phone
        product = GameConfig.productIds.randomElement().map { Product(id: $0) }
        previewRemaining = GameConfig.previewSeconds
        screen = .preview
        sound.play(.start)

        loopTask = Task { @MainActor [self] in
            while previewRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                previewRemaining -= 1
                if previewRemaining > 0 {
                    sound.play(previewRemaining <= 3 ? .beep : .tick)
                }
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
        wrongDrops = 0
        pieceTimesMs = []
        finalMs = nil
        lastRecord = nil
        lastUrgentSecond = 0
        startDate = .now
        screen = .game
        sound.play(.go)

        loopTask = Task { @MainActor [self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                if Task.isCancelled { return }
                if elapsedMs >= GameConfig.maxGameMs {
                    finish(completed: false)
                    return
                }
                // Ultimos 10 s: tic de reloj y musica mas rapida.
                let secondsLeft = Int((Double(GameConfig.maxGameMs - elapsedMs) / 1000).rounded(.up))
                if secondsLeft <= 10, secondsLeft != lastUrgentSecond {
                    lastUrgentSecond = secondsLeft
                    sound.play(.tickUrgent)
                    sound.setMusicRate(1.12)
                }
            }
        }
    }

    /// Intenta soltar una pieza en una posicion del tablero (nil = fuera del tablero).
    func drop(_ piece: Piece, on position: Int?) -> DropResult {
        guard screen == .game, finalMs == nil, let product,
              let position, placed[position] == nil, !isPlaced(piece) else { return .ignored }

        guard piece.productId == product.id, piece.position == position else {
            wrongDrops += 1
            sound.play(.wrong)
            return .wrong
        }

        placed[position] = piece
        pieceTimesMs.append(elapsedMs)
        sound.playCorrect(placed.count)
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

        let record = GameRecord(
            eventId: ranking.currentEvent.id,
            mode: ranking.mode,
            name: playerName,
            phone: playerPhone,
            productId: product.id,
            completed: completed,
            timeMs: ms,
            piecesPlaced: placed.count,
            wrongDrops: wrongDrops,
            pieceTimesMs: pieceTimesMs,
            playedAt: .now
        )
        ranking.add(record)
        lastRecord = record

        let isFirstPlace = completed && ranking.position(of: record) == 1
        sound.playMusic(nil, fade: 0.3)
        if !completed { sound.play(.timeout) }

        // Pausa corta para que se vea la ultima pieza entrar.
        Task { @MainActor [self] in
            try? await Task.sleep(for: .milliseconds(completed ? 600 : 0))
            if completed { sound.play(isFirstPlace ? .record : .win) }
            if screen == .game { screen = .result }
        }
    }

    func reset() {
        loopTask?.cancel()
        loopTask = nil
        playerName = nil
        playerPhone = nil
        product = nil
        previewRemaining = GameConfig.previewSeconds
        trayPieces = []
        placed = [:]
        wrongDrops = 0
        pieceTimesMs = []
        startDate = nil
        finalMs = nil
        lastRecord = nil
        screen = .register
    }
}
