import SwiftUI

struct PreviewView: View {
    @Environment(GameModel.self) private var game
    @State private var appeared = false

    private var urgent: Bool { game.previewRemaining <= 3 }

    var body: some View {
        HStack(spacing: 64) {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: -14) {
                    Text("¡MEMO-")
                    Text("RÍZALO!")
                }
                .font(.fiesta(96))
                .foregroundStyle(Theme.yellow)
                .shadow(color: Theme.ink, radius: 0, x: 5, y: 5)
                .popIn(appeared, from: 0.6)

                HStack(spacing: 24) {
                    ZStack {
                        Circle().fill(Theme.ink).offset(x: 7, y: 7)
                        Circle().fill(urgent ? Theme.orange : Theme.yellow)
                        Circle().strokeBorder(Theme.ink, lineWidth: 5)
                        Text("\(game.previewRemaining)")
                            .font(.fiesta(88))
                            .foregroundStyle(Theme.ink)
                            .id(game.previewRemaining)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 1.8).combined(with: .opacity),
                                removal: .scale(scale: 0.4).combined(with: .opacity)
                            ))
                    }
                    .frame(width: 170, height: 170)
                    .modifier(Shake(amount: 6, animatableData: urgent ? CGFloat(game.previewRemaining) : 0))
                    .animation(.spring(response: 0.35, dampingFraction: 0.5), value: game.previewRemaining)
                    .popIn(appeared, delay: 0.1, from: 0.3)

                    Text("segundos para\nmemorizar")
                        .font(.fiesta(30, .bold))
                        .foregroundStyle(Theme.cream)
                }

                Text("Después tendrás 1 minuto para armarlo.\n¡Ojo con las piezas trampa!")
                    .font(.fiesta(22, .medium))
                    .foregroundStyle(Theme.mint)
                    .lineSpacing(4)
                    .popIn(appeared, delay: 0.2, from: 0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let product = game.product {
                Image(product.imageName)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .frame(width: 480, height: 480)
                    .padding(22)
                    .sticker(fill: .white, radius: 36, border: 5, shadow: 12)
                    .wobble(1.5, base: -2, duration: 2.2)
                    .popIn(appeared, delay: 0.15, from: 0.5)
            }
        }
        .padding(.horizontal, 64)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { appeared = true }
    }
}
