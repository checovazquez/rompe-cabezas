import SwiftUI

struct PreviewView: View {
    @Environment(GameModel.self) private var game

    var body: some View {
        HStack(spacing: 48) {
            VStack(spacing: 24) {
                Text("Memoriza\nel producto")
                    .font(.system(size: 50, weight: .black))
                    .foregroundStyle(Theme.green)
                    .multilineTextAlignment(.center)

                Text("\(game.previewRemaining)")
                    .font(.system(size: 64, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.greenDark)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: game.previewRemaining)
                    .frame(width: 150, height: 150)
                    .background(Theme.yellow, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.green, lineWidth: 5))

                Text("Después tendrás 1 minuto\npara armarlo")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }

            if let product = game.product {
                Image(product.imageName)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .frame(maxWidth: 520, maxHeight: 520)
            }
        }
        .padding(36)
        .card(padding: 8)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
