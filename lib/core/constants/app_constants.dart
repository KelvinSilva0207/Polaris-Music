/// Constantes globales de Polaris Music.
///
/// Un único lugar para identidad de la app, extensiones soportadas y los
/// parámetros del motor de audio.
class AppConstants {
  AppConstants._();

  static const String appName = 'Polaris Music';
  static const String appVersionFallback = '1.1.1';
  static const String githubOwner = 'KelvinSilva0207';
  static const String githubRepo = 'Polaris-Music';
  static const String githubReleasesUrl =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';
  static const String githubReleasesPage =
      'https://github.com/$githubOwner/$githubRepo/releases';

  /// Nombre del archivo SQLite usado por Drift.
  static const String databaseFileName = 'polaris_music.sqlite';

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

  /// Diseños seleccionables del ecualizador gráfico (frecuencias en Hz).
  /// El diseño personalizado se construye añadiendo/quitando bandas en la UI.
  static const Map<String, List<double>> eqBandLayouts = <String, List<double>>{
    '5': <double>[60, 230, 910, 3600, 14000],
    '10': eqBands,
    '15': <double>[
      25,
      40,
      63,
      100,
      160,
      250,
      400,
      630,
      1000,
      1600,
      2500,
      4000,
      6300,
      10000,
      16000,
    ],
    '20': <double>[
      20,
      31,
      50,
      80,
      125,
      200,
      315,
      500,
      630,
      1000,
      1600,
      2000,
      3150,
      4000,
      6300,
      8000,
      10000,
      12500,
      16000,
      20000,
    ],
    '31': <double>[
      20,
      25,
      31.5,
      40,
      50,
      63,
      80,
      100,
      125,
      160,
      200,
      250,
      315,
      400,
      500,
      630,
      800,
      1000,
      1250,
      1600,
      2000,
      2500,
      3150,
      4000,
      5000,
      6300,
      8000,
      10000,
      12500,
      16000,
      20000,
    ],
  };

  static const String eqCustomLayout = 'custom';

  /// Tasa a la que se evalúan los biquads de la curva y la rama sub-armónica.
  /// Un único valor evita que el dibujo y el DSP divergean.
  static const double dspSampleRate = 48000;

  /// Margen extra reservado por el anti-clip sobre el pico estimado de la curva.
  static const double antiClipHeadroomDb = 1.0;

  /// Tope de atenuación automática: el limitador final absorbe el resto.
  static const double antiClipMaxAttenuationDb = 24.0;

  /// Límites del modo paramétrico y del sintetizador sub-armónico.
  static const int eqMaxParametricFilters = 8;
  static const double eqMinFrequency = 20;
  static const double eqMaxFrequency = 20000;
  static const double eqMinQ = 0.1;
  static const double eqMaxQ = 18;
  static const double subMinMix = 0;
  static const double subMaxMix = 0.35;
  static const double subMinCrossover = 40;
  static const double subMaxCrossover = 200;

  /// Rangos de velocidad de reproducción permitidos.
  static const double minSpeed = 0.5;
  static const double maxSpeed = 2.0;

  /// Claves de preferencias (tabla `settings`).
  static const String keyOnboardingDone = 'onboarding.done';
  static const String keyReplayGain = 'audio.replay_gain';

  /// Bypass temporal de todo el DSP: EQ, sub-armónico, preamp y limitador.
  static const String keyPureAudio = 'audio.pure';
  static const String keyGapless = 'audio.gapless';
  static const String keyCrossfade = 'audio.crossfade';
  static const String keyCrossfadeMs = 'audio.crossfade_ms';
  static const String keySilenceTrim = 'audio.trim_silence';
  static const String keySilenceTrimStartMs = 'audio.trim_start_ms';
  static const String keySilenceTrimEndMs = 'audio.trim_end_ms';
  static const String keyPerDeviceProfiles = 'eq.per_device_profiles';
  static const String keyNormalizeVolume = 'audio.normalize';
  static const String keyVolume = 'audio.volume';

  /// Nombre del `audio-device` de media_kit elegido por el usuario.
  /// `null` significa selección automática del sistema.
  static const String keyAudioOutputDevice = 'audio.output_device';
  static const String keyPauseOnHeadphonesDisconnect =
      'audio.pause_on_headphones_disconnect';
  static const String keyPauseOnVolumeZero = 'audio.pause_on_volume_zero';
  static const String keyLastTrackId = 'player.last_track_id';
  static const String keyPlaybackSession = 'player.session';
  static const String keySleepTimerDefault = 'player.sleep_timer_min';
  static const String keySleepFadeSeconds = 'player.sleep_fade_seconds';
  static const String keyEqEnabled = 'eq.enabled';
  static const String keyEqPreset = 'eq.preset';
  static const String keyEqCustomBands = 'eq.custom_bands';
  static const String keyEqCustomPreamp = 'eq.custom_preamp';

