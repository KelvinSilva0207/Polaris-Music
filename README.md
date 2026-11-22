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
| CI/CD | GitHub Actions → instalador `.exe` + `.apk` | ✅ release automática |

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
- Los tokens de panel (`panelColor`, `panelBorder`, `panelShadows`, `panelDecoration`) hacen que
  el estilo de tarjeta activo afecte a mini reproductor, isla dinámica, ajustes, inicio,
  biblioteca, ecualizador, estadísticas y bienvenida, no solo a Now Playing.
- DSP real del ecualizador: 10 bandas + preamplificador enviados a libmpv como filtros `lavfi`.
- Persistencia en Drift (`theme.config`, `theme.profiles`, compatibilidad con `theme.accent`).

### Fase 3 — Refinamiento de UI y propiedades ✅

- Barra de progreso protagonista: 9 px, degradado con el acento de la carátula, resplandor,
  indicador tipo píldora que crece al pasar el ratón o arrastrar y tooltip con el tiempo exacto.
- Control de volumen diferenciado: riel fino segmentado, altavoz clicable para silenciar/restaurar
  y rueda del ratón sobre el control.
- Modal **Propiedades** desde clic derecho (escritorio), menú de opciones (Android) o pulsación
  larga: archivo, calidad real del contenedor, metadatos ID3/Vorbis/MP4, carátula ampliable y
  estadísticas de Drift.
- Micro-animaciones: escala al pulsar, transición de pista y vinilo con giro orgánico; sin
  indicadores tipo panel de administración.

### Fase 4 — Audio avanzado y respaldo completo ✅

- **Perfiles por dispositivo de salida:** el EQ (curva, modo, filtros paramétricos y sub-armónico)
  se guarda por salida con scopes `device:<endpoint>` y se aplica al cambiar entre altavoces,
  Bluetooth o USB. El perfil global sigue intacto como fallback.
- **Crossfade real:** dos decks libmpv con fundido configurable (0–12 s) y relevo del deck entrante
  al principal. El fundido usa un multiplicador de ganancia independiente del temporizador de sueño.
- **Recorte de silencios:** offsets `start`/`end` de `Media` para omitir silencios al inicio/final
  (0–15 s cada lado), sin añadir filtros a la cadena `af` del ecualizador.
- **Repetidor A-B:** marca A y B desde el reproductor y repite el fragmento hasta desactivarlo; se
  desarma automáticamente al cambiar de pista.
- **Respaldo v2:** JSON/ZIP con preferencias globales y por scope, perfiles activos, presets de EQ
  con DSP completo, listas, favoritos, letras y temas RGB/HSL. Importa también respaldos v1 y
  muestra avisos por bloque restaurado parcialmente.

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
- [x] Modo puro / sin filtros (bypass de todo el DSP sin borrar la curva guardada)
- [x] Anti-clip: preamp automático y limitador suave solo con filtros activos

### 3. Móvil e interfaz
- [x] Glassmorphism + fondo dinámico según carátula
- [x] Motor de temas con presets y perfiles
- [x] Gestos avanzados estilo Poweramp (borde derecho = volumen, borde izquierdo = brillo en Android)
- [x] Isla dinámica
- [x] Normalización de volumen (ReplayGain aplicado sobre el volumen efectivo)
- [x] Notificación y controles en pantalla de bloqueo

### 4. Gestión y reproducción
- [x] Soporte amplio de formatos vía libmpv
- [x] Explorador/indexador de carpetas locales
- [x] Géneros, álbumes y múltiples vistas de ordenamiento
- [x] Recomendaciones por reproducciones y favoritos
- [x] Letras: detección y panel de letras
- [x] Modo karaoke
- [x] Tutorial de bienvenida y créditos

### 5. Recomendaciones de la comunidad
- [x] Reproducción gapless y crossfade (mutuamente excluyentes)
- [x] Búsqueda con debounce y términos recientes
- [x] Temporizador de sueño personalizado con fundido
- [x] Informe de diagnóstico copiable
- [x] Karaoke con resaltado por palabra y salto al tocar una línea
- [x] Listas M3U (importar y exportar)
- [x] Listas inteligentes (favoritos, más reproducidas, recientes, largas)
- [x] Reordenar la cola arrastrando
- [x] Etiquetas accesibles en controles de transporte, cola y letras
- [x] Escribir metadatos de vuelta al archivo
- [x] Widget de Android (carátula, título y transporte esencial)
- [x] Integración con Android Auto (árbol de navegación desde `audio_service`)
- [x] Scrobbling (Last.fm o servidor compatible; requiere credenciales del usuario)
- [x] Gestos de volumen y brillo
- [x] Inspector técnico de la pista (códec, contenedor, bitrate, muestreo, canales, duración, fuente y tamaño)

---

## Limitaciones conocidas

- **Ecualizador:** las 10 bandas y el preamplificador se aplican con filtros `lavfi` de libmpv
  (`equalizer` + `volume`) en Windows y Android. En plataformas sin libmpv nativo la UI avisa y
  solo se guardan los presets.
