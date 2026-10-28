# Rompe-MASECAS · iPad

Versión nativa en SwiftUI del juego web. iPad, horizontal, iPadOS 17+.

## Abrir y correr
1. Abre `RompeMasecas.xcodeproj` (Xcode 16+).
2. Target **RompeMasecas** › **Signing & Capabilities** › tu **Team**.
3. Run (⌘R) en el iPad o el simulador.

## Juego
Registro → 10 s para memorizar → 60 s para armar el 3×3 (9 correctas + 11 trampa) → Top 20.

## Panel admin (mantén presionado el logo 3 s)
- **Jugadores:** identificar por Nombre/apodo, Teléfono o Ambos.
- **Leaderboard:** renombrar evento o crear "Nuevo leaderboard" (pone el Top 20 en ceros, el historial se conserva).
- **Sonido:** música y efectos on/off con volumen independiente.
- **Datos:** exportar CSV del evento actual o de todo; resumen por evento.
- **Borrar todos los datos.**

## Datos para análisis
Cada partida guarda: evento, modo, nombre, teléfono, producto, completado, tiempo, piezas colocadas,
errores, precisión y el tiempo (ms) en que se colocó cada pieza.
- `Documents/partidas.json` (fuente)
- `Documents/partidas.csv` (siempre actualizado) → app **Archivos › En mi iPad › Rompe-MASECAS**,
  o en Finder con el iPad conectado por cable.

## Sonido
Música y efectos originales estilo marimba en `RompeMasecas/Sounds` (WAV). Música de menú y de juego
(se acelera los últimos 10 s), conteo, piezas (la correcta sube de nota con cada pieza), error,
victoria, récord (#1 del evento) y tiempo agotado. Suena aunque el iPad esté en silencio.

## Widget de inicio
Tamaños grande y extra grande: récord del día, Top 3 / Top 5 del evento actual y acceso directo al juego.
Se actualiza solo después de cada partida (la app comparte el ranking por el App Group
`group.com.checovazquez.rompemasecas`).
- Para correr la app usa el scheme **RompeMasecas**. El scheme del widget pide tamaño chico por default y
  falla; si lo usas, cambia `_XCWidgetFamily` a `systemLarge` en **Edit Scheme › Run › Arguments**.

## Configuración
`RompeMasecas/Core/Models.swift` › `GameConfig`.
