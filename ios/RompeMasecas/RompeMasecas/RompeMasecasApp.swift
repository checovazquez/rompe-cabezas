import SwiftUI

@main
struct RompeMasecasApp: App {
    @State private var game = GameModel(ranking: RankingStore())

    init() {
        AppFonts.register()
    }

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

    private var screenTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.94).combined(with: .opacity),
            removal: .scale(scale: 1.04).combined(with: .opacity)
        )
    }

    var body: some View {
        ZStack {
            DotsBackground()

            switch game.screen {
            case .register:
                RegisterView().transition(screenTransition)
            case .preview:
                PreviewView().transition(screenTransition)
            case .game:
                GameView().transition(.opacity)
            case .result:
                ResultView().transition(screenTransition)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: game.screen)
        .onChange(of: game.screen, initial: true) { _, screen in
            // Musica por pantalla; el conteo y el resultado van sin musica.
            switch screen {
            case .register: SoundManager.shared.playMusic(.menu)
            case .preview: SoundManager.shared.playMusic(nil)
            case .game: SoundManager.shared.playMusic(.game)
            case .result: break // el GameModel ya la apago con fade
            }
        }
        .foregroundStyle(Theme.ink)
        .preferredColorScheme(.light)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}
