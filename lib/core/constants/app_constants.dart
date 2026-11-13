/// Constantes globales de Polaris Music.
///
/// Un único lugar para identidad de la app, extensiones soportadas y los
/// parámetros del motor de audio.
class AppConstants {
  AppConstants._();

  static const String appName = 'Polaris Music';
  static const String appVersionFallback = '0.1.0';
  static const String githubOwner = 'KelvinSilva0207';
  static const String githubRepo = 'Polaris-Music';
  static const String githubReleasesUrl =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';
  static const String githubReleasesPage =
      'https://github.com/$githubOwner/$githubRepo/releases';

  /// Extensiones que el escáner intenta indexar.
  ///
  /// media_kit/libmpv reproduce prácticamente todo lo que decodifique FFmpeg;
  /// esta lista solo filtra archivos al recorrer carpetas.
  static const Set<String> audioExtensions = <String>{
    'mp3',
    'flac',
    'wav',
    'aac',
    'm4a',
    'alac',
    'ogg',
    'oga',
    'opus',
    'wma',
    'aiff',
    'aif',
    'ape',
    'wv',
    'mka',
    'dsf',
    'dff',
    'mpc',
    'mp2',
    'mp4',
    'webm',
    'caf',
    'amr',
    'ac3',
    'dts',
    'tta',
    'spx',
  };

  /// Bandas del ecualizador (Hz). 10 bandas de estudio.
  static const List<double> eqBands = <double>[
    31,
    62,
    125,
    250,
    500,
    1000,
    2000,
    4000,
    8000,
    16000,
  ];

  static const double eqMinGain = -12;
  static const double eqMaxGain = 12;

  /// Rangos de velocidad de reproducción permitidos.
  static const double minSpeed = 0.5;
  static const double maxSpeed = 2.0;

  /// Claves de preferencias (tabla `settings`).
  static const String keyOnboardingDone = 'onboarding.done';
  static const String keyReplayGain = 'audio.replay_gain';
  static const String keyGapless = 'audio.gapless';
  static const String keyCrossfade = 'audio.crossfade';
  static const String keyCrossfadeMs = 'audio.crossfade_ms';
  static const String keyNormalizeVolume = 'audio.normalize';
  static const String keyVolume = 'audio.volume';
  static const String keyLastTrackId = 'player.last_track_id';
  static const String keySleepTimerDefault = 'player.sleep_timer_min';
  static const String keyEqEnabled = 'eq.enabled';
  static const String keyEqPreset = 'eq.preset';
  static const String keyAlwaysOnTop = 'window.always_on_top';
  static const String keyMiniMode = 'window.mini_mode';
  static const String keyTrayEnabled = 'window.tray_enabled';
  static const String keyAccentColor = 'theme.accent';
  static const String keyThemeConfig = 'theme.config';
  static const String keyThemeProfiles = 'theme.profiles';
  static const String keyIslandEnabled = 'island.enabled';
  static const String keyScanOnStartup = 'library.scan_on_startup';
  static const String keyLastScanAt = 'library.last_scan_at';
}