  /// Configuración completa (gráfica, paramétrica y sub-armónico). Las claves
  /// antiguas se siguen escribiendo para no romper versiones previas.
  static const String keyEqConfig = 'eq.config';
  static const String keyAlwaysOnTop = 'window.always_on_top';
  static const String keyMiniMode = 'window.mini_mode';
  static const String keyTrayEnabled = 'window.tray_enabled';
  static const String keyAccentColor = 'theme.accent';
  static const String keyThemeConfig = 'theme.config';
  static const String keyThemeProfiles = 'theme.profiles';
  static const String keyMotionConfig = 'ui.motion';
  static const String keyCompactIslandStyle = 'ui.style.island';
  static const String keyCompactMiniStyle = 'ui.style.mini';
  static const String keyCompactPhoneStyle = 'ui.style.phone';
  static const String keyCompactPlayerStyle = 'ui.style.player';
  static const String keyTypography = 'ui.typography';
  static const String keyImportedFonts = 'ui.imported_fonts';
  static const String keyIslandEnabled = 'island.enabled';
  static const String keyScanOnStartup = 'library.scan_on_startup';
  static const String keyLastScanAt = 'library.last_scan_at';
  static const String keyRecentSearches = 'library.recent_searches';
  static const String keyKaraokeEnabled = 'lyrics.karaoke';
  static const String keyScrobbleConfig = 'scrobbling.config';

  /// Carpetas visibles elegidas por el usuario. Vacío = carpeta estándar.
  static const String keyDocumentsFolder = 'storage.documents_folder';
  static const String keyMusicFolder = 'storage.music_folder';
  static const String keyDownloadsFolder = 'storage.downloads_folder';

  /// Atajos globales del escritorio (formato `ctrl+alt+space`).
  static const String keyHotkeyPlayPause = 'hotkey.play_pause';
  static const String keyHotkeyNext = 'hotkey.next';
  static const String keyHotkeyPrevious = 'hotkey.previous';

  static const String defaultHotkeyPlayPause = 'ctrl+alt+space';
  static const String defaultHotkeyNext = 'ctrl+alt+right';
  static const String defaultHotkeyPrevious = 'ctrl+alt+left';

  /// Preferencias que «Restablecer ajustes» devuelve a su valor inicial.
  ///
  /// Se excluyen deliberadamente la introducción, la sesión de reproducción,
  /// las credenciales de scrobbling, los tokens online, las fuentes importadas
  /// y los perfiles de tema guardados: son datos del usuario, no configuración
  /// de prueba. Las carpetas vuelven a las rutas estándar, pero sus archivos
  /// no se eliminan.
  static const List<String> resettablePreferenceKeys = <String>[
    keyReplayGain,
    keyPureAudio,
    keyGapless,
    keyCrossfade,
    keyCrossfadeMs,
    keySilenceTrim,
    keySilenceTrimStartMs,
    keySilenceTrimEndMs,
    keyNormalizeVolume,
    keyVolume,
    keyAudioOutputDevice,
    keyPauseOnHeadphonesDisconnect,
    keyPauseOnVolumeZero,
    keySleepTimerDefault,
    keySleepFadeSeconds,
    keyEqEnabled,
    keyEqPreset,
    keyEqCustomBands,
    keyEqCustomPreamp,
    keyEqConfig,
    keyPerDeviceProfiles,
    keyAlwaysOnTop,
    keyMiniMode,
    keyTrayEnabled,
    keyAccentColor,
    keyThemeConfig,
    keyMotionConfig,
    keyCompactIslandStyle,
    keyCompactMiniStyle,
    keyCompactPhoneStyle,
    keyCompactPlayerStyle,
    keyTypography,
    keyIslandEnabled,
    keyScanOnStartup,
    keyLastScanAt,
    keyRecentSearches,
    keyKaraokeEnabled,
    keyDocumentsFolder,
    keyMusicFolder,
    keyDownloadsFolder,
    keyHotkeyPlayPause,
    keyHotkeyNext,
    keyHotkeyPrevious,
  ];

  /// Los perfiles EQ por dispositivo viven en scopes `device:<salida>`.
  static const String resettableScopePrefix = 'device:';

  /// Logo oficial usado en la interfaz.
  static const String logoAsset = 'assets/icons/polaris_music_logo.png';
}
