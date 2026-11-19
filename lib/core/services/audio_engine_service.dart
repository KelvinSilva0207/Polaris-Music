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
/// - Crossfade real: dos decks mpv. El principal sigue alimentando [states] y
///   el handler protegido `_onPlaylistChanged`; el entrante se mantiene fuera de
///   la UI hasta el relevo.
/// - Recorte de silencios: offsets `start`/`end` de `Media` (mpv), sin tocar la
///   cadena `af` del ecualizador.
class AudioEngineService {
  AudioEngineService({Player? player, this.isBackgrounded})
    : _player = player ?? Player();

  static const String _tag = 'AudioEngine';

  /// Lo inyecta el DI para saber si la UI está en segundo plano. Nunca se usa
  /// para pausar la reproducción: solo reduce la frecuencia de eventos de UI.
  final bool Function()? isBackgrounded;

  /// Deck principal. No es `final` porque al terminar un crossfade se intercambia
  /// con el deck entrante; el handler `_onPlaylistChanged` no se modifica.
  Player _player;

  /// Segundo deck (mpv) usado únicamente para la pista entrante durante un
  /// crossfade. Se crea de forma perezosa y se reutiliza en el siguiente.
  Player? _fadePlayer;
  Timer? _crossfadeTimer;
  StreamSubscription<Duration>? _crossfadePositionSub;
  bool _crossfading = false;
  int _crossfadeMs = 0;
  double _crossfadeGain = 1;

  /// Offsets de recorte de silencio aplicados a cada `Media` (0 = desactivado).
  Duration _trimStart = Duration.zero;
  Duration _trimEnd = Duration.zero;

  final StreamController<PlaybackSnapshot> _states =
      StreamController<PlaybackSnapshot>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  PlaybackSnapshot _state = const PlaybackSnapshot(volume: 50);
  double _baseVolume = 0.5;

  /// Multiplicador temporal aplicado por el temporizador de sueño.
  ///
  /// No altera [_baseVolume]: al cancelar el temporizador el volumen del usuario
  /// se recupera exactamente como estaba.
  double _fadeFactor = 1;
  bool _replayGainEnabled = true;
  int _openEpoch = 0;
  bool _initialized = false;
  String _lastAudioFilter = '';
  DateTime _lastPositionEmit = DateTime.fromMillisecondsSinceEpoch(0);

  PlaybackSnapshot get state => _state;
  Stream<PlaybackSnapshot> get states => _states.stream;
  Stream<Duration> get positionStream => _player.stream.position;
  Stream<bool> get playingStream => _player.stream.playing;
  Stream<String> get errorStream => _player.stream.error;

  /// Acceso de bajo nivel para DSP/ecualizador.
  Player get player => _player;

  /// `true` cuando libmpv está disponible y acepta filtros de audio.
  ///
  /// En Windows y Android `media_kit` usa [NativePlayer]; en web no hay DSP.
  bool get dspAvailable => _player.platform is NativePlayer;

  /// Aplica la cadena de filtros de audio (`af`) o la limpia con `''`.
  ///
  /// La cadena la construye `EqualizerDsp`; aquí solo se habla con libmpv.
  /// Si mpv rechaza una cadena (por ejemplo, un filtro no disponible en su
  /// build de FFmpeg), se restaura la última cadena válida para no interrumpir
  /// la reproducción.
  Future<void> setAudioFilter(String filter) async {
    final PlatformPlayer? platform = _player.platform;
    if (platform is! NativePlayer) return;
    final String previous = _lastAudioFilter;
    if (filter == previous) return;

    try {
      await platform.setProperty('af', filter);

      String? applied;
      try {
        applied = (await platform.getProperty('af')).toString();
      } catch (_) {
        // Algunas versiones de mpv no exponen la lectura antes del primer
        // archivo; en ese caso confiamos en setProperty.
        applied = null;
      }
      if (applied != null && !_filterWasApplied(filter, applied)) {
        await platform.setProperty('af', previous);
        AppLog.w(_tag, 'libmpv rechazó la cadena DSP; se restauró la anterior');
        return;
      }

      _lastAudioFilter = filter;
      // El deck entrante debe llevar la misma cadena cuando el relevo ocurra
      // mientras el usuario está ajustando el ecualizador.
      final PlatformPlayer? fadePlatform = _fadePlayer?.platform;
      if (fadePlatform is NativePlayer && filter.isNotEmpty) {
        try {
          await fadePlatform.setProperty('af', filter);
        } catch (_) {
          // Si falla, se reintentará al abrir el siguiente crossfade.
        }
      }
      AppLog.i(_tag, filter.isEmpty ? 'DSP desactivado' : 'DSP: $filter');
    } catch (error, stack) {
      try {
        await platform.setProperty('af', previous);
      } catch (_) {
        // Nada más que hacer: el reproductor sigue con su cadena anterior.
      }
      AppLog.w(_tag, 'No se pudo aplicar el filtro de audio', error, stack);
    }
  }

