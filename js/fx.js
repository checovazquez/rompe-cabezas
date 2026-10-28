// Confeti en un canvas del tamaño del escenario (1194×834).

const COLORS = ['#FFD60A', '#FFF8E6', '#FF8A3D', '#7ED957', '#4CC9F0'];
const INK = '#0A3D1E';
const W = 1194;
const H = 834;
const rand = (a, b) => a + Math.random() * (b - a);

export class Confetti {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.particles = [];
    this.running = false;
    this.resize(1);
  }

  /** scale = escala del escenario en pantalla, para que se vea nítido. */
  resize(scale) {
    const dpr = (window.devicePixelRatio || 1) * scale;
    this.canvas.width = Math.round(W * dpr);
    this.canvas.height = Math.round(H * dpr);
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  /** Lluvia desde arriba en toda la pantalla. */
  rain(count = 140) {
    const t0 = performance.now();
    for (let i = 0; i < count; i++) {
      this.particles.push(this.make({
        t0, mode: 'rain',
        x0: Math.random() * W, y0: -30,
        vx: rand(-40, 40), vy: rand(110, 260),
        delay: rand(0, 1.4),
        swayA: rand(10, 30), swayF: rand(2, 4), phase: rand(0, Math.PI * 2),
      }));
    }
    this.start();
  }

  /** Explosión desde un punto (coordenadas del escenario). */
  burst(x, y, count = 22) {
    const t0 = performance.now();
    for (let i = 0; i < count; i++) {
      const angle = rand(-Math.PI * 0.95, -Math.PI * 0.05);
      const speed = rand(220, 520);
      this.particles.push(this.make({
        t0, mode: 'burst', x0: x, y0: y,
        vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed, delay: 0,
      }));
    }
    this.start();
  }

  make(p) {
    return {
      w: rand(9, 14), h: rand(14, 22),
      rot0: rand(0, Math.PI * 2), spin: rand(-7, 7),
      circle: Math.random() < 0.25,
      color: COLORS[Math.floor(Math.random() * COLORS.length)],
      swayA: 0, swayF: 0, phase: 0,
      ...p,
    };
  }

  clear() {
    this.particles = [];
  }

  start() {
    if (this.running) return;
    this.running = true;
    const frame = (now) => {
      const ctx = this.ctx;
      ctx.clearRect(0, 0, W, H);
      this.particles = this.particles.filter((p) => {
        const t = (now - p.t0) / 1000 - p.delay;
        if (t < 0) return true;
        let x;
        let y;
        let alpha = 1;
        if (p.mode === 'rain') {
          x = p.x0 + p.vx * t + p.swayA * Math.sin(t * p.swayF + p.phase);
          y = p.y0 + p.vy * t + 40 * t * t;
        } else {
          x = p.x0 + p.vx * t;
          y = p.y0 + p.vy * t + 700 * t * t;
          alpha = Math.max(0, 1 - t / 1.1);
        }
        if (y > H + 40 || alpha <= 0) return false;

        ctx.save();
        ctx.globalAlpha = alpha;
        ctx.translate(x, y);
        ctx.rotate(p.rot0 + p.spin * t);
        ctx.beginPath();
        if (p.circle) {
          ctx.arc(0, 0, p.w / 2, 0, Math.PI * 2);
        } else if (ctx.roundRect) {
          ctx.roundRect(-p.w / 2, -p.h / 2, p.w, p.h, 2);
        } else {
          ctx.rect(-p.w / 2, -p.h / 2, p.w, p.h);
        }
        ctx.fillStyle = p.color;
        ctx.fill();
        ctx.lineWidth = 2;
        ctx.strokeStyle = INK;
        ctx.stroke();
        ctx.restore();
        return true;
      });
      if (this.particles.length) {
        requestAnimationFrame(frame);
      } else {
        ctx.clearRect(0, 0, W, H);
        this.running = false;
      }
    };
    requestAnimationFrame(frame);
  }
}
