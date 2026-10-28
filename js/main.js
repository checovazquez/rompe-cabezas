import { CONFIG, MODES, RankingStore, formatTime, displayName, accuracy, scoreText } from './store.js';
import { sound } from './sound.js';
import { Confetti } from './fx.js';

const $ = (sel) => document.querySelector(sel);
const STAGE_W = 1194;
const STAGE_H = 834;

const store = new RankingStore();
const stage = $('#stage');
const confetti = new Confetti($('#fx'));
let scale = 1;

// ---------------------------------------------------------------- Escenario

function fitStage() {
  const vw = window.innerWidth;
  const vh = window.innerHeight;
  scale = Math.min(vw / STAGE_W, vh / STAGE_H);
  const x = (vw - STAGE_W * scale) / 2;
  const y = (vh - STAGE_H * scale) / 2;
  stage.style.transform = `translate(${x}px, ${y}px) scale(${scale})`;
  confetti.resize(scale);
}
window.addEventListener('resize', fitStage);
fitStage();

/** Coordenadas de pantalla → coordenadas del escenario. */
function toStage(clientX, clientY) {
  const r = stage.getBoundingClientRect();
  return { x: (clientX - r.left) / scale, y: (clientY - r.top) / scale };
}

// Primer toque: desbloquear audio y pantalla siempre encendida.
let wakeLock = null;
async function keepAwake() {
  try {
    if ('wakeLock' in navigator && document.visibilityState === 'visible') {
      wakeLock = await navigator.wakeLock.request('screen');
    }
  } catch { /* no soportado */ }
}
document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible' && wakeLock) keepAwake(); });
window.addEventListener('pointerdown', () => { sound.unlock(); if (!wakeLock) keepAwake(); }, { capture: true });
document.addEventListener('contextmenu', (e) => e.preventDefault());
document.addEventListener('gesturestart', (e) => e.preventDefault());

// ---------------------------------------------------------------- Pantallas

const screens = {
  register: $('#screen-register'),
  preview: $('#screen-preview'),
  game: $('#screen-game'),
  result: $('#screen-result'),
};
let screen = null;

function show(name) {
  screen = name;
  for (const [key, el] of Object.entries(screens)) el.classList.toggle('active', key === name);
  if (name === 'register') sound.playMusic('menu');
  if (name === 'preview') sound.playMusic(null);
  if (name === 'game') sound.playMusic('game');
}

// ---------------------------------------------------------------- Estado del juego

const game = {
  name: null,
  phone: null,
  product: null,
  tray: [],
  placed: {}, // posición -> pieza
  wrongDrops: 0,
  pieceTimesMs: [],
  startAt: 0,
  finalMs: null,
  record: null,
  timers: [],
  raf: 0,
  lastUrgentSecond: 0,
};

const pieceId = (p) => `p${p.productId}_${p.position}`;
const pieceSrc = (p) => `assets/pieces/${pieceId(p)}.png`;
const productSrc = (id) => `assets/products/producto${id}.jpg`;
const shuffle = (arr) => {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
};
const ALL_PIECES = CONFIG.productIds.flatMap((productId) =>
  [1, 2, 3, 4, 5, 6, 7, 8, 9].map((position) => ({ productId, position })));

function clearTimers() {
  game.timers.forEach((t) => clearTimeout(t));
  game.timers = [];
  cancelAnimationFrame(game.raf);
}
const later = (ms, fn) => game.timers.push(setTimeout(fn, ms));

function elapsedMs() {
  if (game.finalMs != null) return game.finalMs;
  if (!game.startAt) return 0;
  return Math.min(CONFIG.maxGameMs, Math.round(performance.now() - game.startAt));
}

// ---------------------------------------------------------------- Inicio

const nameInput = $('#name-input');
const phoneDisplay = $('#phone-display');
const startBtn = $('#start-btn');
let digits = '';

function renderLeaders() {
  const list = $('#leaders-list');
  list.replaceChildren();
  const top = store.top.slice(0, 3);
  if (!top.length) {
    const p = document.createElement('div');
    p.className = 'leaders-empty';
    p.textContent = '¡Sé el primero del ranking!';
    list.append(p);
    return;
  }
  top.forEach((r, i) => {
    const row = document.createElement('div');
    row.className = 'leader-row';
    row.append(medal(i + 1), span('name', displayName(r)), span('time', scoreText(r)));
    list.append(row);
  });
}

