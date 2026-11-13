import 'package:get_it/get_it.dart';

import '../../features/library/data/library_repository.dart';
import '../../features/lyrics/data/lyrics_service.dart';
import '../../features/profiles_backup/domain/profiles_service.dart';
import '../../features/stats_sync/domain/stats_service.dart';
import '../database/app_database.dart';
import '../services/audio_engine_service.dart';
import '../services/backup_service.dart';
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

    final AppDatabase database = AppDatabase();
    sl.registerSingleton<AppDatabase>(database);

    final SettingsService settings = SettingsService(database.settingsDao);
    await settings.load();
    sl.registerSingleton<SettingsService>(settings);

    final AudioEngineService engine = AudioEngineService();
    await engine.initialize();
    sl.registerSingleton<AudioEngineService>(engine);

    final MediaSessionService mediaSession = MediaSessionService(engine);
    await mediaSession.initialize();
    sl.registerSingleton<MediaSessionService>(mediaSession);

    final PlaybackStatsRecorder statsRecorder = PlaybackStatsRecorder(
      engine: engine,
      database: database,
    )..start();
    sl.registerSingleton<PlaybackStatsRecorder>(statsRecorder);

    final WindowService window = WindowService();
    await window.initialize();
    sl.registerSingleton<WindowService>(window);

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

    AppLog.i('Bootstrap', 'Servicios inicializados');
  }

  /// Libera recursos nativos en orden inverso.
  static Future<void> shutdown() async {
    if (sl.isRegistered<TrayService>()) {
      await sl<TrayService>().dispose();
    }
    if (sl.isRegistered<MediaSessionService>()) {
      await sl<MediaSessionService>().dispose();
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
