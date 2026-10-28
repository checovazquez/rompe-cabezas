import SwiftUI

// MARK: - Fondo verde con puntos que se desplazan lento

struct DotsBackground: View {
    var spacing: CGFloat = 22
    var period: Double = 6

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { ctx, size in
                let cycle = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                let shift = CGFloat(cycle) * spacing
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.green))

                var dots = Path()
                var y = -spacing + shift
                while y < size.height + spacing {
                    var x = -spacing + shift
                    while x < size.width + spacing {
                        dots.addEllipse(in: CGRect(x: x - 1.6, y: y - 1.6, width: 3.2, height: 3.2))
                        x += spacing
                    }
                    y += spacing
                }
                ctx.fill(dots, with: .color(Theme.yellow.opacity(0.16)))
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Confeti

struct ConfettiView: View {
    enum Mode: Equatable {
        case rain            // cae desde arriba en toda la pantalla
        case burst(CGPoint)  // explota desde un punto
    }

    let mode: Mode
    @State private var particles: [Particle]
    @State private var start = Date.now

    struct Particle {
        var x0: CGFloat, vx: CGFloat, vy: CGFloat
        var w: CGFloat, h: CGFloat
        var rot0: Double, spin: Double
        var swayA: CGFloat, swayF: Double, phase: Double
        var delay: Double
        var circle: Bool
        var color: Color
    }

    init(mode: Mode, count: Int = 140) {
        self.mode = mode
        var list: [Particle] = []
        for _ in 0..<count {
            let isBurst: Bool
            if case .burst = mode { isBurst = true } else { isBurst = false }
            let angle = Double.random(in: -Double.pi * 0.95 ... -Double.pi * 0.05)
            let speed = CGFloat.random(in: 220...520)
            list.append(Particle(
                x0: .random(in: 0...1),
                vx: isBurst ? CGFloat(cos(angle)) * speed : .random(in: -40...40),
                vy: isBurst ? CGFloat(sin(angle)) * speed : .random(in: 110...260),
                w: .random(in: 9...14), h: .random(in: 14...22),
                rot0: .random(in: 0...(2 * .pi)), spin: .random(in: -7...7),
                swayA: isBurst ? 0 : .random(in: 10...30), swayF: .random(in: 2...4), phase: .random(in: 0...(2 * .pi)),
                delay: isBurst ? 0 : .random(in: 0...1.4),
                circle: Bool.random() && Bool.random(),
                color: Theme.confetti.randomElement() ?? Theme.yellow
            ))
        }
        _particles = State(initialValue: list)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in particles {
                    let lt = t - p.delay
                    guard lt > 0 else { continue }

                    let tt = CGFloat(lt)
                    let x: CGFloat
                    let y: CGFloat
                    var alpha: Double = 1
                    switch mode {
                    case .rain:
                        let sway: CGFloat = p.swayA * CGFloat(sin(lt * p.swayF + p.phase))
                        x = p.x0 * size.width + p.vx * tt + sway
                        y = -30 + p.vy * tt + 40 * tt * tt
                    case .burst(let origin):
                        x = origin.x + p.vx * tt
                        y = origin.y + p.vy * tt + 700 * tt * tt
                        alpha = max(0, 1 - lt / 1.1)
                    }
                    if y > size.height + 40 || alpha <= 0 { continue }

                    var c = ctx
                    c.opacity = alpha
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(p.rot0 + p.spin * lt))
                    let rect = CGRect(x: -p.w / 2, y: -p.h / 2, width: p.w, height: p.circle ? p.w : p.h)
                    let path = p.circle ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 2)
                    c.fill(path, with: .color(p.color))
                    c.stroke(path, with: .color(Theme.ink), lineWidth: 2)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - "¡ARMA!" al arrancar el juego

struct GoSplash: View {
    var text = "¡ARMA!"
    @State private var phase = 0

    var body: some View {
        Text(text)
            .font(.fiesta(124))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 52)
            .padding(.vertical, 6)
            .sticker(fill: Theme.yellow, radius: 44, border: 6, shadow: 12)
            .rotationEffect(.degrees(-6))
            .scaleEffect(phase == 0 ? 0.2 : (phase == 1 ? 1 : 1.3))
            .opacity(phase == 2 ? 0 : 1)
            .allowsHitTesting(false)
            .task {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { phase = 1 }
                try? await Task.sleep(for: .milliseconds(750))
                withAnimation(.easeIn(duration: 0.25)) { phase = 2 }
            }
    }
}

// MARK: - Movimientos en loop

/// Vaivén suave (logo, stickers).
struct Wobble: ViewModifier {
    var angle: Double = 4
    var base: Double = 0
    var duration: Double = 1.6
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(base + (on ? angle : -angle)))
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

/// Latido (botones de llamada a la accion).
struct Pulse: ViewModifier {
    var active: Bool = true
    var scale: CGFloat = 1.04
    var duration: Double = 0.7
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(active && on ? scale : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

extension View {
    func wobble(_ angle: Double = 4, base: Double = 0, duration: Double = 1.6) -> some View {
        modifier(Wobble(angle: angle, base: base, duration: duration))
    }

    func pulse(_ active: Bool = true, scale: CGFloat = 1.04, duration: Double = 0.7) -> some View {
        modifier(Pulse(active: active, scale: scale, duration: duration))
    }

    /// Entrada con rebote y retraso.
    func popIn(_ shown: Bool, delay: Double = 0, from scale: CGFloat = 0.7) -> some View {
        self
            .scaleEffect(shown ? 1 : scale)
            .opacity(shown ? 1 : 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.6).delay(delay), value: shown)
    }
}
