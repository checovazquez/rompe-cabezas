import SwiftUI

/// Se abre manteniendo presionado el logo 3 s en la pantalla de registro.
struct AdminView: View {
    @Environment(GameModel.self) private var game
    @Environment(\.dismiss) private var dismiss
    @State private var csvURL: URL?
    @State private var confirmClear = false

    private var entries: [RankingEntry] { game.ranking.entries }

    var body: some View {
        NavigationStack {
            Form {
                Section("Partidas") {
                    LabeledContent("Total", value: "\(entries.count)")
                    LabeledContent("Completadas", value: "\(entries.filter(\.completed).count)")
                    LabeledContent("Celulares únicos", value: "\(Set(entries.map(\.phone)).count)")
                    if let best = entries.first {
                        LabeledContent("Mejor tiempo", value: "\(best.timeText)  ·  \(best.maskedPhone)")
                    }
                }

                Section {
                    if let csvURL {
                        ShareLink(item: csvURL) {
                            Label("Exportar CSV (celulares completos)", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button(role: .destructive) {
                        confirmClear = true
                    } label: {
                        Label("Borrar ranking", systemImage: "trash")
                    }
                    .disabled(entries.isEmpty)
                } footer: {
                    Text("Para evento: activa Acceso Guiado (Ajustes › Accesibilidad › Acceso guiado) y triple clic al botón lateral para bloquear el iPad en el juego.")
                }
            }
            .navigationTitle("Administración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .confirmationDialog("¿Borrar todas las partidas?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Borrar todo", role: .destructive) {
                    game.ranking.clear()
                    csvURL = game.ranking.exportCSV()
                }
            } message: {
                Text("Exporta el CSV antes si necesitas los celulares.")
            }
        }
        .onAppear { csvURL = game.ranking.exportCSV() }
    }
}
