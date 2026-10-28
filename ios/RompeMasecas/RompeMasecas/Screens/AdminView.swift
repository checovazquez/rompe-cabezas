import SwiftUI

/// Se abre manteniendo presionado el logo 3 s en la pantalla de registro.
struct AdminView: View {
    @Environment(GameModel.self) private var game
    @Environment(\.dismiss) private var dismiss

    @State private var exportAllURL: URL?
    @State private var exportCurrentURL: URL?

    @State private var askNewEvent = false
    @State private var askRename = false
    @State private var eventNameDraft = ""
    @State private var confirmDeleteAll = false

    private var store: RankingStore { game.ranking }

    var body: some View {
        @Bindable var ranking = game.ranking

        NavigationStack {
            Form {
                // 1. Identificacion del jugador
                Section {
                    Picker("Identificar jugador por", selection: $ranking.mode) {
                        ForEach(PlayerMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Jugadores")
                } footer: {
                    Text(modeFooter)
                }

                // 2. Leaderboard actual
                Section {
                    LabeledContent("Evento", value: store.currentEvent.name)
                    LabeledContent("Partidas", value: "\(store.leaderboard.count)")
                    if let best = store.leaderboard.first, best.completed {
                        LabeledContent("Mejor tiempo", value: "\(best.timeText)  ·  \(best.displayName)")
                    }
                    Button {
                        eventNameDraft = store.currentEvent.name
                        askRename = true
                    } label: {
                        Label("Renombrar evento", systemImage: "pencil")
                    }
                    Button {
                        eventNameDraft = ""
                        askNewEvent = true
                    } label: {
                        Label("Nuevo leaderboard", systemImage: "arrow.counterclockwise")
                    }
                } header: {
                    Text("Leaderboard actual")
                } footer: {
                    Text("“Nuevo leaderboard” deja el Top \(GameConfig.rankingLimit) en ceros. Las partidas anteriores se quedan guardadas para el análisis.")
                }

                // 3. Datos para analisis
                Section {
                    if let exportCurrentURL {
                        ShareLink(item: exportCurrentURL) {
                            Label("Exportar CSV · evento actual", systemImage: "square.and.arrow.up")
                        }
                    }
                    if let exportAllURL {
                        ShareLink(item: exportAllURL) {
                            Label("Exportar CSV · todas las partidas", systemImage: "square.and.arrow.up.on.square")
                        }
                    }
                } header: {
                    Text("Datos")
                } footer: {
                    Text("También hay un partidas.csv siempre actualizado en la app Archivos › En mi iPad › Rompe-MASECAS (o en Finder con el iPad conectado). Incluye tiempo, errores, precisión y el tiempo de cada pieza.")
                }

                // Historial por evento
                Section("Historial") {
                    LabeledContent("Total de partidas", value: "\(store.records.count)")
                    ForEach(Array(store.events.reversed())) { event in
                        EventSummaryRow(
                            event: event,
                            records: store.records(for: event),
                            isCurrent: event.id == store.currentEvent.id
                        )
                    }
                }

                // Zona peligrosa
                Section {
                    Button(role: .destructive) {
                        confirmDeleteAll = true
                    } label: {
                        Label("Borrar todos los datos", systemImage: "trash")
                    }
                    .disabled(store.records.isEmpty && store.events.count <= 1)
                } footer: {
                    Text("Para eventos: activa Acceso Guiado (Ajustes › Accesibilidad › Acceso guiado) y haz triple clic en el botón lateral para dejar el iPad fijo en el juego.")
                }
            }
            .navigationTitle("Administración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .alert("Nuevo leaderboard", isPresented: $askNewEvent) {
                TextField("Nombre del evento", text: $eventNameDraft)
                Button("Crear") {
                    store.startNewEvent(named: eventNameDraft)
                    refreshExports()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Ej. “Soriana Contry 28-oct”. El ranking actual se guarda en el historial.")
            }
            .alert("Renombrar evento", isPresented: $askRename) {
                TextField("Nombre del evento", text: $eventNameDraft)
                Button("Guardar") {
                    store.renameCurrentEvent(to: eventNameDraft)
                    refreshExports()
                }
                Button("Cancelar", role: .cancel) {}
            }
            .confirmationDialog("¿Borrar todos los datos?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
                Button("Borrar todo", role: .destructive) {
                    store.deleteAll()
                    refreshExports()
                }
            } message: {
                Text("Se eliminan todas las partidas y eventos. Exporta el CSV antes si lo necesitas.")
            }
        }
        .onAppear { refreshExports() }
    }

    private var modeFooter: String {
        switch store.mode {
        case .nickname:
            return "Solo se pide nombre o apodo y se muestra en el ranking."
        case .phone:
            return "Solo se pide celular; en el ranking se ve enmascarado (******1234)."
        case .both:
            return "Se pide apodo y celular. En el ranking se ve el apodo; el celular solo sale en el CSV."
        }
    }

    private func refreshExports() {
        exportCurrentURL = store.exportFile(for: store.currentEvent)
        exportAllURL = store.exportFile()
    }
}

private struct EventSummaryRow: View {
    let event: GameEvent
    let records: [GameRecord]
    let isCurrent: Bool

    private var completed: [GameRecord] { records.filter(\.completed) }

    private var bestText: String {
        completed.map(\.timeMs).min().map { formatTime(ms: $0) } ?? "—"
    }

    private var averageText: String {
        guard !completed.isEmpty else { return "—" }
        return formatTime(ms: completed.map(\.timeMs).reduce(0, +) / completed.count)
    }

    private var completionText: String {
        guard !records.isEmpty else { return "—" }
        return "\(Int((Double(completed.count) / Double(records.count) * 100).rounded()))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.name).font(.headline)
                if isCurrent {
                    Text("ACTUAL")
                        .font(.caption2.weight(.heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.yellow, in: Capsule())
                }
                Spacer()
                Text(event.startedAt, format: .dateTime.day().month().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(records.count) partidas · \(completionText) completadas · mejor \(bestText) · promedio \(averageText)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
