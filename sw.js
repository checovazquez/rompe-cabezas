// Cache para que el juego funcione sin internet (modo kiosco).
// Sube la version al cambiar cualquier archivo para que los iPads bajen lo nuevo.
const VERSION = 'rm-v2.0.1';
const FILES = [
  "./",
  "index.html",
  "manifest.webmanifest",
  "css/styles.css",
  "js/main.js",
  "js/store.js",
  "js/sound.js",
  "js/fx.js",
  "assets/logo-maseca.png",
  "assets/pieces/p1_1.png",
  "assets/pieces/p1_2.png",
  "assets/pieces/p1_3.png",
  "assets/pieces/p1_4.png",
  "assets/pieces/p1_5.png",
  "assets/pieces/p1_6.png",
  "assets/pieces/p1_7.png",
  "assets/pieces/p1_8.png",
  "assets/pieces/p1_9.png",
  "assets/pieces/p2_1.png",
  "assets/pieces/p2_2.png",
  "assets/pieces/p2_3.png",
  "assets/pieces/p2_4.png",
  "assets/pieces/p2_5.png",
  "assets/pieces/p2_6.png",
  "assets/pieces/p2_7.png",
  "assets/pieces/p2_8.png",
  "assets/pieces/p2_9.png",
  "assets/pieces/p3_1.png",
  "assets/pieces/p3_2.png",
  "assets/pieces/p3_3.png",
  "assets/pieces/p3_4.png",
  "assets/pieces/p3_5.png",
  "assets/pieces/p3_6.png",
  "assets/pieces/p3_7.png",
  "assets/pieces/p3_8.png",
  "assets/pieces/p3_9.png",
  "assets/pieces/p4_1.png",
  "assets/pieces/p4_2.png",
  "assets/pieces/p4_3.png",
  "assets/pieces/p4_4.png",
  "assets/pieces/p4_5.png",
  "assets/pieces/p4_6.png",
  "assets/pieces/p4_7.png",
  "assets/pieces/p4_8.png",
  "assets/pieces/p4_9.png",
  "assets/pieces/p5_1.png",
  "assets/pieces/p5_2.png",
  "assets/pieces/p5_3.png",
  "assets/pieces/p5_4.png",
  "assets/pieces/p5_5.png",
  "assets/pieces/p5_6.png",
  "assets/pieces/p5_7.png",
  "assets/pieces/p5_8.png",
  "assets/pieces/p5_9.png",
  "assets/products/producto1.jpg",
  "assets/products/producto2.jpg",
  "assets/products/producto3.jpg",
  "assets/products/producto4.jpg",
  "assets/products/producto5.jpg",
  "assets/sounds/beep.mp3",
  "assets/sounds/correct_1.mp3",
  "assets/sounds/correct_2.mp3",
  "assets/sounds/correct_3.mp3",
  "assets/sounds/correct_4.mp3",
  "assets/sounds/correct_5.mp3",
  "assets/sounds/correct_6.mp3",
  "assets/sounds/correct_7.mp3",
  "assets/sounds/correct_8.mp3",
  "assets/sounds/correct_9.mp3",
  "assets/sounds/go.mp3",
  "assets/sounds/music_game.wav",
  "assets/sounds/music_menu.wav",
  "assets/sounds/pickup.mp3",
  "assets/sounds/record.mp3",
  "assets/sounds/start.mp3",
  "assets/sounds/tap.mp3",
  "assets/sounds/tick.mp3",
  "assets/sounds/tick_urgent.mp3",
  "assets/sounds/timeout.mp3",
  "assets/sounds/win.mp3",
  "assets/sounds/wrong.mp3",
  "assets/fonts/bricolage-500.woff2",
  "assets/fonts/bricolage-700.woff2",
  "assets/fonts/bricolage-800.woff2",
  "assets/icons/apple-touch-icon.png",
  "assets/icons/favicon.png",
  "assets/icons/icon-192.png",
  "assets/icons/icon-512.png"
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(FILES)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  e.respondWith(caches.match(e.request, { ignoreSearch: true }).then((hit) => hit || fetch(e.request)));
});
