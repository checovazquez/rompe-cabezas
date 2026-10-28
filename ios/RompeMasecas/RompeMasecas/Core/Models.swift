import Foundation

enum GameConfig {
    /// Productos en juego. El 6 tiene piezas listas pero es casi igual al 1.
    static let productIds = [1, 2, 3, 4, 5]
    static let previewSeconds = 10
    static let maxGameMs = 60_000
    static let distractorCount = 11
    static let rankingLimit = 20
    static let nameMaxLength = 16
    /// Segundos en la pantalla de resultado antes de regresar solo al inicio.
    static let resultAutoResetSeconds = 45
}

/// Como se identifica al jugador (se elige en el panel admin).
enum PlayerMode: String, Codable, CaseIterable, Identifiable {
    case nickname, phone, both

    var id: Self { self }

    var label: String {
        switch self {
        case .nickname: return "Nombre / apodo"
        case .phone: return "Teléfono"
        case .both: return "Ambos"
        }
    }

    var asksName: Bool { self != .phone }
    var asksPhone: Bool { self != .nickname }
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

/// Un "leaderboard": se reinicia creando uno nuevo, sin perder el historial.
struct GameEvent: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var startedAt: Date = .now
}

/// Una partida jugada, con todo lo necesario para analisis posterior.
struct GameRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    let eventId: UUID
    let mode: PlayerMode
    let name: String?
    let phone: String?
    let productId: Int
    let completed: Bool
    let timeMs: Int
    let piecesPlaced: Int
    let wrongDrops: Int
    /// Milisegundos desde el arranque en que se coloco cada pieza, en orden.
    let pieceTimesMs: [Int]
    let playedAt: Date

    var maskedPhone: String? {
        guard let phone, phone.count >= 4 else { return phone }
        return "******" + phone.suffix(4)
    }

    /// Lo que se ve en el leaderboard.
    var displayName: String {
        if let name, !name.isEmpty { return name }
        return maskedPhone ?? "—"
    }

    var timeText: String { formatTime(ms: timeMs) }

    /// Fraccion de soltadas correctas sobre el total de intentos.
    var accuracy: Double {
        let attempts = piecesPlaced + wrongDrops
        return attempts == 0 ? 0 : Double(piecesPlaced) / Double(attempts)
    }
}

func formatTime(ms: Int) -> String {
    let cs = max(0, ms) / 10
    let minutes = cs / 6000
    let seconds = (cs % 6000) / 100
    let centis = cs % 100
    return String(format: "%02d:%02d.%02d", minutes, seconds, centis)
}
