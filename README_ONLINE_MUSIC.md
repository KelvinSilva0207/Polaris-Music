# Módulo de Música Online y Descargas para Polaris Music

## Resumen

Esta es la implementación del **Módulo de Música Online y Descargas** para Polaris Music, siguiendo la arquitectura Clean Architecture y el patrón estilo Metrolist. Permite buscar pistas en el catálogo abierto de Audius, reproducirlas en streaming y descargarlas a la biblioteca local.

## Características

### 1. Búsqueda y Exploración Online
- **Catálogo abierto de Audius**: Sin necesidad de API key, siguiendo los endpoints públicos
- **Búsqueda por título, artista o género**: Resultados en tiempo real con debounce
- **Tendencias**: Listado inicial de pistas populares
- **Visualización de resultados**: Carátula, título, artista, duración y badge de fuente

### 2. Reproducción en Streaming
- **URL directa de audio**: Resolución mediante HTTP con seguimiento de redirecciones
- **Integración con media_kit**: Comportamiento idéntico al de pistas locales
- **Controles completos**: Volumen, progreso, letras, ecualizador
- **Badge de origen**: Indicador visual claro de streaming vs local

### 3. Descargas Offline
- **Cola de descargas**: Máximo 2 descargas simultáneas con progreso y cancelación
- **Cache de carátulas**: Almacenamiento local de imágenes para visualización offline
- **Registro en biblioteca**: Las descargas aparecen instantáneamente en la biblioteca local
- **Deduplicación**: Evita descargas repetidas por mismo `externalId`

### 4. Experiencia de Usuario
- **Interfaz fluida**: Diseñada con tokens del tema (`Violet Glass`, `Monolith`, `Bronze`)
- **Navegación integrada**: Pestaña "Online" en la barra de navegación principal
- **Feedback en tiempo real**: Estados de descarga (cola, descargando, completada, fallida)
- **Modo offline**: Controles idénticos a pistas locales con badge de streaming

## Arquitectura

### Capa de Datos (`data/`)
- `OnlineMusicService`: Cliente HTTP para Audius API
- `DownloadManager`: Gestión de cola de descargas con `dio`
- `AudiusTrackDto`: Modelo de transporte de datos

### Capa de Dominio (`domain/`)
- `OnlineMusicRepository`: Contrato abstracto de búsqueda/resolución
- `OnlineTrack`: Modelo de pista online
- `ResolvedStream`: Resultado de resolución de URL
- `SearchOnlineTracksUseCase`, `StreamTrackUseCase`, `DownloadTrackUseCase`: Casos de uso

### Capa de Presentación (`presentation/`)
- `OnlineMusicScreen`: Pantalla principal de búsqueda y exploración
- `OnlineMusicProviders`: Providers de Riverpod
- Componentes UI: `_OnlineTrackTile`, `_DownloadsPanel`, `_OnlineArtwork`, etc.

## Tecnologías Clave

### Audius API
- Endpoints: `/v1/tracks/search`, `/v1/tracks/trending`, `/v1/tracks/{id}/stream`
- Sin autenticación necesaria
- Resultados JSON estandarizados

### `dio`
- HTTP client con timeouts configurables
- Seguimiento de progreso de descargas
- Manejo de redirecciones

### Drift SQLite
- Almacenamiento local de pistas descargadas
- Columnas `source` y `externalId` para distinguir fuentes
- Migración automática de v1 a v2

### media_kit
- Motor de reproducción universal
- Soporte para streaming desde URLs directas
- Sincronización con estados de reproductor local

## Flujos de Uso

### 1. Búsqueda de Pistas Online
```dart
// Usuario escribe "lofi" en el campo de búsqueda
// El controlador aplica debounce de 450ms
// Se consulta la API de Audius
// Se muestran resultados en tiempo real
```

### 2. Reproducción en Streaming
```dart
// Usuario toca una pista online
// Se resuelve la URL de audio directa
// Se cachea la carátula si no está en disco
// Se reproduce mediante media_kit
// El reproductor se comporta como con pistas locales
```

