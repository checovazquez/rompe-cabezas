import SwiftUI

@main
struct RompeMasecasApp: App {
    @State private var game = GameModel(ranking: RankingStore())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(game)
                .onAppear {
                    // Modo kiosco: que la pantalla no se apague.
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
    }
}

struct RootView: View {
    @Environment(GameModel.self) private var game

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            switch game.screen {
            case .register:
                RegisterView().transition(.opacity)
            case .preview:
                PreviewView().transition(.opacity)
            case .game:
                GameView().transition(.opacity)
            case .result:
                ResultView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: game.screen)
        .onChange(of: game.screen, initial: true) { _, screen in
            // Musica por pantalla; el conteo y el resultado van sin musica.
            switch screen {
            case .register: SoundManager.shared.playMusic(.menu)
            case .preview: SoundManager.shared.playMusic(nil)
            case .game: SoundManager.shared.playMusic(.game)
            case .result: break // el GameModel ya la apago con fade
            }
        }
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.light)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}