function span(cls, text) {
  const s = document.createElement('span');
  s.className = cls;
  s.textContent = text;
  return s;
}

function medal(pos) {
  const m = span(`medal medal-${pos}`, String(pos));
  return m;
}

function buildKeypad() {
  const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'borrar', '0', 'limpiar'];
  const pad = $('#keypad');
  for (const key of keys) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'btn-sticker key' + (key === 'limpiar' ? ' key-small' : '');
    if (key === 'borrar') {
      b.setAttribute('aria-label', 'Borrar');
      b.innerHTML = '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M21 5H8.5L2 12l6.5 7H21a1 1 0 0 0 1-1V6a1 1 0 0 0-1-1zm-4.3 10.3-1.4 1.4L13 14.4l-2.3 2.3-1.4-1.4 2.3-2.3-2.3-2.3 1.4-1.4 2.3 2.3 2.3-2.3 1.4 1.4-2.3 2.3 2.3 2.3z"/></svg>';
    } else {
      b.textContent = key === 'limpiar' ? 'Limpiar' : key;
    }
    b.addEventListener('click', () => {
      sound.play('tap');
      nameInput.blur();
      if (key === 'borrar') digits = digits.slice(0, -1);
      else if (key === 'limpiar') digits = '';
      else if (digits.length < 10) digits += key;
      renderRegister();
    });
    pad.append(b);
  }
}

function modeInfo() { return MODES[store.mode]; }
function trimmedName() { return nameInput.value.trim(); }
function nameValid() { return !modeInfo().asksName || trimmedName().length >= 2; }
function phoneValid() { return !modeInfo().asksPhone || digits.length === 10; }

function renderRegister() {
  const mode = modeInfo();
  const form = $('#register-form');
  form.classList.toggle('mode-both', store.mode === 'both');
  $('#name-block').hidden = !mode.asksName;
  $('#phone-block').hidden = !mode.asksPhone;
  $('#name-label').textContent = store.mode === 'nickname' ? '¿Cómo te llamamos?' : 'Tu nombre o apodo';
  $('#phone-label').textContent = store.mode === 'phone' ? 'Tu número celular' : 'Tu celular';
  nameInput.enterKeyHint = mode.asksPhone ? 'done' : 'go';

  if (!digits) {
    phoneDisplay.textContent = '10 dígitos';
  } else {
    const p = digits.padEnd(10, '_');
    phoneDisplay.textContent = `${p.slice(0, 2)} ${p.slice(2, 6)} ${p.slice(6)}`;
  }
  phoneDisplay.classList.toggle('empty', !digits);
  phoneDisplay.classList.toggle('valid', digits.length === 10);
  nameInput.classList.toggle('valid', trimmedName().length >= 2);

  startBtn.classList.toggle('compact', store.mode === 'both');
  const ready = nameValid() && phoneValid();
  startBtn.classList.toggle('ready', ready);
  startBtn.style.opacity = ready ? '1' : '.55';
}

function shakeEl(el) {
  el.classList.remove('shake');
  void el.offsetWidth;
  el.classList.add('shake');
}

nameInput.addEventListener('input', () => {
  if (nameInput.value.length > CONFIG.nameMaxLength) nameInput.value = nameInput.value.slice(0, CONFIG.nameMaxLength);
  renderRegister();
});

$('#register-form').addEventListener('submit', (e) => {
  e.preventDefault();
  if (!(nameValid() && phoneValid())) {
    sound.play('wrong');
    if (!nameValid()) shakeEl(nameInput);
    if (!phoneValid()) shakeEl(phoneDisplay);
    return;
  }
  nameInput.blur();
  const mode = modeInfo();
  startPreview(mode.asksName ? trimmedName() : null, mode.asksPhone ? digits : null);
});

$('#screen-register').addEventListener('pointerdown', (e) => {
  if (e.target !== nameInput) nameInput.blur();
});

// ---------------------------------------------------------------- Memoriza

