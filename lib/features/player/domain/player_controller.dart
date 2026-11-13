import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/playback_state.dart';
import '../../../core/models/track.dart';
import '../../../core/services/audio_engine_service.dart';
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
  });

  final PlaybackSnapshot playback;
  final Duration? sleepRemaining;
  final bool sleepEndsAtTrack;
  final bool crossfadeEnabled;
  final int crossfadeMs;
  final bool replayGainEnabled;
  final bool gaplessEnabled;

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
    required SettingsService settings,
  }) : _engine = engine,
       _settings = settings,
       super(
         PlayerUiState(
           playback: engine.state,
           replayGainEnabled: settings.replayGainEnabled,
           gaplessEnabled: settings.gaplessEnabled,
           crossfadeEnabled: settings.crossfadeEnabled,
           crossfadeMs: settings.crossfadeMs,
         ),
       ) {
    _stateSub = _engine.states.listen(_onEngineState);
  }

  static const String _tag = 'Player';

  final AudioEngineService _engine;
  final SettingsService _settings;

  StreamSubscription<PlaybackSnapshot>? _stateSub;
  Timer? _sleepTicker;
  DateTime? _sleepDeadline;
  Timer? _sleepTimeout;

  void _onEngineState(PlaybackSnapshot snapshot) {
    if (snapshot.completed && state.sleepEndsAtTrack) {
      unawaited(_engine.pause());
      _clearSleep();
    }
    state = state.copyWith(playback: snapshot);
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
    unawaited(_settings.setInt(AppConstants.keyLastTrackId, track.id));
  }

  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    await _engine.setQueue(tracks, startIndex: startIndex);
    final Track started = tracks[startIndex.clamp(0, tracks.length - 1)];
    unawaited(_settings.setInt(AppConstants.keyLastTrackId, started.id));
  }

  Future<void> addToQueue(Track track) => _engine.addToQueue(track);

  Future<void> removeFromQueue(int index) => _engine.removeAt(index);

  Future<void> clearQueue() => _engine.clearQueue();

  Future<void> togglePlay() => _engine.playOrPause();

  Future<void> play() => _engine.play();

  Future<void> pause() => _engine.pause();

  Future<void> next() => _engine.next();

  Future<void> previous() => _engine.previous();

  Future<void> playAt(int index) => _engine.playIndex(index);

  Future<void> seek(Duration position) => _engine.seek(position);

  Future<void> seekFraction(double value) => _engine.seekToProgress(value);

  Future<void> setVolume(double percent) async {
    await _engine.setVolume(percent);
    await _settings.saveVolume(percent / 100);
  }

  Future<void> setSpeed(double speed) => _engine.setSpeed(speed);

  Future<void> toggleShuffle() => _engine.toggleShuffle();

  Future<void> cycleRepeat() => _engine.cycleRepeat();

  Future<void> setRepeat(RepeatMode mode) => _engine.setRepeat(mode);

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
    _sleepTicker?.cancel();
    _sleepTimeout?.cancel();
    super.dispose();
  }
}
