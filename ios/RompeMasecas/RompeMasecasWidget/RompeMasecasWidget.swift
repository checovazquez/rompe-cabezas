import WidgetKit
import SwiftUI

// MARK: - Datos que manda la app (misma forma que WidgetBridge.swift en la app)

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

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static let sample = WidgetSnapshot(
        eventName: "Soriana Contry",
        games: 47,
        top: [
            Row(name: "El Tigre", time: "00:18.42", completed: true),
            Row(name: "Memo R.", time: "00:21.07", completed: true),
            Row(name: "Caro", time: "00:23.90", completed: true),
            Row(name: "Lupita", time: "00:24.31", completed: true),
            Row(name: "Don Beto", time: "00:27.55", completed: true)
        ]
    )

    static let empty = WidgetSnapshot(eventName: "Evento 1", games: 0, top: [])
}

// MARK: - Timeline (la app pide recargar despues de cada partida)

struct RMEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> RMEntry {
        RMEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (RMEntry) -> Void) {
        let snap = context.isPreview ? .sample : (WidgetSnapshot.load() ?? .empty)
        completion(RMEntry(date: .now, snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RMEntry>) -> Void) {
        let entry = RMEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .empty)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

// MARK: - Estilo Fiesta (copia ligera del Theme de la app)

private enum W {
    static let green = Color(red: 14 / 255, green: 107 / 255, blue: 51 / 255)
    static let ink = Color(red: 10 / 255, green: 61 / 255, blue: 30 / 255)
    static let yellow = Color(red: 1, green: 214 / 255, blue: 10 / 255)
    static let cream = Color(red: 1, green: 248 / 255, blue: 230 / 255)
    static let cream2 = Color(red: 244 / 255, green: 236 / 255, blue: 214 / 255)
    static let muted = Color(red: 74 / 255, green: 107 / 255, blue: 85 / 255)
    static let mint = Color(red: 232 / 255, green: 245 / 255, blue: 236 / 255)
    static let silver = Color(red: 230 / 255, green: 225 / 255, blue: 211 / 255)
    static let bronze = Color(red: 224 / 255, green: 164 / 255, blue: 88 / 255)

    static func medal(_ pos: Int) -> Color {
        switch pos {
        case 1: return yellow
        case 2: return silver
        case 3: return bronze
        default: return .clear
        }
    }

    static func font(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        switch weight {
        case .medium, .regular: return .custom("BricolageGrotesque-Medium", size: size)
        case .bold, .semibold: return .custom("BricolageGrotesque-Bold", size: size)
        default: return .custom("BricolageGrotesque-ExtraBold", size: size)
        }
    }
}

private extension View {
    func sticker(_ fill: Color, radius: CGFloat = 20, border: CGFloat = 3, shadow: CGFloat = 5) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(W.ink, lineWidth: border))
            .background(shape.fill(W.ink).offset(x: shadow, y: shadow))
    }
}

// MARK: - Piezas

private struct Header: View {
    var iconSize: CGFloat
    var titleSize: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            Image("icono")
                .resizable()
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.23, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: iconSize * 0.23, style: .continuous)
                        .strokeBorder(W.ink, lineWidth: 3)
                )
                .background(
                    RoundedRectangle(cornerRadius: iconSize * 0.23, style: .continuous)
                        .fill(W.ink).offset(x: 3, y: 3)
                )
                .rotationEffect(.degrees(-6))

            VStack(alignment: .leading, spacing: -titleSize * 0.18) {
                Text("ROMPE-")
                Text("MASECAS")
            }
            .font(W.font(titleSize))
            .foregroundStyle(W.yellow)
            .shadow(color: W.ink, radius: 0, x: 3, y: 3)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }
}

private struct PlayButton: View {
    var fill: Color
    var expand: Bool

    var body: some View {
        Text("¡A jugar!")
            .font(W.font(22))
            .foregroundStyle(W.ink)
            .padding(.horizontal, 24)
            .frame(maxWidth: expand ? .infinity : nil, minHeight: 50)
            .sticker(fill, radius: 16, shadow: 0)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(W.ink).offset(y: 5)
            )
    }
}

