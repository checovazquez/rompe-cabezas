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

    var body: some View {
        GeometryReader { geo in
            let timerHeight: CGFloat = 104
            let boardChrome: CGFloat = 72 // titulo + padding de la tarjeta
            let boardHeight = max(300, geo.size.height - timerHeight - 16 - boardChrome)
            // Las piezas salen de la foto cuadrada estirada a 4:5; en cuadrado recuperan su proporcion real.
            let boardSide = min(boardHeight, geo.size.width * 0.5)
            let boardSize = CGSize(width: boardSide, height: boardSide)

            HStack(spacing: 18) {
                leftPanel
                rightPanel(boardSize: boardSize, timerHeight: timerHeight)
                    .frame(width: boardSize.width + 30)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .coordinateSpace(.named(gameSpace))
        .overlay(alignment: .topLeading) { floatingPiece }
        .onPreferenceChange(SlotFrameKey.self) { slotFrames = $0 }
    }

    // MARK: - Izquierda: instrucciones + charola

    private var leftPanel: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ROMPE-MASECAS")
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(Theme.green)
                Text("Arrastra las piezas correctas al lugar correcto. Tienes 1 minuto.")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 16)

            VStack(alignment: .leading, spacing: 10) {
                Text("Piezas")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Theme.green)

                tray
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Theme.dashed, style: StrokeStyle(lineWidth: 3, dash: [9, 7]))
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .card(padding: 14)
        }
    }

    private var tray: some View {
        GeometryReader { geo in
            let gap: CGFloat = 12
            let layout = trayLayout(count: game.trayPieces.count, in: geo.size, gap: gap)
            let cols = layout.cols
            let rows = layout.rows
            let size = CGSize(width: layout.side, height: layout.side)

            VStack(spacing: gap) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: gap) {
                        ForEach(0..<cols, id: \.self) { c in
                            let idx = r * cols + c
                            if idx < game.trayPieces.count {
                                trayCell(game.trayPieces[idx], size: size)
                            } else {
                                Color.clear.frame(width: size.width, height: size.height)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Columnas que dan la pieza cuadrada mas grande posible en el espacio disponible.
    private func trayLayout(count: Int, in space: CGSize, gap: CGFloat) -> (cols: Int, rows: Int, side: CGFloat) {
        var best = (cols: 5, rows: 4, side: CGFloat(40))
        for cols in 3...7 {
            let rows = Int((Double(max(count, 1)) / Double(cols)).rounded(.up))
            let side = min(
                (space.width - gap * CGFloat(cols - 1)) / CGFloat(cols),
                (space.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
            )
            if side > best.side { best = (cols, rows, side) }
        }
        return best
    }

    private func trayCell(_ piece: Piece, size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.dashed, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))

            if !game.isPlaced(piece) {
                PieceTile(piece: piece, wrong: wrongId == piece.id)
                    .opacity(dragging == piece ? 0.25 : 1)
                    .modifier(Shake(animatableData: shakes[piece.id] ?? 0))
                    .contentShape(Rectangle())
                    .gesture(dragGesture(for: piece))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Derecha: tiempo + tablero

    private func rightPanel(boardSize: CGSize, timerHeight: CGFloat) -> some View {
        VStack(spacing: 16) {
            TimerCard()
                .frame(height: timerHeight)

            VStack(spacing: 10) {
                Text("Arma el producto  ·  \(game.placed.count)/9")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Theme.green)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: game.placed.count)

                board(size: boardSize)
            }
            .frame(maxWidth: .infinity)
            .card(padding: 12)

            Spacer(minLength: 0)
        }
    }

    private func board(size: CGSize) -> some View {
        let slot = CGSize(width: size.width / 3, height: size.height / 3)
        return VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { c in
                        slotView(position: r * 3 + c, size: slot)
                    }
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Theme.bg.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.line, lineWidth: 3)
        )
    }

    private func slotView(position: Int, size: CGSize) -> some View {
        let placedPiece = game.placed[position]
        let isHovered = dragging != nil && placedPiece == nil && hoveredPosition == position

        return ZStack {
            if let placedPiece {
                Image(placedPiece.imageName)
                    .resizable()
                    .transition(.scale(scale: 1.15).combined(with: .opacity))
            } else {
                Rectangle()
                    .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                Text("\(position)")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.line)
            }

            if isHovered {
                Rectangle().fill(Theme.green.opacity(0.15))
                Rectangle().strokeBorder(Theme.green, lineWidth: 3)
            }

            if flashPosition == position {
                Rectangle().fill(Theme.green.opacity(0.35))
            }
        }
        .frame(width: size.width, height: size.height)
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

    // MARK: - Drag

    private var hoveredPosition: Int? {
        slotFrames.first { $0.value.contains(dragLocation) }?.key
    }

    private var floatingSize: CGSize {
        slotFrames[1]?.size ?? CGSize(width: 150, height: 150)
    }

    @ViewBuilder
    private var floatingPiece: some View {
        if let dragging {
            PieceTile(piece: dragging, lifted: true)
                .frame(width: floatingSize.width, height: floatingSize.height)
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

                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    switch game.drop(piece, on: target) {
                    case .correct:
                        if let target { flash(target) }
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
            try? await Task.sleep(for: .milliseconds(280))
            withAnimation(.easeOut(duration: 0.2)) {
                if flashPosition == position { flashPosition = nil }
            }
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

private struct TimerCard: View {
    @Environment(GameModel.self) private var game

    var body: some View {
        TimelineView(.animation) { _ in
            let ms = game.elapsedMs
            let remaining = Double(GameConfig.maxGameMs - ms) / Double(GameConfig.maxGameMs)
            let urgent = ms >= GameConfig.maxGameMs - 10_000

            VStack(spacing: 4) {
                Text("TIEMPO")
                    .font(.system(size: 20, weight: .black))
                    .tracking(1)
                    .foregroundStyle(Theme.green)
                Text(formatTime(ms: ms))
                    .font(.system(size: 48, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(urgent ? Theme.wrong : Theme.greenDark)

                GeometryReader { geo in
                    Capsule().fill(Theme.green.opacity(0.15))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(urgent ? Theme.wrong : Theme.green)
                                .frame(width: geo.size.width * max(0, remaining))
                        }
                }
                .frame(height: 6)
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.yellow, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Theme.green, lineWidth: 4)
            )
            .shadow(color: .black.opacity(0.08), radius: 15, y: 10)
        }
    }
}

struct PieceTile: View {
    let piece: Piece
    var wrong = false
    var lifted = false

    var body: some View {
        Image(piece.imageName)
            .resizable()
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(wrong ? Theme.wrong : Theme.pieceBorder, lineWidth: 3)
            )
            .shadow(color: .black.opacity(lifted ? 0.3 : 0), radius: lifted ? 14 : 0, y: lifted ? 8 : 0)
            .scaleEffect(lifted ? 1.05 : 1)
    }
}

private struct SlotFrameKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}
