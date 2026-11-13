# Polaris Music

Reproductor de audio modular para **Windows** y **Android**, parte de la saga Polaris.

Visión: la robustez de **MusicBee** en escritorio, la potencia de **Poweramp** en móvil y un
motor de audio de nivel de estudio, con un sistema visual que se adapta a la carátula y al gusto
del usuario.

---

## Stack

| Área | Decisión | Estado |
|---|---|---|
| UI / lógica | Flutter 3.47 + Riverpod + GetIt | ✅ Fase 1 |
| Escritorio | Flutter Windows (`windows/`) | ✅ build local verificado |
| Móvil | Flutter Android (`android/`) | ⚠️ falta Android SDK local; CI compila APK |
| Audio | `media_kit` (libmpv) | ✅ Fase 1 |
| Biblioteca | Drift + SQLite, escáner de carpetas | ✅ Fase 1 |
| Sesión de medios | `audio_service` (Android) / `smtc_windows` (Windows) | ✅ Fase 1 |
| Temas dinámicos | `AppThemeConfig` + tokens + presets | ✅ Fase 2 |
| CI/CD | GitHub Actions → `.exe` + `.apk` | ✅ pipeline definido |

> Regla del proyecto: ninguna decisión de motor se cierra sin una prueba real de formato,
> gapless, EQ y consumo en segundo plano.

---

## Fases

### Fase 1 — Núcleo reproducible ✅

- Arquitectura limpia por capas (`core`, `features`, `shared`) con la UI aislada de `media_kit`
  y Drift.
- Base de datos Drift con pistas, carpetas, listas, favoritos, letras, presets de EQ, perfiles,
  estadísticas y `settings` clave/valor.
- Escáner de carpetas con `file_picker`, `permission_handler` y lectura de metadatos/carátulas.
- Reproductor con cola, aleatorio, repetición, volumen, velocidad, temporizador de sueño,
  ReplayGain (persistido) y gapless.
- Reproductor mini, isla dinámica, ecualizador (persistencia de presets), estadísticas, perfiles
  y respaldos JSON/ZIP.
- Onboarding, actualizaciones desde GitHub Releases y ventana de escritorio con bandeja.

### Fase 2 — Motor de temas y Now Playing ✅

- `AppThemeConfig` inmutable y serializable con:
  - `cardStyle`: `glassmorphic`, `neumorphic` o `flatMinimal`.
  - `artworkShape`: `squareRounded`, `circleVinyl` o `card3D`.
  - `progressBarType`: `linearClassic`, `waveform` o `circularAroundArtwork`.
  - `colorPaletteMode`: paleta dinámica de la carátula o colores fijos del preset.
- Tres temas base aplicables con un toque:
  1. **Polaris Violet Glass** — violeta profundo, vidrio intenso y vinilo con resplandor.
  2. **Monolith Minimal** — carbón mate, tarjetas planas y onda de audio.
  3. **Bronze Vinyl & Warm Dark** — bronce cálido, vinilo y progreso circular envolvente.
- `NowPlayingScreen` adaptativa: vinilo que gira solo al reproducir, tarjetas glass/neumórficas/
  planas, anillo de progreso interactivo, transiciones `AnimatedSwitcher` y fondo con orbes.
- `CustomizationScreen` con vista previa en vivo, selectores, perfiles personalizados y
  exportación/importación `.json`.
- DSP real del ecualizador: 10 bandas + preamplificador enviados a libmpv como filtros `lavfi`.
- Persistencia en Drift (`theme.config`, `theme.profiles`, compatibilidad con `theme.accent`).

---

## Módulos de la visión

### 1. Arquitectura y núcleo
- [x] Preferencias, favoritos e historial persistidos
- [x] Perfiles de usuario + exportar/importar backups
- [ ] Plugins externos
- [x] Actualizaciones desde GitHub Releases (descarga e instalador)
- [x] CI/CD: APK + EXE por release

### 2. Escritorio
- [x] Modo teléfono (panel flotante lateral con UI móvil)
- [x] Modo mini / ocultación lateral estilo AIMP
- [x] Control de ventana (always on top, etc.)
- [x] Isla dinámica de Windows
- [x] Ecualización DSP real de 10 bandas mediante filtros de libmpv

### 3. Móvil e interfaz
- [x] Glassmorphism + fondo dinámico según carátula
- [x] Motor de temas con presets y perfiles
- [ ] Gestos avanzados estilo Poweramp (pista, volumen, brillo)
- [x] Isla dinámica
- [x] Normalización de volumen (ReplayGain persistido; DSP pendiente)
- [x] Notificación y controles en pantalla de bloqueo

### 4. Gestión y reproducción
- [x] Soporte amplio de formatos vía libmpv
- [x] Explorador/indexador de carpetas locales
- [x] Géneros, álbumes y múltiples vistas de ordenamiento
- [x] Recomendaciones por reproducciones y favoritos
- [x] Letras: detección y panel de letras
- [ ] Modo karaoke
- [x] Tutorial de bienvenida y créditos

---

## Limitaciones conocidas

- **Ecualizador:** las 10 bandas y el preamplificador se aplican con filtros `lavfi` de libmpv
  (`equalizer` + `volume`) en Windows y Android. En plataformas sin libmpv nativo la UI avisa y
  solo se guardan los presets.
- **Crossfade:** el ajuste se persiste, pero el fundido requiere dos decks simultáneos y aún no
  se implementa.
- **Metadatos:** la edición se guarda en Drift; escribir las etiquetas de vuelta al archivo queda
  para una fase posterior.
- **Android local:** sin Android SDK/JDK en el equipo de desarrollo, los APK se generan en CI.
- **`smtc_windows`:** requiere Rust en Windows; el workflow instala el toolchain.

---

## Desarrollo

```powershell
flutter pub get
flutter run -d windows
flutter analyze
flutter test
```

## Notas del entorno local

- Flutter 3.47.6 stable, Visual Studio Build Tools 2022 y Rust → build de Windows OK.
- **No hay Android SDK ni JDK instalados**: los APK se generan en GitHub Actions
  (o instalando Android Studio y apuntando `flutter config --android-sdk`).

## Estructura

```
lib/
  app/            # arranque, shell y navegación
  core/           # base de datos, servicios, tema, providers y utilidades
  features/       # player, equalizer, library, lyrics, dynamic_island, ...
  shared/         # widgets reutilizables (artwork, superficies, estados vacíos)
```