function startPreview(name, phone) {
  clearTimers();
  game.name = name;
  game.phone = phone;
  game.product = CONFIG.productIds[Math.floor(Math.random() * CONFIG.productIds.length)];
  $('#preview-image').src = productSrc(game.product);
  setCountdown(CONFIG.previewSeconds);
  show('preview');
  sound.play('start');

  let remaining = CONFIG.previewSeconds;
  const step = () => {
    remaining -= 1;
    if (remaining <= 0) { startGame(); return; }
    setCountdown(remaining);
    sound.play(remaining <= 3 ? 'beep' : 'tick');
    later(1000, step);
  };
  later(1000, step);
}

function setCountdown(n) {
  const box = $('#countdown');
  const num = $('#countdown-num');
  num.textContent = n;
  num.classList.remove('bump');
  box.classList.remove('tick');
  void num.offsetWidth;
  num.classList.add('bump');
  box.classList.toggle('urgent', n <= 3);
  if (n <= 3) box.classList.add('tick');
}

// ---------------------------------------------------------------- Juego

const tray = $('#tray');
const board = $('#board');
const slots = [];

function buildBoard() {
  for (let pos = 1; pos <= 9; pos++) {
    const slot = document.createElement('div');
    slot.className = 'slot';
    slot.dataset.position = pos;
    slots.push(slot);
    board.append(slot);
  }
}

function startGame() {
  clearTimers();
  const correct = ALL_PIECES.filter((p) => p.productId === game.product);
  const distractors = shuffle(ALL_PIECES.filter((p) => p.productId !== game.product)).slice(0, CONFIG.distractorCount);
  game.tray = shuffle([...correct, ...distractors]);
  game.placed = {};
  game.wrongDrops = 0;
  game.pieceTimesMs = [];
  game.finalMs = null;
  game.record = null;
  game.lastUrgentSecond = 0;

  $('#game-subtitle').textContent = game.name ? `${game.name} · arma el empaque` : 'Arma el empaque';
  board.classList.remove('done');
  for (const slot of slots) {
    slot.replaceChildren(document.createTextNode(slot.dataset.position));
    slot.classList.remove('hover', 'flash');
  }
  tray.replaceChildren();
  for (const p of game.tray) {
    const cell = document.createElement('div');
    cell.className = 'tray-cell';
    const img = document.createElement('img');
    img.className = 'piece';
    img.src = pieceSrc(p);
    img.alt = 'Pieza';
    img.draggable = false;
    img.addEventListener('pointerdown', (e) => beginDrag(e, p, img));
    cell.append(img);
    tray.append(cell);
  }
  renderProgress();
  $('#timer-pill').classList.remove('urgent', 'beat');

  show('game');
  sound.play('go');
  const splash = $('#go-splash');
  splash.classList.remove('show');
  void splash.offsetWidth;
  splash.classList.add('show');

  game.startAt = performance.now();
  const tick = () => {
    const ms = elapsedMs();
    renderTimer(ms);
    if (ms >= CONFIG.maxGameMs) { finish(false); return; }
    const secondsLeft = Math.ceil((CONFIG.maxGameMs - ms) / 1000);
    if (secondsLeft <= 10 && secondsLeft !== game.lastUrgentSecond) {
      game.lastUrgentSecond = secondsLeft;
      sound.play('tick_urgent');
      sound.setMusicRate(1.12);
    }
    game.raf = requestAnimationFrame(tick);
  };
  game.raf = requestAnimationFrame(tick);
}

function renderTimer(ms) {
  const left = CONFIG.maxGameMs - ms;
  $('#timer-text').textContent = formatTime(ms);
  $('#timer-fill').style.width = `${Math.max(0, left / CONFIG.maxGameMs) * 100}%`;
  const pill = $('#timer-pill');
  const urgent = left <= 10_000;
  pill.classList.toggle('urgent', urgent);
  pill.classList.toggle('beat', urgent && Math.floor(left / 500) % 2 === 0);
}

function renderProgress() {
  const count = Object.keys(game.placed).length;
  const box = $('#progress');
  box.replaceChildren();
  for (let i = 1; i <= 9; i++) {
    const d = document.createElement('span');
    d.className = 'dot' + (i <= count ? ' on' : '') + (i === count ? ' last' : '');
    box.append(d);
  }
  const c = document.createElement('span');
  c.className = 'progress-count';
  c.textContent = `${count}/9`;
  box.append(c);
  box.setAttribute('aria-label', `${count} de 9 piezas`);
}