### 3. Descarga a Biblioteca Local
```dart
// Usuario toca el botón "Descargar"
// Se añade a la cola de descargas (máx. 2 simultáneas)
// Dio descarga el archivo de audio
// Se guarda en `downloads/music/`
// Se registra en Drift con `source='download'`
// Aparece en biblioteca con ícono de nube
```

### 4. Visualización de Estado de Descarga
```dart
// Cola: Indicador de progreso circular + botón cancelar
// Descargando: Barra de progreso + botón cancelar
// Completada: Ícono de nube ✅ + desactivada
// Fallida: Ícono de error + botón reintentar
```

## Tokens Visuales

El módulo respeta el tema activo:
- **Temas**: `Violet Glass`, `Monolith`, `Bronze`
- **Componentes**: `PolarisSurface`, `TrackArtwork`, `_SourceBadge`, `_DownloadAction`
- **Iconos**: `Icons.cloud_queue_rounded` (streaming), `Icons.cloud_done_rounded` (descargada), `Icons.offline_pin_rounded` (local)

## Integraciones

### with Biblioteca Local
- `LibraryRepository.registerDownloaded()`: Persiste descargas
- `Track.fromRow()`: Distinción por `source='download'`
- `watchDownloadedExternalIds()`: Reactividad para nube en UI

### with Reproductor
- `StreamTrackUseCase`: Convierte `OnlineTrack` a `Track` reproducible
- `playerControllerProvider`: Funciona idéntico a pistas locales
- `NowPlayingScreen`: Muestra `_TrackOriginBadge` para streaming vs local

### with Letreros
- Resolución desde LRCLIB
- Cache en Drift solo para pistas persistidas (`isPersisted`)

## Código de Barra

### _TrackOriginBadge
```dart
final (IconData icon, String label) = switch (track.origin) {
  TrackOrigin.local => (Icons.offline_pin_rounded, 'Local'),
  TrackOrigin.downloaded => (Icons.cloud_done_rounded, 'Descargada'),
  TrackOrigin.online => (Icons.cloud_queue_rounded, 'Streaming'),
};
```

### Badge en NowPlayingScreen
```dart
class _TrackOriginBadge extends StatelessWidget {
  const _TrackOriginBadge({required this.track, required this.accent});
  // Implementa UI con color/tooltip según origen
}
```

## Compatibilidad

### Android
- Permisos: `INTERNET`, `ACCESS_NETWORK_STATE`
- Almacenamiento: `downloads/music/` en directorio de datos de app
- Sin solicitud de permisos de almacenamiento externo

### Windows
- Guía local: `downloads/music/` relativa al directorio de datos de app
- Compatibilidad con batuta: `AppPaths.music()`

### iOS (futuro)
- Se seguirá patrón de Flutter estándar

## Pruebas

### Test Suite
- `test/online_music_test.dart`: 8 tests unitarios
- DTO, id efímero, `Track.online`, `DownloadTask`
- Cobertura completa de casos de uso principales

### Verificación Manual
- [x] OCR inicial y navegación a pestaña Online
- [x] Campo de búsqueda y tendencias
- [x] Reproducción de pista (streaming)
- [x] Descarga de pista
- [x] Badge de origen en Now Playing
- [x] Nube en biblioteca local

## Instalar y Ejecutar

```bash
# Asegurar dependencias
dart pub get

# Generar drift
flutter packages pub run build_runner build

# Analizar
flutter analyze

# Probar
flutter test

# Construir (Windows)
flutter build windows --release

# Construir (Android)
flutter build apk --release --no-tree-shake
```

## Contribuciones

### Colaboradores
- **Arquitecto de Software**: Diseña componentes reutilizables
- **Desarrollador Flutter**: Implementa casos de uso y UI
- **QA**: Verifica OCR y flujos de usuario

### Publicación
- **Lanzamiento v1.0.2**: Con módulo online
- **Changelog**: Documenta nuevas funcionalidades
- **Documentación**: Actualiza README y notas de versión

## Referencias

- [Documentación de Audius API](https://docs.audius.co/)
- [Guía de media_kit](https://pub.dev/packages/media_kit)
- [Patrón Clean Architecture](https://blog.cleancoder.com/2012/08/13/the-clean-architecture.html)
- [Riverpod State Management](https://riverpod.dev/docs/concepts/overview)