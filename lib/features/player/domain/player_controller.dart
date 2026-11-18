import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/playback_state.dart';
import '../../../core/models/track.dart';
import '../../../core/services/audio_engine_service.dart';
import '../../../core/services/playback_session_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/utils/logger.dart';

/// Estado que consume la UI del reproductor.
///
/// Envuelve el [PlaybackSnapshot] del motor (única fuente de verdad) y añade
/// estado de interfaz: temporizador de sueño y ajustes de audio.
@immutable
class PlayerUiState {
  const PlayerUiState({
    this.playback = const PlaybackSnapshot(),
    this.sleepRemaining,
    this.sleepEndsAtTrack = false,
    this.crossfadeEnabled = false,
    this.crossfadeMs = 3000,
    this.replayGainEnabled = true,
    this.gaplessEnabled = true,
    this.activePlaylistId,
  });

  final PlaybackSnapshot playback;
  final Duration? sleepRemaining;
  final bool sleepEndsAtTrack;
  final bool crossfadeEnabled;
  final int crossfadeMs;
  final bool replayGainEnabled;
  final bool gaplessEnabled;

  /// Playlist que originó la cola actual, si la hubo. Se persiste con la sesión.
  final int? activePlaylistId;

  Track? get track => playback.currentTrack;
  bool get hasTrack => playback.hasTrack;
  bool get playing => playback.playing;
  bool get hasNext => playback.hasNext;

  PlayerUiState copyWith({
    PlaybackSnapshot? playback,
    Object? sleepRemaining = _unset,
    bool? sleepEndsAtTrack,
    bool? crossfadeEnabled,
    int? crossfadeMs,
    bool? replayGainEnabled,
    bool? gaplessEnabled,
    Object? activePlaylistId = _unset,
  }) => PlayerUiState(
    playback: playback ?? this.playback,
    sleepRemaining: identical(sleepRemaining, _unset)
        ? this.sleepRemaining
        : sleepRemaining as Duration?,
    sleepEndsAtTrack: sleepEndsAtTrack ?? this.sleepEndsAtTrack,
    crossfadeEnabled: crossfadeEnabled ?? this.crossfadeEnabled,
    crossfadeMs: crossfadeMs ?? this.crossfadeMs,
    replayGainEnabled: replayGainEnabled ?? this.replayGainEnabled,
    gaplessEnabled: gaplessEnabled ?? this.gaplessEnabled,
    activePlaylistId: identical(activePlaylistId, _unset)
        ? this.activePlaylistId
        : activePlaylistId as int?,
  );
}

const Object _unset = Object();

/// Controlador de reproducción para Riverpod.
///
/// La UI solo llama a estos métodos; el motor (`media_kit`) queda encapsulado
/// en [AudioEngineService].
class PlayerController extends StateNotifier<PlayerUiState> {
  PlayerController({
    required AudioEngineService engine,
    required this._settings,
    required this._session,
    this._resolveTracks,
    this._persistFavorite,
    this.isBackgrounded,
  }) : _engine = engine,
       super(
         PlayerUiState(
           playback: engine.state,
           replayGainEnabled: _settings.replayGainEnabled,
           gaplessEnabled: _settings.gaplessEnabled,
           crossfadeEnabled: _settings.crossfadeEnabled,
           crossfadeMs: _settings.crossfadeMs,
         ),
       ) {
    _stateSub = _engine.states.listen(_onEngineState);
    _session.registerFlush(_saveSession);
    // Guardado periódico: captura la posición aunque la app se cierre de forma
    // brusca. Los cambios de pista/transporte se vuelcan además al instante.
    _sessionTimer = Timer.periodic(const Duration(seconds: 3), (Timer _) {
      _sessionTicks++;
      // En segundo plano bajamos de 20 a 2 escrituras de Drift por minuto.
      // Los cambios de pista y transporte ya vuelcan al instante.
      if ((isBackgrounded?.call() ?? false) && _sessionTicks % 10 != 0) {
        return;
      }
      unawaited(_saveSession());
    });
  }

  static const String _tag = 'Player';

  final AudioEngineService _engine;
  final SettingsService _settings;
  final PlaybackSessionService _session;

  /// Resuelve las rutas guardadas a pistas de la biblioteca. Lo inyecta la capa
  /// de presentación para que el dominio no conozca Drift.
  final Future<List<Track>> Function(List<String> paths)? _resolveTracks;
  final Future<void> Function(int id, bool value)? _persistFavorite;

  /// Inyectado por la capa de presentación para espaciar el guardado en
  /// segundo plano. Nunca controla `play()`/`pause()`.
  final bool Function()? isBackgrounded;

