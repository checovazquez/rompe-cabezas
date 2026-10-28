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
- **Datos:** exportar CSV del evento actual o de todo; resumen por evento.
- **Borrar todos los datos.**

## Datos para análisis
Cada partida guarda: evento, modo, nombre, teléfono, producto, completado, tiempo, piezas colocadas,
errores, precisión y el tiempo (ms) en que se colocó cada pieza.
- `Documents/partidas.json` (fuente)
- `Documents/partidas.csv` (siempre actualizado) → app **Archivos › En mi iPad › Rompe-MASECAS**,
  o en Finder con el iPad conectado por cable.

## Configuración
`RompeMasecas/Core/Models.swift` › `GameConfig`.