// ---------- Arrastre (táctil y mouse)

let drag = null;

function beginDrag(e, piece, img) {
  if (screen !== 'game' || game.finalMs != null || drag) return;
  e.preventDefault();
  img.setPointerCapture?.(e.pointerId);
  const size = slots[0].getBoundingClientRect().width / scale;
  const ghost = document.createElement('img');
  ghost.className = 'float-piece';
  ghost.src = img.src;
  ghost.alt = '';
  ghost.style.width = ghost.style.height = `${size}px`;
  $('#float-layer').append(ghost);
  img.classList.add('dragging');
  drag = { piece, img, ghost, size, pointerId: e.pointerId };
  sound.play('pickup');
  moveDrag(e);

  img.addEventListener('pointermove', moveDrag);
  img.addEventListener('pointerup', endDrag);
  img.addEventListener('pointercancel', endDrag);
}

function slotAt(clientX, clientY) {
  return slots.find((s) => {
    const r = s.getBoundingClientRect();
    return clientX >= r.left && clientX <= r.right && clientY >= r.top && clientY <= r.bottom;
  });
}

function moveDrag(e) {
  if (!drag || e.pointerId !== drag.pointerId) return;
  const { x, y } = toStage(e.clientX, e.clientY);
  drag.ghost.style.left = `${x - drag.size / 2}px`;
  drag.ghost.style.top = `${y - drag.size / 2}px`;
  const over = slotAt(e.clientX, e.clientY);
  for (const s of slots) {
    const pos = Number(s.dataset.position);
    s.classList.toggle('hover', s === over && !game.placed[pos]);
  }
}

function endDrag(e) {
  if (!drag || e.pointerId !== drag.pointerId) return;
  const { piece, img, ghost } = drag;
  img.removeEventListener('pointermove', moveDrag);
  img.removeEventListener('pointerup', endDrag);
  img.removeEventListener('pointercancel', endDrag);
  ghost.remove();
  img.classList.remove('dragging');
  slots.forEach((s) => s.classList.remove('hover'));
  drag = null;

  const target = e.type === 'pointerup' ? slotAt(e.clientX, e.clientY) : null;
  const position = target ? Number(target.dataset.position) : null;
  const result = drop(piece, position);
  if (result === 'correct') {
    target.replaceChildren();
    const placed = document.createElement('img');
    placed.src = pieceSrc(piece);
    placed.alt = 'Pieza colocada';
    target.append(placed);
    target.classList.remove('flash');
    void target.offsetWidth;
    target.classList.add('flash');
    const r = target.getBoundingClientRect();
    const c = toStage(r.left + r.width / 2, r.top + r.height / 2);
    confetti.burst(c.x, c.y);
    img.classList.add('gone');
    renderProgress();
  } else if (result === 'wrong') {
    img.classList.add('wrong');
    shakeEl(img);
    later(500, () => img.classList.remove('wrong'));
  }
}

function drop(piece, position) {
  if (screen !== 'game' || game.finalMs != null || !position || game.placed[position]) return 'ignored';
  if (piece.productId !== game.product || piece.position !== position) {
    game.wrongDrops += 1;
    sound.play('wrong');
    return 'wrong';
  }
  game.placed[position] = piece;
  game.pieceTimesMs.push(elapsedMs());
  const count = Object.keys(game.placed).length;
  sound.playCorrect(count);
  if (count === 9) finish(true);
  return 'correct';
}

function finish(completed) {
  if (screen !== 'game' || game.finalMs != null) return;
  cancelAnimationFrame(game.raf);
  const ms = completed ? elapsedMs() : CONFIG.maxGameMs;
  game.finalMs = ms;
  renderTimer(ms);

  game.record = store.add({
    mode: store.mode,
    name: game.name,
    phone: game.phone,
    productId: game.product,
    completed,
    timeMs: ms,
    piecesPlaced: Object.keys(game.placed).length,
    wrongDrops: game.wrongDrops,
    pieceTimesMs: [...game.pieceTimesMs],
    playedAt: new Date().toISOString(),
  });

  const isRecord = completed && store.positionOf(game.record) === 1;
  sound.playMusic(null, 0.3);
  if (completed) {
    board.classList.add('done');
  } else {
    sound.play('timeout');
  }
  later(completed ? 600 : 0, () => {
    if (completed) sound.play(isRecord ? 'record' : 'win');
    showResult(isRecord);
  });
}

