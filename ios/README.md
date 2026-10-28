# Rompe-MASECAS · iPad

Versión nativa en SwiftUI del juego web (`index.html`). iPad, horizontal, iPadOS 17+.

## Abrir y correr
1. Abre `ios/RompeMasecas/RompeMasecas.xcodeproj` (Xcode 16 o superior).
2. Target **RompeMasecas** › **Signing & Capabilities** › elige tu **Team**.
3. Conecta el iPad o usa el simulador **iPad (A16)** / **iPad Pro 11"** y dale **Run** (⌘R).

## Qué hace igual que el web
- Registro con celular de 10 dígitos (teclado numérico en pantalla).
- 10 s para memorizar un producto al azar (productos 1–5).
- 60 s para armar el 3×3 arrastrando piezas; 9 correctas + 11 trampa.
- Ranking Top 20 guardado en el iPad, celular enmascarado.

## Extras nativos
- Drag táctil con pieza flotante, casilla resaltada al pasar, sacudida en error.
- Barra de tiempo que se pone roja los últimos 10 s.
- Resultado regresa solo al inicio a los 45 s; la pantalla no se apaga.
- **Admin oculto:** mantén presionado el logo 3 s → exportar CSV con celulares completos y borrar ranking.

## Configuración rápida
`RompeMasecas/Core/Models.swift` › `GameConfig` (productos, segundos, piezas trampa, etc.).
Los assets salen de `/assets` y están en `Assets.xcassets`.
