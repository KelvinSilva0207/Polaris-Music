import 'package:get_it/get_it.dart';

import '../../features/library/data/library_repository.dart';
import '../../features/library/data/metadata_editor_service.dart';
import '../../features/library/data/playlist_service.dart';
import '../../features/lyrics/data/lyrics_service.dart';
import '../../features/online_music/data/audius_source.dart';
import '../../features/online_music/data/download_manager.dart';
import '../../features/online_music/data/metadata_audio_bridge.dart';
import '../../features/online_music/data/online_catalog_repository.dart';
import '../../features/online_music/data/online_music_service.dart';
import '../../features/online_music/data/soundcloud_source.dart';
import '../../features/online_music/data/source_helpers.dart';
import '../../features/online_music/data/spotify_source.dart';
import '../../features/online_music/data/tidal_source.dart';
import '../../features/online_music/data/youtube_music_source.dart';
import '../../features/online_music/domain/music_source.dart';
import '../../features/online_music/domain/music_source_catalog.dart';
import '../../features/online_music/domain/online_music_repository.dart';
import '../../features/online_music/domain/stream_track_use_case.dart';
import '../../features/profiles_backup/domain/profiles_service.dart';
import '../../features/stats_sync/domain/stats_service.dart';
import '../database/app_database.dart';
import '../database/database_guard.dart';
import '../services/app_updater_service.dart';
import '../services/audio_engine_service.dart';
import '../services/backup_service.dart';
import '../services/font_service.dart';
import '../services/global_hotkey_service.dart';
import '../services/media_session_service.dart';
import '../services/permission_service.dart';
import '../services/playback_session_service.dart';
import '../services/playback_stats_recorder.dart';
import '../services/scrobble_service.dart';
import '../services/settings_service.dart';
import '../services/storage_paths_service.dart';
import '../services/audio_device_profile_service.dart';
import '../services/system_audio_service.dart';
import '../services/tray_service.dart';
import '../services/update_service.dart';
import '../services/widget_bridge_service.dart';
import '../services/window_service.dart';
import '../utils/logger.dart';

/// Contenedor de servicios (patrón service locator con GetIt).
///
/// La UI nunca resuelve dependencias de infraestructura directamente: los
/// providers de Riverpod leen de aquí y exponen solo modelos de dominio.
final GetIt sl = GetIt.instance;

/// Inicializa la base de datos, el motor y los servicios de plataforma.
///
/// Debe llamarse una sola vez, antes de `runApp`, después de
/// `MediaKit.ensureInitialized()` y `WidgetsFlutterBinding.ensureInitialized()`.
class ServiceLocator {
  ServiceLocator._();

