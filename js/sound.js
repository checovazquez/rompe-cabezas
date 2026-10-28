// Música y efectos con Web Audio. Mismos sonidos que la app de iPad.
// Safari/Chrome no dejan sonar nada hasta el primer toque: se desbloquea solo.

const SFX = ['tap', 'pickup', 'start', 'tick', 'beep', 'go', 'wrong', 'win', 'record', 'timeout', 'tick_urgent',
  'correct_1', 'correct_2', 'correct_3', 'correct_4', 'correct_5', 'correct_6', 'correct_7', 'correct_8', 'correct_9'];
const MUSIC = { menu: 'music_menu', game: 'music_game' };
const KEY = 'rompeMasecas.sound';

class SoundManager {
  constructor() {
    const saved = (() => { try { return JSON.parse(localStorage.getItem(KEY)) || {}; } catch { return {}; } })();
    this.sfxOn = saved.sfxOn ?? true;
    this.musicOn = saved.musicOn ?? true;
    this.sfxVolume = saved.sfxVolume ?? 0.9;
    this.musicVolume = saved.musicVolume ?? 0.5;

    this.ctx = null;
    this.buffers = {};
    this.loading = null;
    this.current = null; // { name, source, gain }
    this.wanted = null;
  }

  save() {
    try {
      localStorage.setItem(KEY, JSON.stringify({
        sfxOn: this.sfxOn, musicOn: this.musicOn, sfxVolume: this.sfxVolume, musicVolume: this.musicVolume,
      }));
    } catch { /* sin almacenamiento */ }
  }

  /** Llamar en el primer gesto del usuario. */
  unlock() {
    if (!this.ctx) {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      if (!Ctx) return;
      this.ctx = new Ctx();
      this.master = this.ctx.createGain();
      this.master.connect(this.ctx.destination);
    }
    if (this.ctx.state === 'suspended') this.ctx.resume();
    if (!this.loading) this.loading = this.loadAll();
  }

  async loadAll() {
    const names = [...SFX, ...Object.values(MUSIC)];
    await Promise.all(names.map(async (name) => {
      const ext = name.startsWith('music_') ? 'wav' : 'mp3';
      try {
        const res = await fetch(`assets/sounds/${name}.${ext}`);
        const data = await res.arrayBuffer();
        this.buffers[name] = await new Promise((ok, fail) => this.ctx.decodeAudioData(data, ok, fail));
      } catch { /* si un sonido falla, el juego sigue */ }
    }));
    // Si una pantalla pidió música mientras cargaba, arrancarla ya.
    if (this.wanted && !this.current) this.playMusic(this.wanted, 0.4);
  }

  play(name) {
    if (!this.sfxOn || !this.ctx || !this.buffers[name]) return;
    const src = this.ctx.createBufferSource();
    const gain = this.ctx.createGain();
    gain.gain.value = this.sfxVolume;
    src.buffer = this.buffers[name];
    src.connect(gain).connect(this.master);
    src.start();
  }

  /** Pieza correcta: sube de tono con cada pieza (1...9). */
  playCorrect(count) {
    this.play(`correct_${Math.min(Math.max(count, 1), 9)}`);
  }

  /** 'menu' | 'game' | null, con fade. */
  playMusic(which, fade = 0.6) {
    this.wanted = which;
    const name = which ? MUSIC[which] : null;
    if (this.current && this.current.name === name) return;
    this.stopCurrent(fade);
    if (!name || !this.musicOn || !this.ctx || !this.buffers[name]) return;

    const now = this.ctx.currentTime;
    const src = this.ctx.createBufferSource();
    const gain = this.ctx.createGain();
    src.buffer = this.buffers[name];
    src.loop = true;
    gain.gain.setValueAtTime(0, now);
    gain.gain.linearRampToValueAtTime(this.musicVolume, now + fade);
    src.connect(gain).connect(this.master);
    src.start();
    this.current = { name, source: src, gain };
  }

  stopCurrent(fade = 0.6) {
    if (!this.current || !this.ctx) { this.current = null; return; }
    const { source, gain } = this.current;
    const now = this.ctx.currentTime;
    gain.gain.cancelScheduledValues(now);
    gain.gain.setValueAtTime(gain.gain.value, now);
    gain.gain.linearRampToValueAtTime(0, now + fade);
    try { source.stop(now + fade + 0.05); } catch { /* ya detenido */ }
    this.current = null;
  }

  /** Acelera la música (últimos segundos del juego). */
  setMusicRate(rate) {
    if (this.current) this.current.source.playbackRate.value = rate;
  }

  setMusicOn(on) {
    this.musicOn = on;
    this.save();
    if (on) {
      const w = this.wanted;
      this.wanted = null;
      this.playMusic(w, 0.3);
    } else {
      this.stopCurrent(0.2);
    }
  }

  setMusicVolume(v) {
    this.musicVolume = v;
    this.save();
    if (this.current && this.ctx) this.current.gain.gain.setTargetAtTime(v, this.ctx.currentTime, 0.05);
  }

  setSfxOn(on) { this.sfxOn = on; this.save(); }
  setSfxVolume(v) { this.sfxVolume = v; this.save(); }
}

export const sound = new SoundManager();
