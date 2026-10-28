import SwiftUI

private let gameSpace = "game"

struct GameView: View {
    @Environment(GameModel.self) private var game

    @State private var slotFrames: [Int: CGRect] = [:]
    @State private var dragging: Piece?
    @State private var dragLocation: CGPoint = .zero
    @State private var shakes: [String: CGFloat] = [:]
    @State private var wrongId: String?
    @State private var flashPosition: Int?
    @State private var bursts: [Burst] = []
    @State private var appeared = false

    private struct Burst: Identifiable {
        let id = UUID()
        let point: CGPoint
    }

    var body: some View {
        GeometryReader { geo in
            let headerHeight: CGFloat = 96
            let bodyHeight = geo.size.height - headerHeight - 20
            let boardChrome: CGFloat = 70 // titulo + padding + borde de la tarjeta
            // Tablero cuadrado: las piezas recuperan la proporcion real del empaque.
            let boardSide = max(300, min(bodyHeight - boardChrome, geo.size.width * 0.5))

            VStack(spacing: 20) {
                header
                    .frame(height: headerHeight)

                HStack(alignment: .top, spacing: 22) {
                    trayCard
                        .frame(maxHeight: .infinity)
                    boardCard(side: boardSide)
                }
                .frame(height: bodyHeight)
            }
            // Solo fundido: escalar aqui moveria las casillas que detectan el arrastre.
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.35), value: appeared)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .coordinateSpace(.named(gameSpace))
        .overlay(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                ForEach(bursts) { burst in
                    ConfettiView(mode: .burst(burst.point), count: 22)
                }
                floatingPiece
            }
        }
        .overlay { GoSplash() }
        .onPreferenceChange(SlotFrameKey.self) { slotFrames = $0 }
        .onAppear { appeared = true }
    }

    // MARK: - Encabezado

    private var header: some View {
        HStack(spacing: 24) {
            HStack(spacing: 16) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(Theme.yellow))
                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 3))
                    .wobble(4, duration: 1.4)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ROMPE-MASECAS")
                        .font(.fiesta(36))
                        .foregroundStyle(Theme.yellow)
                        .shadow(color: Theme.ink, radius: 0, x: 3, y: 3)
                    Text(subtitle)
                        .font(.fiesta(18, .medium))
                        .foregroundStyle(Theme.mint)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ProgressDots(count: game.placed.count)

            TimerPill()
                .frame(width: 270, height: 88)
        }
    }

    private var subtitle: String {
        if let name = game.playerName, !name.isEmpty { return "\(name) · arma el empaque" }
        return "Arma el empaque"
    }

    // MARK: - Charola

    private var trayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Piezas").font(.fiesta(26))
                Spacer()
                Text("\(GameConfig.distractorCount) son trampa")
                    .font(.fiesta(16, .bold))
                    .foregroundStyle(Theme.muted)
            }
            tray
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sticker()
    }

    private var tray: some View {
        GeometryReader { geo in
            let gap: CGFloat = 12
            let layout = trayLayout(count: game.trayPieces.count, in: geo.size, gap: gap)
            let side = layout.side

            VStack(spacing: gap) {
                ForEach(0..<layout.rows, id: \.self) { r in
                    HStack(spacing: gap) {
                        ForEach(0..<layout.cols, id: \.self) { c in
                            let idx = r * layout.cols + c
                            if idx < game.trayPieces.count {
                                trayCell(game.trayPieces[idx], side: side)
                            } else {
                                Color.clear.frame(width: side, height: side)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    /// Columnas que dan la pieza cuadrada mas grande posible (deja aire para la sombra).
    private func trayLayout(count: Int, in space: CGSize, gap: CGFloat) -> (cols: Int, rows: Int, side: CGFloat) {
        var best = (cols: 4, rows: 5, side: CGFloat(40))
        for cols in 3...7 {
            let rows = Int((Double(max(count, 1)) / Double(cols)).rounded(.up))
            let side = min(
                (space.width - 4 - gap * CGFloat(cols - 1)) / CGFloat(cols),
                (space.height - 6 - gap * CGFloat(rows - 1)) / CGFloat(rows)
            )
            if side > best.side { best = (cols, rows, side) }
        }
        return best
    }

    private func trayCell(_ piece: Piece, side: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.dashed, style: StrokeStyle(lineWidth: 3, dash: [7, 6]))

            if !game.isPlaced(piece) {
                PieceTile(piece: piece, wrong: wrongId == piece.id)
                    .opacity(dragging == piece ? 0.2 : 1)
                    .modifier(Shake(animatableData: shakes[piece.id] ?? 0))
                    .contentShape(Rectangle())
                    .gesture(dragGesture(for: piece))
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .frame(width: side, height: side)
    }

    // MARK: - Tablero

    private func boardCard(side: CGFloat) -> some View {
        VStack(spacing: 10) {
            Text("Arma el producto")
                .font(.fiesta(26))
            board(side: side)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .sticker()
    }

    private func board(side: CGFloat) -> some View {
        let slot = side / 3
        return VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { c in
                        slotView(position: r * 3 + c, size: slot)
                    }
                }
            }
        }
        .frame(width: side, height: side)
        .background(Theme.boardBg)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.ink, lineWidth: 4)
        )
        .scaleEffect(game.placed.count == 9 ? 1.03 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.45), value: game.placed.count == 9)
    }

    private func slotView(position: Int, size: CGFloat) -> some View {
        let placedPiece = game.placed[position]
        let isHovered = dragging != nil && placedPiece == nil && hoveredPosition == position

        return ZStack {
            if let placedPiece {
                Image(placedPiece.imageName)
                    .resizable()
                    .transition(.scale(scale: 1.35).combined(with: .opacity))
            } else {
                Rectangle()
                    .strokeBorder(Theme.dashed, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                Text("\(position)")
                    .font(.fiesta(48))
                    .foregroundStyle(Theme.dashed.opacity(0.8))
            }

            if isHovered {
                Rectangle().fill(Theme.yellow.opacity(0.35))
                Rectangle().strokeBorder(Theme.ink, lineWidth: 4)
            }

            if flashPosition == position {
                Rectangle().fill(Theme.yellow.opacity(0.55))
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: SlotFrameKey.self,
                    value: [position: geo.frame(in: .named(gameSpace))]
                )
            }
        )
    }

    // MARK: - Arrastre

    private var hoveredPosition: Int? {
        slotFrames.first { $0.value.contains(dragLocation) }?.key
    }

    private var floatingSize: CGFloat {
        slotFrames[1]?.width ?? 150
    }

    @ViewBuilder
    private var floatingPiece: some View {
        if let dragging {
            PieceTile(piece: dragging, lifted: true)
                .frame(width: floatingSize, height: floatingSize)
                .position(dragLocation)
                .allowsHitTesting(false)
        }
    }

    private func dragGesture(for piece: Piece) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(gameSpace))
            .onChanged { value in
                if dragging == nil {
                    dragging = piece
                    SoundManager.shared.play(.pickup)
                }
                guard dragging == piece else { return } // un solo dedo a la vez
                dragLocation = value.location
            }
            .onEnded { value in
                guard dragging == piece else { return }
                let target = slotFrames.first { $0.value.contains(value.location) }?.key

                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    switch game.drop(piece, on: target) {
                    case .correct:
                        if let target {
                            flash(target)
                            if let frame = slotFrames[target] {
                                celebrate(at: CGPoint(x: frame.midX, y: frame.midY))
                            }
                        }
                    case .wrong:
                        markWrong(piece)
                    case .ignored:
                        break
                    }
                    dragging = nil
                }
            }
    }

    private func flash(_ position: Int) {
        flashPosition = position
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.easeOut(duration: 0.25)) {
                if flashPosition == position { flashPosition = nil }
            }
        }
    }

    private func celebrate(at point: CGPoint) {
        let burst = Burst(point: point)
        bursts.append(burst)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1300))
            bursts.removeAll { $0.id == burst.id }
        }
    }

    private func markWrong(_ piece: Piece) {
        wrongId = piece.id
        withAnimation(.linear(duration: 0.3)) {
            shakes[piece.id, default: 0] += 1
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            if wrongId == piece.id { wrongId = nil }
        }
    }
}