  static Future<void> bootstrap() async {
    if (sl.isRegistered<AppDatabase>()) return;

    AppLog.i('Bootstrap', 'Verificando base de datos');
    final DatabaseGuardOutcome guard = await DatabaseGuard.prepare(
      targetSchemaVersion: 3,
    );
    if (guard == DatabaseGuardOutcome.recovered) {
      AppLog.w(
        'Bootstrap',
        'La base de datos estaba dañada: se ha aislado y se regenerará',
      );
    }

    AppLog.i('Bootstrap', 'Abriendo base de datos');
    AppDatabase database;
    try {
      database = await _openDatabase();
    } on DatabaseCorruptionException catch (error, stack) {
      AppLog.e(
        'Bootstrap',
        'Corrupción detectada al abrir: $error',
        error,
        stack,
      );
      await DatabaseGuard.quarantine(
        await DatabaseGuard.databaseFile(),
        reason: '$error',
      );
      database = await _openDatabase();
    }
    sl.registerSingleton<AppDatabase>(database);

    AppLog.i('Bootstrap', 'Cargando preferencias');
    final SettingsService settings = SettingsService(database.settingsDao);
    await settings.load();
    sl.registerSingleton<SettingsService>(settings);
    final StoragePathsService storagePaths = StoragePathsService(settings);
    sl.registerSingleton<StoragePathsService>(storagePaths);
    sl.registerSingleton<PlaybackSessionService>(
      PlaybackSessionService(settings),
    );

    AppLog.i('Bootstrap', 'Registrando fuentes importadas');
    final FontService fontService = FontService(settings);
    await fontService.restore();
    sl.registerSingleton<FontService>(fontService);

    final PermissionService permissions = PermissionService();
    sl.registerSingleton<PermissionService>(permissions);

    AppLog.i('Bootstrap', 'Iniciando motor de audio');
    final AudioEngineService engine = AudioEngineService(
      isBackgrounded: () =>
          sl.isRegistered<WindowService>() && sl<WindowService>().backgrounded,
      refreshLocalAccess: permissions.refreshLibraryAccess,
      // El repositorio online se registra más abajo: se resuelve en el momento
      // del reintento, cuando ya existe y solo se usa si la pista es online.
      refreshStream: (track) async {
        if (!sl.isRegistered<StreamTrackUseCase>()) return null;
        try {
          return await sl<StreamTrackUseCase>().refresh(track);
        } on Object catch (error, stack) {
          AppLog.w(
            'Bootstrap',
            'No se pudo refrescar el audio de “${track.title}”',
            error,
            stack,
          );
          return null;
        }
      },
    );
    await engine.initialize();
    sl.registerSingleton<AudioEngineService>(engine);

    // El volumen inicial es 50 %; si el usuario ya eligió otro, se respeta.
    await engine.setVolume(
      (settings.volume * 100).clamp(0.0, 100.0).toDouble(),
    );

    AppLog.i('Bootstrap', 'Iniciando sesión multimedia');
    final MediaSessionService mediaSession = MediaSessionService(engine);
    await mediaSession.initialize();
    sl.registerSingleton<MediaSessionService>(mediaSession);

    AppLog.i('Bootstrap', 'Suscribiendo eventos del sistema');
    final SystemAudioService systemAudio = SystemAudioService(
      engine: engine,
      settings: settings,
    );
    await systemAudio.initialize();
    sl.registerSingleton<SystemAudioService>(systemAudio);
    sl.registerSingleton<AudioDeviceProfileService>(
      AudioDeviceProfileService(settings: settings, systemAudio: systemAudio),
    );

    AppLog.i('Bootstrap', 'Registrando atajos globales');
    final GlobalHotkeyService hotkeys = GlobalHotkeyService(
      settings: settings,
      onAction: (HotkeyAction action) async {
        switch (action) {
          case HotkeyAction.playPause:
            await engine.playOrPause();
          case HotkeyAction.next:
            await engine.next();
          case HotkeyAction.previous:
            await engine.previous();
        }
      },
    );
    await hotkeys.initialize();
    sl.registerSingleton<GlobalHotkeyService>(hotkeys);

    sl.registerSingleton<WidgetBridgeService>(WidgetBridgeService());

    final ScrobbleService scrobbler = ScrobbleService(settings: settings);
    sl.registerSingleton<ScrobbleService>(scrobbler);

    final PlaybackStatsRecorder statsRecorder = PlaybackStatsRecorder(
      engine: engine,
      database: database,
      scrobbler: scrobbler,
      widgetBridge: sl<WidgetBridgeService>(),
    )..start();
    sl.registerSingleton<PlaybackStatsRecorder>(statsRecorder);

    AppLog.i('Bootstrap', 'Preparando ventana');
    final WindowService window = WindowService();
    await window.initialize();
    sl.registerSingleton<WindowService>(window);

    AppLog.i('Bootstrap', 'Preparando bandeja del sistema');
    final TrayService tray = TrayService(engine: engine, window: window);
    await tray.initialize();
    sl.registerSingleton<TrayService>(tray);
    window.hideOnClose = tray.isInitialized;

    final AppUpdaterService updater = AppUpdaterService(
      updatesDirectory: storagePaths.updates,
    );
    sl.registerSingleton<AppUpdaterService>(updater);
    sl.registerSingleton<UpdateService>(updater);
    sl.registerSingleton<BackupService>(
      BackupService(database, settingsService: settings),
    );
    sl.registerSingleton<LibraryRepository>(
      LibraryRepository(database, settings: settings),
    );
    sl.registerSingleton<PlaylistService>(
      PlaylistService(database, sl<LibraryRepository>()),
    );
    // Reparación puntual de carátulas borradas por escaneos anteriores; no
    // lee imágenes y funciona incluso si el escaneo automático está desactivado.
    // Un fallo aquí nunca debe impedir que la interfaz arranque.
    try {
      await sl<LibraryRepository>().scanner.restoreArtworkPaths();
    } catch (error, stack) {
      AppLog.w('Bootstrap', 'No se pudieron recuperar carátulas', error, stack);
    }
    sl.registerSingleton<MetadataEditorService>(
      MetadataEditorService(sl<LibraryRepository>()),
    );
    sl.registerSingleton<LyricsService>(LyricsService(database.lyricsDao));
    sl.registerSingleton<StatsService>(StatsService(database));
    sl.registerSingleton<ProfilesService>(
      ProfilesService(database, settings: settings),
    );

    AppLog.i('Bootstrap', 'Preparando catálogo online y descargas');
    sl.registerLazySingleton<OnlineMusicService>(() => OnlineMusicService());
    sl.registerLazySingleton<ArtworkCache>(() => ArtworkCache());
    sl.registerLazySingleton<AudiusSource>(
      () => AudiusSource(sl<OnlineMusicService>()),
    );
    sl.registerLazySingleton<SoundCloudSource>(
      () => SoundCloudSource(
        settings: settings,
        artworkCache: sl<ArtworkCache>(),
      ),
    );
    sl.registerLazySingleton<SpotifySource>(
      () => SpotifySource(settings: settings, artworkCache: sl<ArtworkCache>()),
    );
    sl.registerLazySingleton<TidalSource>(
      () => TidalSource(settings: settings, artworkCache: sl<ArtworkCache>()),
    );
    sl.registerLazySingleton<YouTubeMusicSource>(
      () => YouTubeMusicSource(artworkCache: sl<ArtworkCache>()),
    );
    sl.registerLazySingleton<MusicSourceCatalog>(
      () => MusicSourceCatalog(<MusicSourceProvider>[
        sl<AudiusSource>(),
        sl<YouTubeMusicSource>(),
        sl<SoundCloudSource>(),
        sl<SpotifySource>(),
        sl<TidalSource>(),
      ]),
    );
    sl.registerLazySingleton<MetadataAudioBridge>(
      () => MetadataAudioBridge(sl<MusicSourceCatalog>()),
    );
    sl.registerLazySingleton<OnlineMusicRepository>(
      () => OnlineCatalogRepository(
        catalog: sl<MusicSourceCatalog>(),
        artworkCache: sl<ArtworkCache>(),
        bridge: sl<MetadataAudioBridge>(),
      ),
    );
    sl.registerLazySingleton<StreamTrackUseCase>(
      () => StreamTrackUseCase(sl<OnlineMusicRepository>()),
    );
    sl.registerLazySingleton<DownloadManager>(
      () => DownloadManager(
        repository: sl<OnlineMusicRepository>(),
        registerDownloaded: sl<LibraryRepository>().registerDownloaded,
        hasDownloaded: sl<LibraryRepository>().hasExternalId,
        musicDirectory: sl<StoragePathsService>().music,
      ),
    );

    AppLog.i('Bootstrap', 'Servicios inicializados');
  }

