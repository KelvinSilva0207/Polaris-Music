import 'dart:convert';

import '../constants/app_constants.dart';
import '../models/playback_state.dart';
import 'settings_service.dart';

/// Sesión de reproducción persistida entre ejecuciones.
///
/// Se guarda como un único JSON en la tabla `settings` (clave
/// [AppConstants.keyPlaybackSession]) para no añadir migraciones de Drift.
class PlaybackSession {
  const PlaybackSession({
    this.paths = const <String>[],
    this.index = -1,
    this.positionMs = 0,
    this.playing = false,
    this.shuffle = false,
    this.repeat = RepeatMode.off,
    this.playlistId,
  });

  /// Rutas de la cola, en el orden exacto en que las vio el usuario.
  final List<String> paths;
  final int index;
  final int positionMs;
  final bool playing;
  final bool shuffle;
  final RepeatMode repeat;
  final int? playlistId;

  bool get isEmpty => paths.isEmpty || index < 0;

  Map<String, Object?> toJson() => <String, Object?>{
    'paths': paths,
    'index': index,
    'positionMs': positionMs,
    'playing': playing,
    'shuffle': shuffle,
    'repeat': repeat.index,
    'playlistId': playlistId,
  };

  factory PlaybackSession.fromJson(Map<String, dynamic> json) {
    final Object? rawPaths = json['paths'];
    final List<String> paths = <String>[];
    if (rawPaths is List<dynamic>) {
      for (final dynamic path in rawPaths) {
        if (path is String && path.isNotEmpty) paths.add(path);
      }
    }
    final int index = json['index'] is int ? json['index'] as int : -1;
    final int positionMs = json['positionMs'] is int
        ? json['positionMs'] as int
        : 0;
    final Object? rawRepeat = json['repeat'];
    final RepeatMode repeat =
        rawRepeat is int &&
            rawRepeat >= 0 &&
            rawRepeat < RepeatMode.values.length
        ? RepeatMode.values[rawRepeat]
        : RepeatMode.off;
    return PlaybackSession(
      paths: List<String>.unmodifiable(paths),
      index: index,
      positionMs: positionMs < 0 ? 0 : positionMs,
      playing: json['playing'] == true,
      shuffle: json['shuffle'] == true,
      repeat: repeat,
      playlistId: json['playlistId'] is int ? json['playlistId'] as int : null,
    );
  }
}

/// Persistencia de la sesión de reproducción en `settings`.
///
/// La UI nunca habla con Drift: solo el controlador usa este servicio para
/// guardar y restaurar cola, posición, estado de transporte y playlist activa.
class PlaybackSessionService {
  PlaybackSessionService(this._settings);

  final SettingsService _settings;

  Future<void> Function()? _flush;
  Future<void> _pending = Future<void>.value();

  /// El controlador registra aquí su volcado final. `main` lo invoca justo
  /// antes de cerrar la base de datos, cuando el usuario elige «Salir».
  void registerFlush(Future<void> Function() flush) => _flush = flush;

  void unregisterFlush() => _flush = null;

  Future<void> flush() async {
    final Future<void> Function()? callback = _flush;
    if (callback != null) await callback();
  }

  PlaybackSession get current {
    final String raw = _settings.stringOr(AppConstants.keyPlaybackSession, '');
    if (raw.isEmpty) return const PlaybackSession();
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const PlaybackSession();
      return PlaybackSession.fromJson(decoded);
    } catch (_) {
      // Un JSON corrupto nunca debe impedir el arranque.
      return const PlaybackSession();
    }
  }

  /// Serializa las escrituras para que un guardado reciente no sea sobrescrito
  /// por uno anterior que todavía estaba esperando en Drift.
  Future<void> save(PlaybackSession session) {
    final String raw = jsonEncode(session.toJson());
    _pending = _pending.then(
      (_) => _settings.setString(AppConstants.keyPlaybackSession, raw),
    );
    return _pending;
  }
}