private struct RecordCard: View {
    let best: WidgetSnapshot.Row?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(W.ink)
            VStack(alignment: .leading, spacing: 0) {
                Text("RÉCORD DE HOY")
                    .font(W.font(12, .bold))
                    .tracking(1)
                Text(best.map { "\($0.name) · \($0.time)" } ?? "¡Sé el primero!")
                    .font(W.font(24))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(W.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .sticker(W.yellow)
    }
}

private struct TopCard: View {
    let title: String
    let subtitle: String
    let rows: [WidgetSnapshot.Row]
    let rowHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(W.font(18))
                Spacer(minLength: 8)
                Text(subtitle)
                    .font(W.font(11, .bold))
                    .foregroundStyle(W.muted)
                    .lineLimit(1)
            }
            .padding(.bottom, 2)

            if rows.isEmpty {
                Spacer(minLength: 0)
                Text("Todavía no hay tiempos.\n¡Estrena el ranking!")
                    .font(W.font(15, .bold))
                    .foregroundStyle(W.muted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            } else {
                ForEach(0..<rows.count, id: \.self) { i in
                    let row = rows[i]
                    HStack(spacing: 8) {
                        Text("\(i + 1)")
                            .font(W.font(12))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(W.medal(i + 1)))
                        Text(row.name)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(row.time)
                            .monospacedDigit()
                            .foregroundStyle(row.completed ? W.ink : W.muted)
                    }
                    .font(W.font(15, .bold))
                    .padding(.horizontal, 6)
                    .frame(height: rowHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(i % 2 == 1 ? W.cream2 : Color.clear)
                    )
                }
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(W.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxHeight: .infinity, alignment: .top)
        .sticker(W.cream)
    }
}

// MARK: - Layouts por tamano

struct RompeMasecasWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RMEntry

    private var snap: WidgetSnapshot { entry.snapshot }
    private var best: WidgetSnapshot.Row? { snap.top.first(where: \.completed) }
    private var gamesText: String { snap.games == 1 ? "1 partida" : "\(snap.games) partidas" }

    var body: some View {
        Group {
            switch family {
            case .systemExtraLarge:
                extraLarge
            default:
                large
            }
        }
        .padding(.trailing, 5)
        .padding(.bottom, 5)
        .containerBackground(for: .widget) {
            ZStack {
                W.green
                Image("dots").resizable(resizingMode: .tile)
            }
        }
    }

    private var extraLarge: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                Header(iconSize: 60, titleSize: 32)
                Spacer(minLength: 10)
                RecordCard(best: best)
                Spacer(minLength: 10)
                HStack(spacing: 12) {
                    PlayButton(fill: W.cream, expand: false)
                    Text(gamesText)
                        .font(W.font(14, .medium))
                        .foregroundStyle(W.mint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TopCard(title: "Top 5", subtitle: snap.eventName, rows: Array(snap.top.prefix(5)), rowHeight: 34)
                .frame(width: 290)
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 14) {
            Header(iconSize: 50, titleSize: 27)
            TopCard(title: "Top 3 de hoy", subtitle: gamesText, rows: Array(snap.top.prefix(3)), rowHeight: 36)
            PlayButton(fill: W.yellow, expand: true)
        }
    }
}

// MARK: - Widget

struct RompeMasecasWidget: Widget {
    let kind = "RompeMasecasWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            RompeMasecasWidgetView(entry: entry)
        }
        .configurationDisplayName("Rompe-MASECAS")
        .description("Récord y mejores tiempos del evento. Tócalo para jugar.")
        .supportedFamilies([.systemLarge, .systemExtraLarge])
    }
}

#Preview(as: .systemExtraLarge) {
    RompeMasecasWidget()
} timeline: {
    RMEntry(date: .now, snapshot: .sample)
}

#Preview(as: .systemLarge) {
    RompeMasecasWidget()
} timeline: {
    RMEntry(date: .now, snapshot: .sample)
}
