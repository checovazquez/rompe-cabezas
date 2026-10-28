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
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.light)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}