- **Crossfade:** se usa un segundo deck libmpv; en equipos muy lentos un fundido muy corto puede
  notarse como una pausa breve mientras el deck entrante abre el archivo.
- **Metadatos:** la edición escribe las etiquetas en el archivo y actualiza Drift. Si el archivo es
  de solo lectura o está en uso, se conserva el cambio en la base de datos y se registra el aviso.
- **Scrobbling:** el flujo local está cubierto por tests; enviar escuchas de verdad requiere
  `api key` y `api secret` de Last.fm (o de un servidor compatible configurado en Ajustes).
- **Widget / Android Auto:** dependen del launcher y del coche; si el sistema no los expone, la
  reproducción y la interfaz de la app siguen funcionando con normalidad.
- **Android local:** sin Android SDK/JDK en el equipo de desarrollo, los APK se generan en CI.
- **`permission_handler`:** fijado en `^12.0.3`; la rama 13 usa un plugin Android que exige
  `compileSdk 37`, mientras que Flutter 3.47.6 compila contra 36.
- **`smtc_windows`:** requiere Rust en Windows; el workflow instala el toolchain.
- **CI Linux:** el job de tests instala `libgtk-3-dev`, `libx11-dev` y `libxi-dev` porque los
  *native assets* de `cnativeapi` los necesitan para compilar.

---

## Desarrollo

```powershell
flutter pub get
flutter run -d windows
flutter analyze
flutter test
```

## Instalador de Windows

La app se distribuye con un instalador de **Inno Setup 6** con el mismo lenguaje visual
(panel oscuro, logo, tipografía y textos en español). El resultado es
`Polaris-Music-Setup-<versión>.exe`, publicado automáticamente en cada release de GitHub.

### Instalar

1. Descarga el instalador desde [Releases](https://github.com/KelvinSilva0207/Polaris-Music/releases).
2. Ejecútalo. Por defecto se instala **solo para el usuario actual**
   (`%LOCALAPPDATA%\Programs\Polaris Music`), sin pedir UAC.
3. Si eres administrador, el asistente ofrece instalar para **todos los usuarios**
   (`C:\Program Files\Polaris Music`). También puede forzarse con `/ALLUSERS`.
4. Se crean accesos directos en el menú Inicio y, opcionalmente, en el escritorio.

La desinstalación se hace desde **Configuración → Aplicaciones → Polaris Music**.
Los datos de usuario (biblioteca, temas y respaldos) se conservan.

### Compilar el instalador

Requisitos: Flutter con soporte Windows e [Inno Setup 6](https://jrsoftware.org/isinfo.php).

```powershell
winget install --id JRSoftware.InnoSetup -e

# Compila la app y el instalador
powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1

# Reutiliza el build existente
powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1 -SkipBuild
```

La versión se lee de `pubspec.yaml`; `installer/Output/` está ignorado por Git.
El CI instala Inno Setup con Chocolatey, compila el instalador en cada push y lo adjunta
a la release cuando se publica un tag `v*`.

### Carpetas estándar

Polaris usa rutas predecibles y las muestra en **Ajustes → Carpetas y archivos**,
donde se pueden abrir, cambiar o restaurar:

| Contenido | Windows | Android |
|---|---|---|
| Datos internos (Drift, ajustes, caché) | `%LOCALAPPDATA%\Polaris Music` | almacenamiento privado de la app |
| Documentos y exportaciones | `Documentos\Polaris Music` | directorio Documents propio de la app |
| Música descargada | `Música\Polaris Music` | directorio Music propio de la app |
| Actualizaciones | `Descargas\Polaris Music\Updates` | directorio Download propio de la app, `Polaris Music\Updates` |

En Android no se necesita `WRITE_EXTERNAL_STORAGE`: las descargas viven en el
almacenamiento externo **propio del paquete** y se comparten con el instalador
mediante `FileProvider`. Las carpetas elegidas a mano se recuerdan en la base de datos.

### Autoactualización desde la app

`UpdateService` consulta `releases/latest`, prioriza el asset `Polaris-Music-Setup-*.exe`
y lo descarga en `Descargas\Polaris Music\Updates` (o su equivalente Android).
En **Ajustes → Actualizaciones** aparece **Instalar ahora**:

1. La app confirma y ejecuta el instalador con
   `/SILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /LOG /AUTOUPDATE`.
2. Se cierra para liberar el ejecutable.
3. Inno Setup instala la nueva versión y vuelve a abrir Polaris Music al terminar.

En una instalación para todos los usuarios, la actualización solicita UAC una vez.
Para que el flujo silencioso funcione sin interrupciones, la instalación recomendada es
la de usuario actual.

> Nota: el instalador no está firmado con un certificado de code signing, por lo que
> Windows SmartScreen puede mostrar una advertencia la primera vez. Se puede firmar en CI
> añadiendo un certificado y configurando `SignTool` en Inno Setup.

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
installer/        # Inno Setup, imágenes del asistente y script de compilación
```
