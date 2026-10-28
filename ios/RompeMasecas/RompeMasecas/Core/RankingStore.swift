import Foundation
import Observation

/// Guarda todas las partidas y eventos en el iPad.
/// - Datos: Documents/partidas.json
/// - Copia para analisis siempre actualizada: Documents/partidas.csv
///   (visible en la app Archivos › En mi iPad › Rompe-MASECAS)
@Observable
final class RankingStore {
    private(set) var records: [GameRecord] = []
    private(set) var events: [GameEvent] = []

    var mode: PlayerMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey) }
    }

    private static let modeKey = "rompeMasecasPlayerMode"

    private struct Snapshot: Codable {
        var records: [GameRecord]
        var events: [GameEvent]
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.modeKey)
        mode = saved.flatMap(PlayerMode.init(rawValue:)) ?? .nickname
        load()
        if events.isEmpty {
            events = [GameEvent(name: "Evento 1")]
            save()
        } else {
            WidgetBridge.publish(self)
        }
    }

    // MARK: - Leaderboard actual

    var currentEvent: GameEvent {
        events.last ?? GameEvent(name: "Evento 1")
    }

    /// Partidas del evento actual ordenadas por tiempo.
    var leaderboard: [GameRecord] {
        Self.ranked(records(for: currentEvent))
    }

    var top: [GameRecord] {
        Array(leaderboard.prefix(GameConfig.rankingLimit))
    }

    func position(of record: GameRecord) -> Int? {
        leaderboard.firstIndex { $0.id == record.id }.map { $0 + 1 }
    }

    func records(for event: GameEvent) -> [GameRecord] {
        records.filter { $0.eventId == event.id }
    }

    /// Completados primero por tiempo; los que no terminaron, por piezas colocadas.
    static func ranked(_ list: [GameRecord]) -> [GameRecord] {
        list.sorted { a, b in
            if a.completed != b.completed { return a.completed }
            if a.completed, a.timeMs != b.timeMs { return a.timeMs < b.timeMs }
            if !a.completed, a.piecesPlaced != b.piecesPlaced { return a.piecesPlaced > b.piecesPlaced }
            return a.playedAt < b.playedAt
        }
    }

    // MARK: - Cambios

    func add(_ record: GameRecord) {
        records.append(record)
        save()
    }

    /// "Reinicia" el leaderboard: arranca un evento nuevo, el historial se conserva.
    func startNewEvent(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        events.append(GameEvent(name: trimmed.isEmpty ? "Evento \(events.count + 1)" : trimmed))
        save()
    }

    func renameCurrentEvent(to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = events.indices.last else { return }
        events[i].name = trimmed
        save()
    }

    /// Borra todas las partidas y eventos.
    func deleteAll() {
        records = []
        events = [GameEvent(name: "Evento 1")]
        save()
    }

    // MARK: - Exportar

    /// CSV listo para Excel / Power BI. `event` nil = todas las partidas.
    func csv(for event: GameEvent? = nil) -> String {
        let iso = ISO8601DateFormatter()
        let day = DateFormatter()
        day.dateFormat = "yyyy-MM-dd"
        let hour = DateFormatter()
        hour.dateFormat = "HH:mm:ss"

        var eventNames: [UUID: String] = [:]
        var placeById: [UUID: Int] = [:]
        for ev in events {
            eventNames[ev.id] = ev.name
            for (i, r) in Self.ranked(records(for: ev)).enumerated() {
                placeById[r.id] = i + 1
            }
        }

        let header = [
            "id", "evento", "lugar_en_evento", "fecha", "hora", "fecha_iso", "modo", "nombre", "telefono",
            "producto", "completado", "tiempo", "tiempo_ms", "piezas_colocadas", "errores",
            "precision_pct", "ms_primera_pieza", "tiempos_piezas_ms"
        ]
        var lines = [header.joined(separator: ",")]

        let source = event.map { records(for: $0) } ?? records
        for r in source.sorted(by: { $0.playedAt < $1.playedAt }) {
            let fields: [String] = [
                r.id.uuidString,
                eventNames[r.eventId] ?? "",
                placeById[r.id].map { String($0) } ?? "",
                day.string(from: r.playedAt),
                hour.string(from: r.playedAt),
                iso.string(from: r.playedAt),
                r.mode.rawValue,
                r.name ?? "",
                r.phone ?? "",
                String(r.productId),
                r.completed ? "1" : "0",
                r.timeText,
                String(r.timeMs),
                String(r.piecesPlaced),
                String(r.wrongDrops),
                String(format: "%.1f", r.accuracy * 100),
                r.pieceTimesMs.first.map { String($0) } ?? "",
                r.pieceTimesMs.map { String($0) }.joined(separator: "|")
            ]
            lines.append(fields.map(Self.escape).joined(separator: ","))
        }
        // BOM para que Excel respete acentos.
        return "\u{FEFF}" + lines.joined(separator: "\n")
    }

    /// Escribe un CSV temporal para compartir (AirDrop, correo, Archivos...).
    func exportFile(for event: GameEvent? = nil) -> URL? {
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyyMMdd_HHmm"
        let suffix = event.map { "_" + Self.slug($0.name) } ?? "_todo"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rompe_masecas\(suffix)_\(stamp.string(from: .now)).csv")
        do {
            try csv(for: event).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Persistencia

    private var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var jsonURL: URL { documents.appendingPathComponent("partidas.json") }
    private var csvURL: URL { documents.appendingPathComponent("partidas.csv") }

    private func load() {
        guard let data = try? Data(contentsOf: jsonURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let snap = try? decoder.decode(Snapshot.self, from: data) {
            records = snap.records
            events = snap.events
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(Snapshot(records: records, events: events)) {
            try? data.write(to: jsonURL, options: .atomic)
        }
        try? csv().write(to: csvURL, atomically: true, encoding: .utf8)
        WidgetBridge.publish(self)
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func slug(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let chars = folded.lowercased().map { $0.isLetter || $0.isNumber ? $0 : Character("_") }
        return String(chars.prefix(30))
    }
}