// ---------------------------------------------------------------- Resultado

function showResult(isRecord) {
  const r = game.record;
  const completed = r.completed;
  const title = $('#result-title');
  title.innerHTML = '';
  title.append(completed ? '¡LO' : '¡SE ACABÓ', document.createElement('br'), completed ? 'LOGRASTE!' : 'EL TIEMPO!');
  title.classList.toggle('timeout', !completed);
  $('#record-badge').classList.toggle('on', isRecord);

  $('#result-product').src = productSrc(r.productId);
  const name = r.name || null;
  $('#result-caption').textContent = completed
    ? (name ? `${name}, tu tiempo` : 'Tu tiempo')
    : (name ? `${name}, colocaste` : 'Colocaste');
  const errors = r.wrongDrops === 1 ? '1 error' : `${r.wrongDrops} errores`;
  $('#result-stats').textContent = `${errors} · ${Math.round(accuracy(r) * 100)}% precisión`;

  const main = $('#result-main');
  if (completed) {
    const t0 = performance.now();
    const count = (now) => {
      const t = Math.min(1, Math.max(0, (now - t0) / 1000 - 0.2) / 0.9);
      const eased = 1 - (1 - t) ** 3;
      main.textContent = formatTime(r.timeMs * eased);
      if (t < 1 && screen === 'result') requestAnimationFrame(count);
    };
    main.textContent = formatTime(0);
    requestAnimationFrame(count);
  } else {
    main.textContent = `${r.piecesPlaced} de 9`;
  }

  const pos = store.positionOf(r);
  $('#result-place').textContent = pos ? `Lugar #${pos} de ${store.leaderboard.length}` : '';

  $('#lb-event').textContent = store.currentEvent.name;
  const list = $('#lb-list');
  list.replaceChildren();
  const top = store.top;
  if (!top.length) {
    const li = document.createElement('li');
    li.className = 'lb-empty';
    li.textContent = 'Todavía no hay tiempos registrados.';
    list.append(li);
  }
  top.forEach((e, i) => {
    const li = document.createElement('li');
    li.className = 'lb-row' + (e.id === r.id ? ' me' : '');
    li.style.setProperty('--i', i + 1);
    const time = span('time' + (e.completed ? '' : ' partial'), scoreText(e));
    li.append(medal(i + 1), span('name', displayName(e)), time);
    list.append(li);
  });

  show('result');
  if (completed) confetti.rain(isRecord ? 230 : 140);

  // Modo kiosco: regresar solo al inicio.
  const until = Date.now() + CONFIG.resultAutoResetSeconds * 1000;
  const countdown = () => {
    if (screen !== 'result') return;
    const left = Math.max(0, Math.ceil((until - Date.now()) / 1000));
    $('#reset-countdown').textContent = `Regresa al inicio en ${left} s`;
    if (left <= 0) { reset(); return; }
    later(250, countdown);
  };
  countdown();
}

function reset() {
  clearTimers();
  confetti.clear();
  game.name = null;
  game.phone = null;
  game.product = null;
  game.finalMs = null;
  game.startAt = 0;
  nameInput.value = '';
  digits = '';
  renderRegister();
  renderLeaders();
  show('register');
}

$('#restart-btn').addEventListener('click', reset);

// ---------------------------------------------------------------- Admin

const admin = $('#admin');
let pressTimer = null;
const logo = $('#logo-admin');
logo.addEventListener('pointerdown', () => {
  clearTimeout(pressTimer);
  pressTimer = setTimeout(openAdmin, 3000);
});
['pointerup', 'pointerleave', 'pointercancel'].forEach((ev) =>
  logo.addEventListener(ev, () => clearTimeout(pressTimer)));

function openAdmin() {
  nameInput.blur();
  renderAdmin();
  if (typeof admin.showModal === 'function') admin.showModal();
  else admin.setAttribute('open', '');
}

