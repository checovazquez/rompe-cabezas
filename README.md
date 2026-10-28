# Rompe-MASECAS

Juego de rompecabezas MASECA: memoriza el empaque 10 segundos y ármalo en menos de 1 minuto, con 11 piezas trampa.

- **Web (esta carpeta):** HTML/CSS/JS sin dependencias. Se publica con GitHub Pages y se puede instalar en el iPad desde Safari › Compartir › **Agregar a inicio** (pantalla completa y sin internet).
- **iPad nativo:** [`ios/`](ios/README.md) (SwiftUI, incluye widget de inicio).

Las dos versiones se ven y juegan igual; cada una guarda su propio ranking.

## Web
- Diseño fijo de iPad (1194×834) escalado a cualquier pantalla.
- Modos de jugador (nombre, teléfono o ambos), Top 10 por evento, historial y export a CSV.
- Música y efectos (se activan con el primer toque, regla de los navegadores).
- **Admin:** mantén presionado el logo 3 s.
- **Sin registro:** modo en el admin, o link directo con `?modo=libre` (no pide datos ni muestra ranking; las partidas se guardan anónimas para el CSV).
- Los datos viven en el navegador (localStorage) de cada dispositivo.

Probar en local: `python3 -m http.server` y abrir http://localhost:8000.

Si cambias archivos, sube `VERSION` en `sw.js` para que los dispositivos instalados bajen lo nuevo.

Fuente Bricolage Grotesque bajo SIL Open Font License (`assets/fonts/OFL.txt`).