// MARK: - Componentes

/// 9 puntos que se llenan con rebote.
private struct ProgressDots: View {
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...9, id: \.self) { i in
                Circle()
                    .fill(i <= count ? Theme.yellow : Color.clear)
                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 3))
                    .frame(width: 22, height: 22)
                    .scaleEffect(i == count ? 1.25 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.4), value: count)
            }
            Text("\(count)/9")
                .font(.fiesta(26))
                .foregroundStyle(Theme.cream)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: count)
                .padding(.leading, 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) de 9 piezas")
    }
}

/// Tiempo en sticker; los ultimos 10 s se pone naranja y late.
private struct TimerPill: View {
    @Environment(GameModel.self) private var game

    var body: some View {
        TimelineView(.animation) { _ in
            let ms = game.elapsedMs
            let left = GameConfig.maxGameMs - ms
            let remaining = Double(left) / Double(GameConfig.maxGameMs)
            let urgent = left <= 10_000
            let beat = urgent && (left / 500) % 2 == 0

            VStack(spacing: 6) {
                Text(formatTime(ms: ms))
                    .font(.fiesta(44).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                GeometryReader { bar in
                    Capsule().fill(Theme.ink.opacity(0.2))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Theme.ink)
                                .frame(width: bar.size.width * max(0, remaining))
                        }
                }
                .frame(height: 8)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sticker(fill: urgent ? Theme.orange : Theme.yellow, radius: 24, border: 4, shadow: 6)
            .scaleEffect(beat ? 1.05 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: beat)
        }
    }
}

struct PieceTile: View {
    let piece: Piece
    var wrong = false
    var lifted = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Image(piece.imageName)
            .resizable() // cuadrado: corrige el estirado original de las piezas
            .background(.white)
            .clipShape(shape)
            .overlay(shape.strokeBorder(wrong ? Theme.wrong : Theme.ink, lineWidth: wrong ? 4 : 3))
            .background(shape.fill(Theme.ink).offset(y: lifted ? 10 : 4))
            .rotationEffect(.degrees(lifted ? -5 : 0))
            .scaleEffect(lifted ? 1.08 : 1)
    }
}

private struct SlotFrameKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}
