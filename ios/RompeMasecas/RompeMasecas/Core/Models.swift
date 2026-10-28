import Foundation

enum GameConfig {
    /// Productos en juego. El 6 tiene piezas listas pero es casi igual al 1.
    static let productIds = [1, 2, 3, 4, 5]
    static let previewSeconds = 10
    static let maxGameMs = 60_000
    static let distractorCount = 11
    static let rankingLimit = 20
    /// Segundos en la pantalla de resultado antes de regresar solo al inicio.
    static let resultAutoResetSeconds = 45
}

struct Product: Identifiable, Hashable {
    let id: Int
    var imageName: String { "producto\(id)" }
}

struct Piece: Identifiable, Hashable {
    let productId: Int
    let position: Int // 1...9, de izquierda a derecha y de arriba a abajo
    var id: String { "p\(productId)_\(position)" }
    var imageName: String { id }

    static let all: [Piece] = GameConfig.productIds.flatMap { productId in
        (1...9).map { Piece(productId: productId, position: $0) }
    }
}

struct RankingEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    let phone: String
    let timeMs: Int
    let productId: Int
    let completed: Bool
    let playedAt: Date

    var maskedPhone: String {
        guard phone.count >= 4 else { return phone }
        return "******" + phone.suffix(4)
    }

    var timeText: String { formatTime(ms: timeMs) }
}

func formatTime(ms: Int) -> String {
    let cs = max(0, ms) / 10
    let minutes = cs / 6000
    let seconds = (cs % 6000) / 100
    let centis = cs % 100
    return String(format: "%02d:%02d.%02d", minutes, seconds, centis)
}
