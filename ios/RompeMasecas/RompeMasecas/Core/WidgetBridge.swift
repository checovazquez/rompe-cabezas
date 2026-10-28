import Foundation
import WidgetKit

/// Lo que la app le comparte al widget por el App Group.
/// Misma forma que `WidgetSnapshot` en RompeMasecasWidget.swift.
struct WidgetSnapshot: Codable {
    struct Row: Codable, Hashable {
        let name: String
        let time: String
        let completed: Bool
    }

    var eventName: String
    var games: Int
    var top: [Row]

    static let appGroup = "group.com.checovazquez.rompemasecas"
    static let key = "widgetSnapshot"
}

enum WidgetBridge {
    /// Publica el Top 5 del evento actual y pide al widget que se redibuje.
    /// En el ranking solo va el nombre visible (el celular sale enmascarado).
    static func publish(_ store: RankingStore) {
        let rows = store.top.prefix(5).map { r in
            WidgetSnapshot.Row(
                name: r.displayName,
                time: r.completed ? r.timeText : "\(r.piecesPlaced)/9",
                completed: r.completed
            )
        }
        let snapshot = WidgetSnapshot(
            eventName: store.currentEvent.name,
            games: store.leaderboard.count,
            top: Array(rows)
        )
        guard let defaults = UserDefaults(suiteName: WidgetSnapshot.appGroup),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: WidgetSnapshot.key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
