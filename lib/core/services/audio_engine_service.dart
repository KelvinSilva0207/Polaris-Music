import 'dart:async';

import 'package:media_kit/media_kit.dart' hide Track;

import '../models/playback_state.dart';
import '../models/track.dart';
import '../utils/logger.dart';
import '../utils/replay_gain.dart';

/// Motor de reproducción basado en media_kit (libmpv).
///
/// Es el único punto que conoce media_kit. La UI consume [states] y el resto de
/// servicios (sesión de medios, estadísticas, letras) escuchan el mismo stream.
///
/// Decisiones de Fase 1:
/// - Gapless real: delegado a la lista de reproducción de mpv.
/// - Repetición y aleatorio: delegados a mpv (`PlaylistMode` / `shuffle`).
/// - ReplayGain: se aplica sobre el volumen efectivo (no altera el volumen
///   elegido por el usuario).
/// - Crossfade: requiere dos decks simultáneos; se expone el ajuste y se
///   implementará en Fase 2 (ver README).
class AudioEngineService {
  AudioEngineService({Player? player}) : _player = player ?? Player();

  static const String _tag = 'AudioEngine';

  final Player _player;
  final StreamController<PlaybackSnapshot> _states =
      StreamController<PlaybackSnapshot>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  PlaybackSnapshot _state = const PlaybackSnapshot();
  double _baseVolume = 1.0;
  bool _replayGainEnabled = true;
  int _openEpoch = 0;
  bool _initialized = false;

  PlaybackSnapshot get state => _state;
  Stream<PlaybackSnapshot> get states => _states.stream;
  Stream<Duration> get positionStream => _player.stream.position;
  Stream<bool> get playingStream => _player.stream.playing;
  Stream<String> get errorStream => _player.stream.error;

  /// Acceso de bajo nivel para DSP/ecualizador (Fase 2).
  Player get player => _player;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _player.setVolume(100);
    await _player.setRate(1);

    _subscriptions.addAll(<StreamSubscription<dynamic>>[
      _player.stream.playlist.listen(_onPlaylistChanged),
      _player.stream.playing.listen(
        (bool value) => _emit(_state.copyWith(playing: value)),
      ),
      _player.stream.position.listen(
        (Duration value) => _emit(_state.copyWith(position: value)),
      ),
      _player.stream.duration.listen(
        (Duration value) => _emit(_state.copyWith(duration: value)),
      ),
      _player.stream.buffering.listen(
        (bool value) => _emit(_state.copyWith(buffering: value)),
      ),
      _player.stream.completed.listen((bool value) {
        if (value) {
          _emit(_state.copyWith(playing: false, completed: true));
        }
      }),
      _player.stream.error.listen((String message) {
        AppLog.e(_tag, message);
        _emit(_state.copyWith(error: message));
      }),
    ]);