  /// Comprobación conservadora: solo descarta un cambio claramente perdido.
  static bool _filterWasApplied(String requested, String applied) {
    if (requested.trim().isEmpty) return applied.trim().isEmpty;
    if (applied.trim().isEmpty) return false;
    if (requested.contains('lavfi=') && !applied.contains('lavfi')) {
      return false;
    }
    return true;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _player.setVolume(50);
    await _player.setRate(1);

    _bindPlayer();

    AppLog.i(_tag, 'Motor inicializado (${_player.platform.runtimeType})');
  }

  /// Suscribe el deck principal a los streams de estado.
  ///
  /// Se llama también tras el relevo de crossfade para que el nuevo deck
  /// alimente exactamente los mismos handlers (incluido `_onPlaylistChanged`).
  void _bindPlayer() {
    _subscriptions.addAll(<StreamSubscription<dynamic>>[
      _player.stream.playlist.listen(_onPlaylistChanged),
      _player.stream.playing.listen(
        (bool value) => _emit(_state.copyWith(playing: value)),
      ),
      _player.stream.position.listen(_onPositionChanged),
      _crossfadePositionSub = _player.stream.position.listen(
        _onCrossfadePosition,
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
  }

  /// La UI solo necesita ~5 posiciones por segundo para animar con suavidad
  /// (1 por segundo cuando está en segundo plano).
  ///
  /// libmpv puede entregar decenas por segundo; filtrarlas aquí evita que toda
  /// la app (isla, estadísticas, barra mini) se reconstruya de más. El audio lo
  /// decide libmpv, así que este filtro nunca interrumpe la reproducción.
  void _onPositionChanged(Duration value) {
    final DateTime now = DateTime.now();
    final Duration interval = (isBackgrounded?.call() ?? false)
        ? const Duration(milliseconds: 1000)
        : const Duration(milliseconds: 200);
    if (now.difference(_lastPositionEmit) < interval) return;
    _lastPositionEmit = now;
    // Con recorte activo la UI trabaja en coordenadas "útiles" (0 = justo tras
    // el silencio inicial), mientras mpv informa del tiempo absoluto del archivo.
    final Duration effective = _toEffectivePosition(value);
    final Duration useful = _effectiveDuration(_state.currentTrack);
    if (useful > Duration.zero && _state.duration != useful) {
      _emit(_state.copyWith(duration: useful, position: effective));
      return;
    }
    _emit(_state.copyWith(position: effective));
  }

  /// Refleja el estado de favorito en la cola y en la pista actual.
  ///
  /// La persistencia vive en `LibraryRepository`; este método mantiene la
  /// instantánea que consume la UI en sintonía para que el corazón cambie al
  /// instante sin esperar al siguiente evento del motor.
  void updateFavorite(int trackId, bool value) {
    final Track? current = _state.currentTrack;
    if (current != null &&
        current.id == trackId &&
        current.isFavorite != value) {
      _state = _state.copyWith(
        currentTrack: current.copyWith(isFavorite: value),
      );
    }

    bool queueChanged = false;
    final List<Track> queue = _state.queue
        .map((Track track) {
          if (track.id == trackId && track.isFavorite != value) {
            queueChanged = true;
            return track.copyWith(isFavorite: value);
          }
          return track;
        })
        .toList(growable: false);

    if (queueChanged) {
      _state = _state.copyWith(
        queue: List<Track>.unmodifiable(queue),
        currentTrack: _state.currentTrack,
      );
    }
    _emit(_state);
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

    await _cancelCrossfade();
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

  /// Construye un `Media` aplicando los offsets de recorte configurados.
  ///
  /// `media_kit` traduce `start`/`end` a las propiedades `start`/`end` de mpv,
  /// por lo que no se añade ningún filtro a la cadena `af` del ecualizador.
  Media _mediaFor(Track track) {
    if (_trimStart <= Duration.zero && _trimEnd <= Duration.zero) {
      return Media(track.path);
    }
    final Duration end = track.duration - _trimEnd;
    return Media(
      track.path,
      start: _trimStart > Duration.zero ? _trimStart : null,
      end: end > _trimStart ? end : null,
    );
  }

  /// Traduce el `time-pos` absoluto de mpv a la posición útil que ve la UI.
  Duration _toEffectivePosition(Duration absolute) =>
      absolute > _trimStart ? absolute - _trimStart : Duration.zero;

  /// Duración real que el usuario oye tras recortar silencios.
  Duration _effectiveDuration(Track? track) {
    if (track == null) return Duration.zero;
    final Duration cut = _trimStart + _trimEnd;
    return cut >= track.duration ? Duration.zero : track.duration - cut;
  }

  /// Volumen que el usuario ha elegido tras ReplayGain y el fundido de sueño.
  ///
  /// El crossfade se aplica como multiplicador adicional sobre este valor, de
  /// modo que ambos fundidos pueden coexistir sin pisarse.
  double _currentEffectiveVolume() {
    final double? gainDb = ReplayGain.preferred(
      trackGainDb: _state.currentTrack?.replayGainTrackDb,
      albumGainDb: _state.currentTrack?.replayGainAlbumDb,
    );
    final double base = _replayGainEnabled
        ? ReplayGain.effectiveVolume(baseVolume: _baseVolume, gainDb: gainDb)
        : _baseVolume * 100;
    return base * _fadeFactor;
  }

  Future<void> _open({required bool autoPlay}) async {
    final int epoch = ++_openEpoch;
    final List<Media> medias = _state.queue
        .map(_mediaFor)
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
      // mpv informa de la duración completa del archivo; con recorte activo la
      // barra debe mostrar solo el fragmento reproducible desde el primer tick.
      final Duration useful = _effectiveDuration(_state.currentTrack);
      if (useful > Duration.zero) {
        _emit(_state.copyWith(duration: useful, position: Duration.zero));
      }
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
    await _player.add(_mediaFor(track));
  }

  /// Inserta una pista justo después de la que suena ahora.
  ///
  /// `media_kit` no expone `insert`, así que se añade al final y se reordena la
  /// lista nativa con `move`. El índice de la pista actual no cambia porque la
  /// inserción siempre es posterior a ella.
  Future<void> insertNext(Track track) async {
    if (_state.queue.isEmpty) {
      await setQueue(<Track>[track]);
      return;
    }

    final int nextIndex = _state.index + 1;
    final int insertIndex = _state.index < 0
        ? 0
        : (nextIndex > _state.queue.length ? _state.queue.length : nextIndex);
    final List<Track> queue = <Track>[..._state.queue]
      ..insert(insertIndex, track);
    _emit(_state.copyWith(queue: List<Track>.unmodifiable(queue)));

    final int appendedIndex = _state.queue.length;
    await _player.add(_mediaFor(track));
    if (appendedIndex != insertIndex) {
      await _player.move(appendedIndex, insertIndex);
    }
  }

  /// Refleja una edición de etiquetas en la instantánea de la cola.
  void updateMetadata(
    int trackId, {
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? genre,
    int? year,
    int? trackNumber,
    int? discNumber,
    String? artworkPath,
  }) {
    bool changed = false;
    Track updatedTrack(Track track) {
      if (track.id != trackId) return track;
      changed = true;
      return track.copyWith(
        title: title,
        artist: artist,
        album: album,
        albumArtist: albumArtist,
        genre: genre,
        year: year,
        trackNumber: trackNumber,
        discNumber: discNumber,
        artworkPath: artworkPath,
      );
    }

    final Track? current = _state.currentTrack;
    final Track? updatedCurrent = current == null
        ? null
        : updatedTrack(current);
    final List<Track> queue = _state.queue
        .map(updatedTrack)
        .toList(growable: false);
    if (!changed) return;

    _emit(
      _state.copyWith(
        currentTrack: updatedCurrent,
        queue: List<Track>.unmodifiable(queue),
      ),
    );
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _state.queue.length) return;
    await _cancelCrossfade();
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
    await _cancelCrossfade();
    _state = PlaybackSnapshot(volume: _baseVolume * 100);
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
    await _cancelCrossfade();
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
    await _cancelCrossfade();
    await _player.next();
  }

  Future<void> previous() async {
    if (!_state.hasQueue) return;
    await _cancelCrossfade();
    // Comportamiento estándar: si llevamos más de 4 s, reinicia la pista.
    if (_state.position > const Duration(seconds: 4)) {
      await seek(Duration.zero);
      return;
    }
    await _player.previous();
  }

  /// [position] es la posición útil (0 = tras el silencio recortado).
  Future<void> seek(Duration position) => _player.seek(_trimStart + position);

  Future<void> seekToProgress(double progress) {
    final int ms = (progress.clamp(0.0, 1.0) * _state.duration.inMilliseconds)
        .round();
    return seek(Duration(milliseconds: ms));
  }

  Future<void> setVolume(double percent) async {
    _baseVolume = (percent.clamp(0, 100)) / 100;
    await _applyVolume();
  }

  /// Ajusta el fundido del temporizador de sueño sin tocar el volumen base.
  Future<void> setFadeFactor(double factor) async {
    final double value = factor.clamp(0.0, 1.0).toDouble();
    if (value == _fadeFactor) return;
    _fadeFactor = value;
    await _applyVolume();
  }

  Future<void> _applyVolume() async {
    final double effective = _currentEffectiveVolume() * _crossfadeGain;
    await _player.setVolume(effective);
    _emit(_state.copyWith(volume: effective));
  }

  /// Configura el crossfade real (dos decks). `enabled == false` o `ms == 0`
  /// lo desactivan y restauran el volumen del deck principal.
  Future<void> configureCrossfade({
    required bool enabled,
    required int ms,
  }) async {
    final int duration = enabled ? ms.clamp(0, 12000) : 0;
    if (duration == _crossfadeMs) return;
    _crossfadeMs = duration;
    if (duration <= 0) {
      await _cancelCrossfade();
    }
    AppLog.i(_tag, 'Crossfade: ${duration > 0 ? '$duration ms' : 'off'}');
  }

  /// Configura el recorte de silencios y reaplica la cola para que mpv use los
  /// nuevos offsets. Llamar con `enabled: false` restaura el comportamiento
  /// original (sin `start`/`end`).
  Future<void> configureSilenceTrim({
    required bool enabled,
    required int startMs,
    required int endMs,
  }) async {
    final Duration start = enabled
        ? Duration(milliseconds: startMs.clamp(0, 60000))
        : Duration.zero;
    final Duration end = enabled
        ? Duration(milliseconds: endMs.clamp(0, 60000))
        : Duration.zero;
    if (start == _trimStart && end == _trimEnd) return;
    _trimStart = start;
    _trimEnd = end;
    if (_state.hasQueue) {
      await _cancelCrossfade();
      await _open(autoPlay: _state.playing);
    }
  }

  /// Dispara el fundido cuando queda menos que la duración configurada.
  ///
  /// Usa el stream de posición sin throttling (a diferencia de [_onPositionChanged])
  /// para que el relevo no se retrase hasta el siguiente tick de UI.
  void _onCrossfadePosition(Duration position) {
    if (_crossfadeMs <= 0 || _crossfading || !_state.playing) return;
    if (_state.repeat == RepeatMode.one) return;
    final int nextIndex = _state.index + 1;
    if (nextIndex >= _state.queue.length && _state.repeat != RepeatMode.all) {
      return;
    }
    final Duration total = _effectiveDuration(_state.currentTrack);
    if (total <= Duration.zero) return;
    final Duration remaining = total - _toEffectivePosition(position);
    if (remaining > Duration(milliseconds: _crossfadeMs)) return;
    unawaited(_startCrossfade(nextIndex % _state.queue.length));
  }

  Future<void> _startCrossfade(int nextIndex) async {
    if (_crossfading || nextIndex < 0 || nextIndex >= _state.queue.length) {
      return;
    }
    _crossfading = true;
    try {
      final Player incoming = _fadePlayer ??= Player();
      await incoming.stop();
      await incoming.open(
        Playlist(
          _state.queue.map(_mediaFor).toList(growable: false),
          index: nextIndex,
        ),
        play: false,
      );
      await incoming.setVolume(0);
      await incoming.setPlaylistMode(PlaylistMode.none);
      await incoming.setShuffle(false);
      final PlatformPlayer? platform = incoming.platform;
      if (platform is NativePlayer && _lastAudioFilter.isNotEmpty) {
        await platform.setProperty('af', _lastAudioFilter);
      }
      await incoming.play();

      final int steps = (_crossfadeMs / 50).round().clamp(8, 40);
      final DateTime started = DateTime.now();
      _crossfadeTimer = Timer.periodic(
        Duration(milliseconds: (_crossfadeMs / steps).round().clamp(10, 200)),
        (Timer timer) async {
          final double t =
              DateTime.now().difference(started).inMilliseconds / _crossfadeMs;
          if (t >= 1) {
            timer.cancel();
            await _finishCrossfade(incoming);
            return;
          }
          _crossfadeGain = (1 - t).clamp(0.0, 1.0);
          await _applyVolume();
          await incoming.setVolume(_currentEffectiveVolume() * t);
        },
      );
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo iniciar el crossfade', error, stack);
      await _cancelCrossfade();
    }
  }

  /// Relevo: el deck entrante pasa a ser el principal y el antiguo se recicla.
  Future<void> _finishCrossfade(Player incoming) async {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    _crossfadeGain = 1;

    final Player outgoing = _player;
    for (final StreamSubscription<dynamic> sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    _player = incoming;
    _fadePlayer = outgoing;
    final int incomingIndex = incoming.state.playlist.index;
    final int newIndex = incomingIndex < 0 ? _state.index : incomingIndex;
    final Track? newTrack = newIndex >= 0 && newIndex < _state.queue.length
        ? _state.queue[newIndex]
        : _state.currentTrack;
    _state = _state.copyWith(
      index: newIndex,
      currentTrack: newTrack,
      position: Duration(milliseconds: _crossfadeMs),
      completed: false,
      error: null,
      duration: _effectiveDuration(newTrack),
    );
    _bindPlayer();
    await outgoing.pause();
    await _applyVolume();
    _crossfading = false;
    AppLog.i(_tag, 'Crossfade completado');
  }

  /// Aborta un fundido en curso y devuelve el volumen al deck principal.
  Future<void> _cancelCrossfade() async {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    _crossfadeGain = 1;
    if (!_crossfading) return;
    _crossfading = false;
    final Player? incoming = _fadePlayer;
    if (incoming != null) {
      try {
        await incoming.stop();
      } catch (_) {
        // El deck se reutilizará en el siguiente fundido.
      }
    }
    await _applyVolume();
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
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    await _crossfadePositionSub?.cancel();
    for (final StreamSubscription<dynamic> sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _states.close();
    final Player? fade = _fadePlayer;
    if (fade != null && !identical(fade, _player)) {
      await fade.dispose();
    }
    await _player.dispose();
  }
}
