// Ranking, eventos y exportación. Mismo modelo y mismo CSV que la app de iPad.
// Todo vive en localStorage de este navegador.

export const CONFIG = {
  productIds: [1, 2, 3, 4, 5], // el 6 tiene piezas pero es casi igual al 1
  previewSeconds: 10,
  maxGameMs: 60_000,
  distractorCount: 11,
  rankingLimit: 10,
  nameMaxLength: 16,
  resultAutoResetSeconds: 45,
};

export const MODES = {
  nickname: { label: 'Nombre / apodo', asksName: true, asksPhone: false,
    foot: 'Solo se pide nombre o apodo y se muestra en el ranking.' },
  phone: { label: 'Teléfono', asksName: false, asksPhone: true,
    foot: 'Solo se pide celular; en el ranking se ve enmascarado (******1234).' },
  both: { label: 'Ambos', asksName: true, asksPhone: true,
    foot: 'Se pide apodo y celular. En el ranking se ve el apodo; el celular solo sale en el CSV.' },
  libre: { label: 'Sin registro', asksName: false, asksPhone: false, noRanking: true, maxGameMs: 30_000,
    foot: 'No pide datos, no muestra ranking y da 30 segundos para armar. Las partidas se guardan anónimas para el CSV. También se abre directo con ?modo=libre en el link.' },
};

const DATA_KEY = 'rompeMasecas.data.v2';
const MODE_KEY = 'rompeMasecas.mode';

export function formatTime(ms) {
  const cs = Math.floor(Math.max(0, ms) / 10);
  const m = String(Math.floor(cs / 6000)).padStart(2, '0');
  const s = String(Math.floor((cs % 6000) / 100)).padStart(2, '0');
  const c = String(cs % 100).padStart(2, '0');
  return `${m}:${s}.${c}`;
}

export function maskedPhone(phone) {
  if (!phone || phone.length < 4) return phone || null;
  return '******' + phone.slice(-4);
}

export function displayName(r) {
  if (r.name) return r.name;
  return maskedPhone(r.phone) || '—';
}

export function accuracy(r) {
  const attempts = r.piecesPlaced + r.wrongDrops;
  return attempts === 0 ? 0 : r.piecesPlaced / attempts;
}

export function scoreText(r) {
  return r.completed ? formatTime(r.timeMs) : `${r.piecesPlaced}/9`;
}

/** Completados primero por tiempo; los que no terminaron, por piezas colocadas. */
export function ranked(list) {
  return [...list].sort((a, b) => {
    if (a.completed !== b.completed) return a.completed ? -1 : 1;
    if (a.completed && a.timeMs !== b.timeMs) return a.timeMs - b.timeMs;
    if (!a.completed && a.piecesPlaced !== b.piecesPlaced) return b.piecesPlaced - a.piecesPlaced;
    return new Date(a.playedAt) - new Date(b.playedAt);
  });
}

const isRanked = (r) => r.mode !== 'libre';

const uuid = () => (crypto.randomUUID ? crypto.randomUUID()
  : 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (ch) => {
    const r = Math.random() * 16 | 0;
    return (ch === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
  }));

const newEvent = (name) => ({ id: uuid(), name, startedAt: new Date().toISOString() });

function safeGet(key) {
  try { return localStorage.getItem(key); } catch { return null; }
}
function safeSet(key, value) {
  try { localStorage.setItem(key, value); } catch { /* sin almacenamiento: sigue en memoria */ }
}

export class RankingStore {
  constructor() {
    this.records = [];
    this.events = [];
    const raw = safeGet(DATA_KEY);
    if (raw) {
      try {
        const data = JSON.parse(raw);
        this.records = Array.isArray(data.records) ? data.records : [];
        this.events = Array.isArray(data.events) ? data.events : [];
      } catch { /* datos corruptos: empezar limpio */ }
    }
    const mode = safeGet(MODE_KEY);
    this._mode = MODES[mode] ? mode : 'nickname';
    if (this.events.length === 0) {
      this.events = [newEvent('Evento 1')];
      this.save();
    }
  }

  get mode() { return this._mode; }
  set mode(value) {
    if (!MODES[value]) return;
    this._mode = value;
    safeSet(MODE_KEY, value);
  }

  get currentEvent() { return this.events[this.events.length - 1]; }
  recordsFor(event) { return this.records.filter((r) => r.eventId === event.id); }
  /** Las partidas "sin registro" no entran al ranking (solo al CSV). */
  get leaderboard() { return ranked(this.recordsFor(this.currentEvent).filter(isRanked)); }
  get top() { return this.leaderboard.slice(0, CONFIG.rankingLimit); }

  positionOf(record) {
    const i = this.leaderboard.findIndex((r) => r.id === record.id);
    return i < 0 ? null : i + 1;
  }

  add(record) {
    const full = { id: uuid(), eventId: this.currentEvent.id, ...record };
    this.records.push(full);
    this.save();
    return full;
  }

  startNewEvent(name) {
    const trimmed = (name || '').trim();
    this.events.push(newEvent(trimmed || `Evento ${this.events.length + 1}`));
    this.save();
  }

  renameCurrentEvent(name) {
    const trimmed = (name || '').trim();
    if (!trimmed) return;
    this.currentEvent.name = trimmed;
    this.save();
  }

  deleteAll() {
    this.records = [];
    this.events = [newEvent('Evento 1')];
    this.save();
  }

  save() {
    safeSet(DATA_KEY, JSON.stringify({ records: this.records, events: this.events }));
  }

  /** CSV listo para Excel / Power BI. event null = todas las partidas. */
  csv(event = null) {
    const names = {};
    const place = {};
    for (const ev of this.events) {
      names[ev.id] = ev.name;
      ranked(this.recordsFor(ev).filter(isRanked)).forEach((r, i) => { place[r.id] = i + 1; });
    }
    const pad = (n) => String(n).padStart(2, '0');
    const header = ['id', 'evento', 'lugar_en_evento', 'fecha', 'hora', 'fecha_iso', 'modo', 'nombre', 'telefono',
      'producto', 'completado', 'tiempo', 'tiempo_ms', 'piezas_colocadas', 'errores',
      'precision_pct', 'ms_primera_pieza', 'tiempos_piezas_ms'];
    const esc = (v) => {
      const s = String(v ?? '');
      return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
    };
    const source = event ? this.recordsFor(event) : this.records;
    const lines = [header.join(',')];
    for (const r of [...source].sort((a, b) => new Date(a.playedAt) - new Date(b.playedAt))) {
      const d = new Date(r.playedAt);
      lines.push([
        r.id, names[r.eventId] ?? '', place[r.id] ?? '',
        `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`,
        `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`,
        d.toISOString(), r.mode, r.name ?? '', r.phone ?? '',
        r.productId, r.completed ? 1 : 0, formatTime(r.timeMs), r.timeMs,
        r.piecesPlaced, r.wrongDrops, (accuracy(r) * 100).toFixed(1),
        r.pieceTimesMs[0] ?? '', r.pieceTimesMs.join('|'),
      ].map(esc).join(','));
    }
    return '﻿' + lines.join('\n'); // BOM para que Excel respete acentos
  }

  download(event = null) {
    const d = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    const stamp = `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}_${pad(d.getHours())}${pad(d.getMinutes())}`;
    const slug = event
      ? '_' + event.name.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '_').slice(0, 30)
      : '_todo';
    const blob = new Blob([this.csv(event)], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `rompe_masecas${slug}_${stamp}.csv`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 2000);
  }
}