  StreamSubscription<PlaybackSnapshot>? _stateSub;
  int _sessionTicks = 0;
  Timer? _sessionTimer;
  Timer? _sleepTicker;
  DateTime? _sleepDeadline;
  Timer? _sleepTimeout;
  Timer? _volumeSaveTimer;
  double? _pendingVolume;

  void _onEngineState(PlaybackSnapshot snapshot) {
    if (snapshot.completed && state.sleepEndsAtTrack) {
      unawaited(_engine.pause());
      _clearSleep();
    }
    final PlaybackSnapshot previous = state.playback;
    state = state.copyWith(playback: snapshot);
    // La posición cambia cada segundo: no la escribimos en SQLite cada vez.
    // Sí volcamos al instante cualquier cambio estructural de la sesión.
    if (previous.currentTrack?.id != snapshot.currentTrack?.id ||
        previous.playing != snapshot.playing ||
        previous.shuffle != snapshot.shuffle ||
        previous.repeat != snapshot.repeat ||
        previous.queue.length != snapshot.queue.length) {
      unawaited(_saveSession());
    }
  }

  // ---------------------------------------------------------------------------
  // Cola y transporte
  // ---------------------------------------------------------------------------

  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    if (queue != null && queue.isNotEmpty) {
      final int index = queue.indexWhere((Track t) => t.id == track.id);
      await _engine.setQueue(queue, startIndex: index < 0 ? 0 : index);
    } else {
      await _engine.playTrack(track);
    }
    if (track.isPersisted) {
      unawaited(_settings.setInt(AppConstants.keyLastTrackId, track.id));
    }
  }

  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    await _engine.setQueue(tracks, startIndex: startIndex);
    final Track started = tracks[startIndex.clamp(0, tracks.length - 1)];
    if (started.isPersisted) {
      unawaited(_settings.setInt(AppConstants.keyLastTrackId, started.id));
    }
  }

  Future<void> addToQueue(Track track) => _engine.addToQueue(track);

  Future<void> removeFromQueue(int index) => _engine.removeAt(index);

  Future<void> clearQueue() async {
    await _engine.clearQueue();
    // Cola vacía intencional: no debe reaparecer al reiniciar.
    await _session.save(const PlaybackSession());
  }

  Future<void> togglePlay() => _engine.playOrPause();

  Future<void> play() => _engine.play();

  Future<void> pause() async {
    await _engine.pause();
    await _saveSession();
  }

  Future<void> next() => _engine.next();

  Future<void> previous() => _engine.previous();

  Future<void> playAt(int index) => _engine.playIndex(index);

  Future<void> seek(Duration position) async {
    await _engine.seek(position);
    await _saveSession();
  }

  Future<void> seekFraction(double value) => _engine.seekToProgress(value);

  Future<void> setVolume(double percent) async {
    await _engine.setVolume(percent);
    // Arrastrar el deslizador dispara decenas de eventos por segundo; la
    // escritura en SQLite se agrupa para no castigar el disco.
    _pendingVolume = percent / 100;
    _volumeSaveTimer?.cancel();
    _volumeSaveTimer = Timer(const Duration(milliseconds: 400), () {
      final double? value = _pendingVolume;
      _pendingVolume = null;
      if (value != null) unawaited(_settings.saveVolume(value));
    });
  }

  /// Actualiza el corazón de favoritos de forma inmediata en la UI.
  ///
  /// El motor refleja el cambio en la cola al instante y la persistencia en
  /// Drift se delega en `LibraryRepository` a través del callback inyectado.
  Future<void> setFavorite(bool value) async {
    final Track? track = state.track;
    if (track == null) return;
    _engine.updateFavorite(track.id, value);
    await _persistFavorite?.call(track.id, value);
  }

  Future<void> setSpeed(double speed) => _engine.setSpeed(speed);

  Future<void> toggleShuffle() => _engine.toggleShuffle();

  Future<void> cycleRepeat() => _engine.cycleRepeat();

  Future<void> setRepeat(RepeatMode mode) => _engine.setRepeat(mode);

  // ---------------------------------------------------------------------------
  // Sesión persistida
  // ---------------------------------------------------------------------------

  /// Marca la playlist que originó la cola actual y la incluye en la sesión.
  void setActivePlaylist(int? id) {
    state = state.copyWith(activePlaylistId: id);
    unawaited(_saveSession());
  }

  /// Restaura la última sesión al arrancar: cola, índice, posición exacta,
  /// reproducción, aleatorio, repetición y playlist activa.
  Future<void> restoreSession() async {
    final PlaybackSession session = _session.current;
    if (session.isEmpty || _resolveTracks == null || !mounted) return;
    final List<Track> tracks = await _resolveTracks(session.paths);
    if (tracks.isEmpty || !mounted) return;

    final int start = session.index.clamp(0, tracks.length - 1);
    await _engine.setQueue(
      tracks,
      startIndex: start,
      autoPlay: session.playing,
    );
    await _engine.setShuffle(session.shuffle);
    await _engine.setRepeat(session.repeat);
    if (session.positionMs > 0) {
      await _engine.seek(Duration(milliseconds: session.positionMs));
    }
    if (!mounted) return;
    state = state.copyWith(
      playback: _engine.state,
      activePlaylistId: session.playlistId,
    );
    await _saveSession();
    AppLog.i(
      _tag,
      'Sesión restaurada: ${tracks.length} pistas, índice $start, '
      '${session.positionMs} ms',
    );
  }

  /// Vuelca el estado actual a `settings`.
  Future<void> _saveSession() async {
    final PlaybackSnapshot playback = state.playback;
    // Nunca sobrescribimos una sesión guardada con el estado vacío del arranque.
    if (!playback.hasTrack && state.activePlaylistId == null) return;
    await _session.save(
      PlaybackSession(
        paths: playback.queue
            .map((Track track) => track.path)
            .toList(growable: false),
        index: playback.index,
        positionMs: playback.position.inMilliseconds,
        playing: playback.playing,
        shuffle: playback.shuffle,
        repeat: playback.repeat,
        playlistId: state.activePlaylistId,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Ajustes de audio
  // ---------------------------------------------------------------------------

  Future<void> setReplayGainEnabled(bool value) async {
    await _engine.setReplayGainEnabled(value);
    await _settings.setBool(AppConstants.keyReplayGain, value);
    state = state.copyWith(replayGainEnabled: value);
  }

  Future<void> setGaplessEnabled(bool value) async {
    // El gapless real lo hace mpv al reproducir la lista; el ajuste documenta
    // la intención y desactiva el modo de lista cuando el usuario lo pide.
    await _settings.setBool(AppConstants.keyGapless, value);
    state = state.copyWith(gaplessEnabled: value);
  }

  /// Fase 1: se persiste el ajuste. El crossfade real necesita dos decks
  /// simultáneos y se implementará en Fase 2 (ver README).
  Future<void> setCrossfade({required bool enabled, int? ms}) async {
    final int duration = (ms ?? state.crossfadeMs).clamp(0, 12000);
    await _settings.setBool(AppConstants.keyCrossfade, enabled);
    await _settings.setInt(AppConstants.keyCrossfadeMs, duration);
    state = state.copyWith(crossfadeEnabled: enabled, crossfadeMs: duration);
    AppLog.i(
      _tag,
      'Crossfade ${enabled ? 'activado' : 'desactivado'} '
      '($duration ms, pendiente de DSP en Fase 2)',
    );
  }

  // ---------------------------------------------------------------------------
  // Temporizador de sueño
  // ---------------------------------------------------------------------------

  void startSleepTimer(Duration duration) {
    _clearSleep();
    _sleepDeadline = DateTime.now().add(duration);
    state = state.copyWith(sleepRemaining: duration, sleepEndsAtTrack: false);
    _sleepTimeout = Timer(duration, () {
      unawaited(_engine.pause());
      _clearSleep();
    });
    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      final DateTime? deadline = _sleepDeadline;
      if (deadline == null) return;
      final Duration remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        _clearSleep();
        return;
      }
      state = state.copyWith(sleepRemaining: remaining);
    });
  }

  void sleepAtEndOfTrack() {
    _clearSleep();
    state = state.copyWith(sleepRemaining: null, sleepEndsAtTrack: true);
  }

  void cancelSleepTimer() => _clearSleep();

  void _clearSleep() {
    _sleepTicker?.cancel();
    _sleepTicker = null;
    _sleepTimeout?.cancel();
    _sleepTimeout = null;
    _sleepDeadline = null;
    if (mounted) {
      state = state.copyWith(sleepRemaining: null, sleepEndsAtTrack: false);
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _sessionTimer?.cancel();
    _sleepTicker?.cancel();
    _sleepTimeout?.cancel();
    _volumeSaveTimer?.cancel();
    final double? pending = _pendingVolume;
    if (pending != null) unawaited(_settings.saveVolume(pending));
    unawaited(_saveSession());
    _session.unregisterFlush();
    super.dispose();
  }
}