    AppLog.i(_tag, 'Motor inicializado (${_player.platform.runtimeType})');
  }

  void _onPlaylistChanged(Playlist playlist) {
    final int index = playlist.index;
    final List<Track> queue = _state.queue;
    final Track? track = index >= 0 && index < queue.length
        ? queue[index]
        : _state.currentTrack;

    final bool trackChanged =
        track != null && track.id != _state.currentTrack?.id;

    _emit(
      _state.copyWith(
        index: index < 0 ? _state.index : index,
        currentTrack: track,
        duration: trackChanged ? track.duration : _state.duration,
        position: trackChanged ? Duration.zero : _state.position,
        completed: trackChanged ? false : _state.completed,
        error: trackChanged ? null : _state.error,
      ),
    );

    if (trackChanged) {
      AppLog.i(_tag, 'Pista actual: ${track.artist} - ${track.title}');
      unawaited(_applyVolume());
    }
  }

  /// Carga una cola y opcionalmente empieza a reproducir.
  ///
  /// [startIndex] es el índice dentro de [tracks] (orden de la cola).
  Future<void> setQueue(
    List<Track> tracks, {
    int startIndex = 0,
    bool autoPlay = true,
  }) async {
    if (tracks.isEmpty) {
      await clearQueue();
      return;
    }

    final int index = startIndex.clamp(0, tracks.length - 1);
    _state = _state.copyWith(
      queue: List<Track>.unmodifiable(tracks),
      index: index,
      currentTrack: tracks[index],
      position: Duration.zero,
      duration: tracks[index].duration,
      completed: false,
      error: null,
    );
    _emit(_state);

    await _open(autoPlay: autoPlay);
    await _applyVolume();
  }

  Future<void> _open({required bool autoPlay}) async {
    final int epoch = ++_openEpoch;
    final List<Media> medias = _state.queue
        .map((Track track) => Media(track.path))
        .toList(growable: false);

    if (medias.isEmpty) return;

    try {
      await _player.open(
        Playlist(medias, index: _state.index.clamp(0, medias.length - 1)),
        play: autoPlay,
      );
      if (epoch != _openEpoch) return;
      await _applyPlaylistMode();
      await _player.setShuffle(_state.shuffle);
    } catch (error, stack) {
      AppLog.e(_tag, 'No se pudo abrir la cola', error, stack);
      _emit(_state.copyWith(error: 'No se pudo abrir la pista: $error'));
    }
  }

  Future<void> _applyPlaylistMode() async {
    final PlaylistMode mode = switch (_state.repeat) {
      RepeatMode.one => PlaylistMode.single,
      RepeatMode.all => PlaylistMode.loop,
      RepeatMode.off => PlaylistMode.none,
    };
    await _player.setPlaylistMode(mode);
  }

  Future<void> addToQueue(Track track) async {
    if (_state.queue.isEmpty) {
      await setQueue(<Track>[track]);
      return;
    }
    final List<Track> queue = <Track>[..._state.queue, track];
    _emit(_state.copyWith(queue: List<Track>.unmodifiable(queue)));
    await _player.add(Media(track.path));
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _state.queue.length) return;
    final List<Track> queue = <Track>[..._state.queue]..removeAt(index);
    _emit(
      _state.copyWith(
        queue: List<Track>.unmodifiable(queue),
        index: index < _state.index ? _state.index - 1 : _state.index,
        currentTrack: index == _state.index
            ? (queue.isEmpty ? null : queue[index.clamp(0, queue.length - 1)])
            : _state.currentTrack,
      ),
    );
    await _player.remove(index);
  }

  Future<void> clearQueue() async {
    _state = const PlaybackSnapshot(volume: 100);
    _emit(_state);
    await _player.stop();
  }

  /// Reproduce una pista de la cola (o abre una nueva cola de una sola pista).
  Future<void> playTrack(Track track) async {
    final int index = _state.queue.indexWhere((Track t) => t.id == track.id);
    if (index >= 0) {
      await playIndex(index);
    } else {
      await setQueue(<Track>[track]);
    }
  }

  Future<void> playIndex(int index) async {
    if (index < 0 || index >= _state.queue.length) return;
    _state = _state.copyWith(index: index, currentTrack: _state.queue[index]);
    _emit(_state);
    await _player.jump(index);
    await _player.play();
  }

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> playOrPause() => _player.playOrPause();

  Future<void> stop() => _player.stop();

  Future<void> next() async {
    if (!_state.hasQueue) return;
    await _player.next();
  }

  Future<void> previous() async {
    if (!_state.hasQueue) return;
    // Comportamiento estándar: si llevamos más de 4 s, reinicia la pista.
    if (_state.position > const Duration(seconds: 4)) {
      await _player.seek(Duration.zero);
      return;
    }
    await _player.previous();
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> seekToProgress(double progress) {
    final int ms = (progress.clamp(0.0, 1.0) * _state.duration.inMilliseconds)
        .round();
    return seek(Duration(milliseconds: ms));
  }

  Future<void> setVolume(double percent) async {
    _baseVolume = (percent.clamp(0, 100)) / 100;
    await _applyVolume();
  }

  Future<void> _applyVolume() async {
    final double? gainDb = ReplayGain.preferred(
      trackGainDb: _state.currentTrack?.replayGainTrackDb,
      albumGainDb: _state.currentTrack?.replayGainAlbumDb,
    );
    final double effective = _replayGainEnabled
        ? ReplayGain.effectiveVolume(baseVolume: _baseVolume, gainDb: gainDb)
        : _baseVolume * 100;

    await _player.setVolume(effective);
    _emit(_state.copyWith(volume: effective));
  }

  Future<void> setReplayGainEnabled(bool enabled) async {
    _replayGainEnabled = enabled;
    await _applyVolume();
  }

  Future<void> setSpeed(double speed) async {
    final double value = speed.clamp(0.5, 2.0);
    await _player.setRate(value);
    _emit(_state.copyWith(speed: value));
  }

  /// Cambia el tono sin alterar la velocidad (mpv `pitch`).
  Future<void> setPitch(double pitch) => _player.setPitch(pitch);

  Future<void> toggleShuffle() async {
    await setShuffle(!_state.shuffle);
  }

  Future<void> setShuffle(bool value) async {
    _emit(_state.copyWith(shuffle: value));
    await _player.setShuffle(value);
  }

  Future<void> cycleRepeat() async {
    await setRepeat(_state.repeat.next);
  }

  Future<void> setRepeat(RepeatMode mode) async {
    _emit(_state.copyWith(repeat: mode));
    await _applyPlaylistMode();
  }

  void _emit(PlaybackSnapshot snapshot) {
    _state = snapshot;
    if (!_states.isClosed) {
      _states.add(snapshot);
    }
  }

  Future<void> dispose() async {
    for (final StreamSubscription<dynamic> sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _states.close();
    await _player.dispose();
  }
}
