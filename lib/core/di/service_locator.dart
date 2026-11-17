import 'package:get_it/get_it.dart';

import '../../features/library/data/library_repository.dart';
import '../../features/lyrics/data/lyrics_service.dart';
import '../../features/online_music/data/download_manager.dart';
import '../../features/online_music/data/online_music_service.dart';
import '../../features/profiles_backup/domain/profiles_service.dart';
import '../../features/stats_sync/domain/stats_service.dart';
import '../database/app_database.dart';
import '../services/audio_engine_service.dart';
import '../services/backup_service.dart';
import '../services/global_hotkey_service.dart';
import '../services/media_session_service.dart';
import '../services/permission_service.dart';
import '../services/playback_stats_recorder.dart';
import '../services/settings_service.dart';
import '../services/tray_service.dart';
import '../services/update_service.dart';
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

    AppLog.i('Bootstrap', 'Abriendo base de datos');
    final AppDatabase database = AppDatabase();
    sl.registerSingleton<AppDatabase>(database);

    AppLog.i('Bootstrap', 'Cargando preferencias');
    final SettingsService settings = SettingsService(database.settingsDao);
    await settings.load();
    sl.registerSingleton<SettingsService>(settings);

    AppLog.i('Bootstrap', 'Iniciando motor de audio');
    final AudioEngineService engine = AudioEngineService();
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

    final PlaybackStatsRecorder statsRecorder = PlaybackStatsRecorder(
      engine: engine,
      database: database,
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

    sl.registerSingleton<PermissionService>(PermissionService());
    sl.registerSingleton<UpdateService>(UpdateService());
    sl.registerSingleton<BackupService>(BackupService(database));
    sl.registerSingleton<LibraryRepository>(LibraryRepository(database));
    sl.registerSingleton<LyricsService>(LyricsService(database.lyricsDao));
    sl.registerSingleton<StatsService>(StatsService(database));
    sl.registerSingleton<ProfilesService>(ProfilesService(database));

    AppLog.i('Bootstrap', 'Preparando catálogo online y descargas');
    sl.registerLazySingleton<OnlineMusicService>(() => OnlineMusicService());
    sl.registerLazySingleton<DownloadManager>(
      () => DownloadManager(
        repository: sl<OnlineMusicService>(),
        registerDownloaded: sl<LibraryRepository>().registerDownloaded,
        hasDownloaded: sl<LibraryRepository>().hasExternalId,
      ),
    );

    AppLog.i('Bootstrap', 'Servicios inicializados');
  }

  /// Libera recursos nativos en orden inverso.
  static Future<void> shutdown() async {
    if (sl.isRegistered<GlobalHotkeyService>()) {
      await sl<GlobalHotkeyService>().dispose();
    }
    if (sl.isRegistered<TrayService>()) {
      await sl<TrayService>().dispose();
    }
    if (sl.isRegistered<MediaSessionService>()) {
      await sl<MediaSessionService>().dispose();
    }
    if (sl.isRegistered<DownloadManager>()) {
      await sl<DownloadManager>().dispose();
    }
    if (sl.isRegistered<OnlineMusicService>()) {
      await sl<OnlineMusicService>().dispose();
    }
    if (sl.isRegistered<LibraryRepository>()) {
      await sl<LibraryRepository>().dispose();
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
