# Polaris Music

Reproductor de audio multiplataforma para **Windows** y **Android**, parte de la saga Polaris.

Visión: la robustez de **MusicBee** en escritorio, la potencia de **Poweramp** en móvil y un
motor de audio de nivel de estudio, con una estética glassmorphism oscura con acentos morados.

---

## Stack

| Área | Decisión | Estado |
|---|---|---|
| UI / lógica | Flutter 3.47 (Dart) | ✅ base creada |
| Escritorio | Flutter Windows (`windows/`) | ✅ compila |
| Móvil | Flutter Android (`android/`) | ⚠️ falta Android SDK local; CI puede compilar |
| Audio | Por definir (spike de motor) | ⏳ |
| CI/CD | GitHub Actions → `.exe` + `.apk` | ⏳ |
| Distribución | GitHub Releases + updater propio | ⏳ |

### Candidatos de motor de audio (a validar con un spike)

- **media_kit** (libmpv): cobertura amplia de formatos en Windows y Android, filtros/EQ vía mpv.
- **just_audio + audio_service**: excelente integración Android (notificación, media session).
- **FFmpeg (ffmpeg_kit / ffi)**: decodificación universal y análisis (ReplayGain, letras, waveform).

> Regla del proyecto: ninguna decisión de motor se cierra sin una prueba real de formato,
> gapless, EQ y consumo en segundo plano.

---

## Módulos de la visión

### 1. Arquitectura y núcleo
- [ ] Multiplataforma real con preferencias, favoritos e historial sincronizables
- [ ] Perfiles de usuario + exportar/importar backups
- [ ] Plugins externos
- [ ] Actualizaciones automáticas desde GitHub Releases
- [ ] CI/CD: APK + EXE por release

### 2. Escritorio
- [ ] Modo teléfono (panel flotante lateral con UI móvil)
- [ ] Modo mini / ocultación lateral estilo AIMP
- [ ] Control de ventana (always on top, etc.)
- [ ] Isla dinámica de Windows
- [ ] Ecualización avanzada estilo FXSound

### 3. Móvil e interfaz
- [ ] Glassmorphism + fondo dinámico según carátula
- [ ] Gestos avanzados estilo Poweramp (pista, volumen, brillo)
- [ ] Isla dinámica móvil
- [ ] Normalización de volumen (ReplayGain)
- [ ] Notificación y controles en pantalla de bloqueo

### 4. Gestión y reproducción
- [ ] Soporte universal de formatos
- [ ] Explorador/indexador de carpetas locales
- [ ] Géneros, álbumes y múltiples vistas de ordenamiento
- [ ] Recomendaciones por reproducciones y favoritos (corazones)
- [ ] Letras: detección, búsqueda, descarga y sincronía
- [ ] Modo karaoke
- [ ] Tutorial de bienvenida y créditos

> Todos los módulos deben poder activarse/desactivarse en Ajustes para no penalizar el rendimiento.

---

## Estado del repositorio

- Esqueleto Flutter (`polaris_music`) con plataformas `android` y `windows`.
- Remoto: <https://github.com/KelvinSilva0207/Polaris-Music.git>
- Versión: `0.1.0+1`

## Desarrollo

```powershell
flutter pub get
flutter run -d windows
flutter analyze
flutter test
```

## Notas del entorno local

- Flutter 3.47.6 stable, Visual Studio Build Tools 2022 → build de Windows OK.
- **No hay Android SDK ni JDK instalados**: los APK se generarán en GitHub Actions
  (o instalando Android Studio y apuntando `flutter config --android-sdk`).