admin.addEventListener('close', () => {
  renderRegister();
  renderLeaders();
});

function renderAdmin() {
  const picker = $('#mode-picker');
  picker.replaceChildren();
  for (const [key, m] of Object.entries(MODES)) {
    const b = document.createElement('button');
    b.type = 'button';
    b.setAttribute('role', 'radio');
    b.setAttribute('aria-checked', String(store.mode === key));
    b.textContent = m.label;
    b.addEventListener('click', () => { store.mode = key; renderAdmin(); });
    picker.append(b);
  }
  $('#mode-foot').textContent = MODES[store.mode].foot;

  $('#music-on').checked = sound.musicOn;
  $('#music-vol').value = sound.musicVolume;
  $('#sfx-on').checked = sound.sfxOn;
  $('#sfx-vol').value = sound.sfxVolume;

  const lb = store.leaderboard;
  $('#adm-event').textContent = store.currentEvent.name;
  $('#adm-games').textContent = lb.length;
  const best = lb[0];
  $('#adm-best').textContent = best && best.completed ? `${formatTime(best.timeMs)} · ${displayName(best)}` : '—';
  $('#rename-input').value = store.currentEvent.name;
  $('#new-event-input').value = '';

  $('#adm-total').textContent = store.records.length;
  const hist = $('#adm-history');
  hist.replaceChildren();
  const fmt = new Intl.DateTimeFormat('es-MX', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
  for (const ev of [...store.events].reverse()) {
    const recs = store.recordsFor(ev);
    const done = recs.filter((r) => r.completed);
    const bestMs = done.length ? Math.min(...done.map((r) => r.timeMs)) : null;
    const avgMs = done.length ? Math.round(done.reduce((s, r) => s + r.timeMs, 0) / done.length) : null;
    const pct = recs.length ? `${Math.round((done.length / recs.length) * 100)}%` : '—';

    const row = document.createElement('div');
    row.className = 'history-row';
    const top = document.createElement('div');
    top.className = 'h-top';
    const name = span('h-name', ev.name);
    if (ev.id === store.currentEvent.id) name.append(span('h-tag', 'ACTUAL'));
    top.append(name, span('h-date', fmt.format(new Date(ev.startedAt))));
    const stats = span('h-stats',
      `${recs.length} partidas · ${pct} completadas · mejor ${bestMs != null ? formatTime(bestMs) : '—'} · promedio ${avgMs != null ? formatTime(avgMs) : '—'}`);
    row.append(top, stats);
    hist.append(row);
  }

  const del = $('#delete-all');
  del.classList.remove('confirm');
  del.textContent = 'Borrar todos los datos';
}

$('#music-on').addEventListener('change', (e) => sound.setMusicOn(e.target.checked));
$('#music-vol').addEventListener('input', (e) => sound.setMusicVolume(Number(e.target.value)));
$('#sfx-on').addEventListener('change', (e) => sound.setSfxOn(e.target.checked));
$('#sfx-vol').addEventListener('input', (e) => sound.setSfxVolume(Number(e.target.value)));
$('#sfx-vol').addEventListener('change', () => sound.playCorrect(5));

$('#rename-btn').addEventListener('click', () => {
  store.renameCurrentEvent($('#rename-input').value);
  renderAdmin();
});
$('#new-event-btn').addEventListener('click', () => {
  store.startNewEvent($('#new-event-input').value);
  renderAdmin();
});
$('#export-current').addEventListener('click', () => store.download(store.currentEvent));
$('#export-all').addEventListener('click', () => store.download(null));
$('#delete-all').addEventListener('click', (e) => {
  const btn = e.currentTarget;
  if (!btn.classList.contains('confirm')) {
    btn.classList.add('confirm');
    btn.textContent = '¿Seguro? Toca otra vez para borrar todo';
    return;
  }
  store.deleteAll();
  renderAdmin();
});

// ---------------------------------------------------------------- Arranque

buildKeypad();
buildBoard();
renderRegister();
renderLeaders();
show('register');

if ('serviceWorker' in navigator && location.protocol === 'https:') {
  navigator.serviceWorker.register('sw.js').catch(() => {});
}

// Para pruebas desde la consola.
window.rompeMasecas = { store, sound, game };
