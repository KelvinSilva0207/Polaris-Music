// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:math' as math;

import '../database/app_database.dart';
import '../models/playback_state.dart';
import '../models/track.dart';
import '../utils/logger.dart';
import 'audio_engine_service.dart';
import 'scrobble_service.dart';
import 'widget_bridge_service.dart';

/// Escucha el motor y persiste historial + contadores de reproducción.
///
/// Reglas:
/// - Cada cambio de pista cierra la entrada anterior y abre una nueva.
/// - Una reproducción cuenta para `playCount` si se escuchó al menos el 50 %
///   de la pista o 30 s (lo que sea menor); así los skips rápidos no inflan
///   las estadísticas.
class PlaybackStatsRecorder {
  PlaybackStatsRecorder({
    required AudioEngineService engine,
    required AppDatabase database,
    ScrobbleService? scrobbler,
    WidgetBridgeService? widgetBridge,
  }) : _engine = engine,
       _historyDao = database.historyDao,
       _trackDao = database.trackDao,
       _scrobbler = scrobbler,
       _widgetBridge = widgetBridge;

  static const String _tag = 'StatsRecorder';

  final AudioEngineService _engine;
  final HistoryDao _historyDao;
  final TrackDao _trackDao;
  final ScrobbleService? _scrobbler;
  final WidgetBridgeService? _widgetBridge;

  StreamSubscription<PlaybackSnapshot>? _subscription;
  Track? _track;
  int? _historyId;
  Duration _lastPosition = Duration.zero;
  DateTime _startedAt = DateTime.now();
  bool _lastWidgetPlaying = false;
  int? _widgetTrackId;

  void start() {
    _subscription ??= _engine.states.listen(_onState);
  }

  void _onState(PlaybackSnapshot snapshot) {
    final Track? track = snapshot.currentTrack;
    final WidgetBridgeService? widgetBridge = _widgetBridge;
    final bool canUpdateWidget =
        widgetBridge != null && widgetBridge.isAvailable;

    if (track == null) {
      // Al vaciar la cola el widget debe volver al estado de espera; sin esto
      // conservaba el último título y el icono en "pausa" de forma indefinida.
      if (canUpdateWidget && (_widgetTrackId != null || _lastWidgetPlaying)) {
        _widgetTrackId = null;
        _lastWidgetPlaying = false;
        unawaited(widgetBridge.clear());
      }
      return;
    }

    // El widget se actualiza también con pistas de streaming y al pausar.
    if (canUpdateWidget) {
      final bool wasPlaying = _lastWidgetPlaying;
      _lastWidgetPlaying = snapshot.playing;
      if (wasPlaying != snapshot.playing || _widgetTrackId != track.id) {
        _widgetTrackId = track.id;
        unawaited(widgetBridge.update(track, playing: snapshot.playing));
      }
    }

    if (!track.isPersisted) {
      // El streaming no se persiste: se cierra la escucha local anterior y no
      // se abre una fila de historial (rompería la clave foránea).
      unawaited(_finish(completed: snapshot.completed));
      _lastPosition = Duration.zero;
      return;
    }

    if (_track?.id != track.id) {
      unawaited(_finish(completed: snapshot.completed));
      unawaited(_begin(track));
      _lastPosition = Duration.zero;
      return;
    }

    _lastPosition = snapshot.position;
    if (snapshot.completed) {
      unawaited(_finish(completed: true));
    }
  }

  Future<void> _begin(Track track) async {
    _track = track;
    _lastPosition = Duration.zero;
    _startedAt = DateTime.now();
    try {
      _historyId = await _historyDao.startPlay(track.id);
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo abrir historial', error, stack);
    }
  }

  Future<void> _finish({required bool completed}) async {
    final int? historyId = _historyId;
    final Track? track = _track;
    final Duration position = _lastPosition;
    final DateTime startedAt = _startedAt;
    _historyId = null;
    _track = null;

    if (historyId == null || track == null) return;
    if (position <= Duration.zero) {
      // Nunca llegó a sonar: no cuenta como escucha, pero se conserva la fila.
      return;
    }

    final int msPlayed = position.inMilliseconds;
    final int threshold = math.min(30000, (track.durationMs * 0.5).round());
    final bool counts = completed || msPlayed >= threshold;

    try {
      await _historyDao.finishPlay(
        historyId,
        msPlayed: msPlayed,
        completed:
            completed ||
            (track.durationMs > 0 && msPlayed >= track.durationMs * 0.9),
      );
      if (counts) {
        await _trackDao.registerPlay(track.id, completed: completed);
        await _scrobble(track, startedAt);
      }
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo cerrar historial', error, stack);
    }
  }

  /// El scrobbling es best-effort: un fallo de red nunca afecta al historial.
  Future<void> _scrobble(Track track, DateTime startedAt) async {
    final ScrobbleService? scrobbler = _scrobbler;
    if (scrobbler == null || !scrobbler.isReady) return;
    try {
      await scrobbler.scrobble(track, listenedAt: startedAt);
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo enviar el scrobble', error, stack);
    }
  }

  Future<void> dispose() async {
    await _finish(completed: false);
    await _subscription?.cancel();
    _subscription = null;
  }
}
