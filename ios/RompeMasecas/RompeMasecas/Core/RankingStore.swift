import Foundation
import Observation

/// Guarda todas las partidas en el iPad (equivalente al localStorage del web).
@Observable
final class RankingStore {
    private(set) var entries: [RankingEntry] = []
    private let key = "rompeMasecasRanking"

    init() {
        load()
    }

    var top: [RankingEntry] {
        Array(entries.prefix(GameConfig.rankingLimit))
    }

    func add(_ entry: RankingEntry) {
        entries.append(entry)
        entries.sort {
            $0.timeMs != $1.timeMs ? $0.timeMs < $1.timeMs : $0.playedAt < $1.playedAt
        }
        save()
    }

    func position(of entry: RankingEntry) -> Int? {
        entries.firstIndex { $0.id == entry.id }.map { $0 + 1 }
    }

    func clear() {
        entries = []
        save()
    }

    /// CSV con todas las partidas (celular completo) para exportar desde el panel admin.
    func exportCSV() -> URL? {
        let iso = ISO8601DateFormatter()
        var lines = ["posicion,celular,tiempo,tiempo_ms,completado,producto,fecha"]
        for (i, e) in entries.enumerated() {
            lines.append("\(i + 1),\(e.phone),\(e.timeText),\(e.timeMs),\(e.completed ? "si" : "no"),\(e.productId),\(iso.string(from: e.playedAt))")
        }
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyyMMdd_HHmm"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rompe_masecas_\(stamp.string(from: .now)).csv")
        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RankingEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