  /// Crea la base de datos y fuerza la apertura para que las migraciones y el
  /// `beforeOpen` se ejecuten dentro del `try` del bootstrap.
  static Future<AppDatabase> _openDatabase() async {
    final AppDatabase database = AppDatabase();
    try {
      await database.customSelect('SELECT 1').get();
      return database;
    } catch (error, stack) {
      await database.close();
      Error.throwWithStackTrace(error, stack);
    }
  }

  /// Cierre completo en Android.
  ///
  /// Conservado por compatibilidad con Ajustes: ahora delega en [shutdown],
  /// que también detiene la notificación y el servicio en primer plano.
  static Future<void> shutdownAndroid() => shutdown();

  /// Libera recursos nativos en orden inverso.
  ///
  /// En Android se usa `MediaSessionService.shutdown()` (no solo `dispose()`)
  /// para retirar la notificación y detener el `AudioService` antes de cerrar
  /// la base de datos. Así el botón `X` y el cierre desde Ajustes comparten la
  /// misma secuencia y no quedan servicios en segundo plano.
  static Future<void> shutdown() async {
    if (sl.isRegistered<PlaybackSessionService>()) {
      await sl<PlaybackSessionService>().flush();
    }
    if (sl.isRegistered<GlobalHotkeyService>()) {
      await sl<GlobalHotkeyService>().dispose();
    }
    if (sl.isRegistered<TrayService>()) {
      await sl<TrayService>().dispose();
    }
    if (sl.isRegistered<WindowService>()) {
      await sl<WindowService>().dispose();
    }
    if (sl.isRegistered<MediaSessionService>()) {
      await sl<MediaSessionService>().shutdown();
    }
    if (sl.isRegistered<AudioDeviceProfileService>()) {
      await sl<AudioDeviceProfileService>().dispose();
    }
    if (sl.isRegistered<SystemAudioService>()) {
      await sl<SystemAudioService>().dispose();
    }
    if (sl.isRegistered<DownloadManager>()) {
      await sl<DownloadManager>().dispose();
    }
    if (sl.isRegistered<OnlineMusicService>()) {
      await sl<OnlineMusicService>().dispose();
    }
    if (sl.isRegistered<ArtworkCache>()) {
      sl<ArtworkCache>().dispose();
    }
    if (sl.isRegistered<LibraryRepository>()) {
      await sl<LibraryRepository>().dispose();
    }
    if (sl.isRegistered<PlaybackStatsRecorder>()) {
      await sl<PlaybackStatsRecorder>().dispose();
    }
    if (sl.isRegistered<SettingsService>()) {
      await sl<SettingsService>().dispose();
    }
    if (sl.isRegistered<AudioEngineService>()) {
      await sl<AudioEngineService>().dispose();
    }
    if (sl.isRegistered<AppDatabase>()) {
      await sl<AppDatabase>().close();
    }
    await sl.reset();
  }
}
