import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart' hide Track;

import '../debug/memory_probe.dart';
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
  /// Caché demuxer por deck. 8 MB son suficientes para archivos locales y
  /// streaming normal, y se pagan DOS veces cuando hay crossfade: reducirlo
  /// de 16 MB recorta 16 MB de memoria nativa en cada fundido.
  static const int _demuxerBufferSize = 8 * 1024 * 1024;

  static Player _createPlayer() {
    return Player(
      configuration: const PlayerConfiguration(bufferSize: _demuxerBufferSize),
    );
  }

  /// Un archivo local debe existir; las pistas online usan URLs y no se tocan.
  static bool _isPlayable(Track track) =>
      track.isOnline ||
      (track.path.isNotEmpty && File(track.path).existsSync());

  /// Convierte un error de libmpv en un mensaje breve y sin URLs.
  ///
  /// mpv incluye la URL completa de googlevideo en `Failed to open ...`; eso no
  /// aporta nada al usuario y delata parámetros firmados con validez corta. El
  /// detalle crudo sigue escribiéndose en el log.
  static String sanitizePlaybackError(
    Object message, {
    String? sourceLabel,
    bool exhausted = false,
  }) {
    final String raw = message.toString().trim();
    final String source = sourceLabel ?? 'este servicio';
    if (_isOpenFailure(raw)) {
      return exhausted
          ? 'No se pudo abrir el audio de $source. No hay más fuentes '
                'disponibles.'
          : 'No se pudo abrir el audio de $source. Reintentando…';
    }
    // Si el mensaje trae una URL entremezclada, la quitamos antes de truncar.
    final String cleaned = raw
        .replaceAll(RegExp(r'https?://[^\s)\]]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return 'No se pudo reproducir esta pista. Inténtalo de nuevo.';
    }
    const int max = 140;
    return cleaned.length <= max
        ? cleaned
        : '${cleaned.substring(0, max - 1)}…';
  }

  /// Errores que implican que mpv no pudo abrir la URL (no avisos de decodificación).
  static bool _isOpenFailure(String raw) {
    final String lower = raw.toLowerCase();
    return lower.contains('failed to open') ||
        lower.contains('googlevideo') ||
        lower.contains('http') ||
        lower.contains('403') ||
        lower.contains('404') ||
        lower.contains('410') ||
        lower.contains('permission denied') ||
        lower.contains('cannot open');
  }

  static String _streamKey(Track track) =>
      track.externalId ?? 'track:${track.id}';

  /// Prueba la siguiente URL alternativa de una pista online tras un fallo.
  ///
  /// Cada alternativa lleva sus propias cabeceras (User-Agent incluido), así
  /// que se sustituye la pista en los espejos de la cola y se reabre la playlist
  /// en la misma posición. Devuelve `true` cuando ha lanzado un reintento; el
  /// mensaje "Reintentando…" se limpia en cuanto mpv abre el nuevo media.
  Future<bool> _tryNextStreamAlternative(Track failed) async {
    if (_disposed || failed.streamAlternatives.isEmpty) return false;
    final String key = _streamKey(failed);
    // Un mismo error pueden emitirlo varios listeners de mpv; solo actuamos
    // una vez por ronda para no quemar todas las alternativas de golpe.
    if (!_retryingStreams.add(key)) return false;
    try {
      final int attempt = _streamAttempts[key] ?? 0;
      if (attempt >= failed.streamAlternatives.length) return false;
      final StreamAlternative alternative = failed.streamAlternatives[attempt];
      final Track replacement = failed.copyWith(
        path: alternative.url,
        httpHeaders: alternative.httpHeaders,
      );
      _streamAttempts[key] = attempt + 1;

      List<Track> replaceIn(List<Track> source) {
        final int at = source.indexWhere((Track item) => item.id == failed.id);
        if (at < 0) return source;
        return List<Track>.unmodifiable(<Track>[
          ...source.sublist(0, at),
          replacement,
          ...source.sublist(at + 1),
        ]);
      }

      final String retryMessage = sanitizePlaybackError(
        'Failed to open ${alternative.url}',
        sourceLabel: failed.sourceLabel,
      );
      _state = _state.copyWith(
        queue: replaceIn(_state.queue),
        shuffledQueue: replaceIn(_state.shuffledQueue),
        currentTrack: replacement,
        buffering: true,
        playing: true,
        error: retryMessage,
      );
      _emit(_state);
      AppLog.w(
        _tag,
        'Reintentando “${failed.title}” con '
        '${alternative.label.isEmpty ? 'alternativa ${attempt + 1}' : alternative.label}',
      );
      await _open(autoPlay: true);
      if (!_disposed && identical(_state.error, retryMessage)) {
        _emit(_state.copyWith(error: null, buffering: false));
      }
      return true;
    } finally {
      _retryingStreams.remove(key);
    }
  }

  /// Busca el índice reproducible más cercano a [from] en la dirección pedida.
  ///
  /// Con [wrap] recorre la cola completa (repetir todo, abrir una sesión); sin
  /// él se detiene en los extremos, igual que la playlist nativa de mpv.
  static int _nextPlayableIndex(
    List<Track> order,
    int from, {
    bool forward = true,
    bool wrap = true,
  }) {
    final int length = order.length;
    if (length == 0) return -1;
    final int limit = wrap ? length : (forward ? length - from : from + 1);
    for (int i = 0; i < limit; i++) {
      final int raw = forward ? from + i : from - i;
      if (_isPlayable(order[raw % length])) return raw % length;
    }
    return -1;
  }

  AudioEngineService({Player? player, this.isBackgrounded})
    : _player = player ?? _createPlayer();

  static const String _tag = 'AudioEngine';

  /// Lo inyecta el DI para saber si la UI está en segundo plano. Nunca se usa
  /// para pausar la reproducción: solo reduce la frecuencia de eventos de UI.
  final bool Function()? isBackgrounded;

  /// Deck principal. No es `final` porque al terminar un crossfade se intercambia
  /// con el deck entrante; el handler `_onPlaylistChanged` no se modifica.
  Player _player;

  /// Segundo deck (mpv), solo durante un crossfade. Se dispone al terminar:
  /// conservarlo caliente deja vivo un contexto mpv con su caché de demuxer
  /// y una copia de la playlist, lo que disparaba la RAM cientos de MB.
  Player? _fadePlayer;
  Timer? _crossfadeTimer;
  StreamSubscription<Duration>? _crossfadePositionSub;
  bool _crossfading = false;
  bool _disposed = false;
  bool _awaitingShuffleEvent = false;
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

  /// Intentos ya probados con las URLs alternativas de cada pista online.
  /// La clave es el `externalId` (o el id efímero) para no confundir dos
  /// pistas con el mismo título.
  final Map<String, int> _streamAttempts = <String, int>{};
  final Set<String> _retryingStreams = <String>{};
  String _lastAudioFilter = '';
  DateTime _lastPositionEmit = DateTime.fromMillisecondsSinceEpoch(0);
  Duration? _pendingPosition;
  Timer? _positionTrailingTimer;

  /// Posición sin filtrar, reenlazada al deck activo en cada `_bindPlayer()`.
  /// Así los consumidores (controlador, A-B, letras) nunca quedan suscritos
  /// al reproductor que se descartó durante un crossfade.
  final StreamController<Duration> _positionEvents =
      StreamController<Duration>.broadcast();

  PlaybackSnapshot get state => _state;
  Stream<PlaybackSnapshot> get states => _states.stream;
  Stream<Duration> get positionStream => _positionEvents.stream;
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
    if (_initialized || _disposed) return;
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
      _player.stream.error.listen((String message) async {
        // El log conserva el detalle técnico (incluida la URL); la UI no.
        AppLog.e(_tag, message);
        final Track? failed = _state.currentTrack;
        if (failed != null &&
            failed.isOnline &&
            failed.streamAlternatives.isNotEmpty &&
            _isOpenFailure(message)) {
          final bool retried = await _tryNextStreamAlternative(failed);
          if (retried) return;
          _emit(
            _state.copyWith(
              buffering: false,
              error: sanitizePlaybackError(
                message,
                sourceLabel: failed.sourceLabel,
                exhausted: true,
              ),
            ),
          );
          return;
        }
        // Un error puede llegar sin el `buffering=false` de mpv: lo limpiamos
        // aquí para que el spinner y la sesión de medios no queden colgados.
        // No forzamos `playing: false`: mpv también reporta avisos no fatales.
        _emit(
          _state.copyWith(
            buffering: false,
            error: sanitizePlaybackError(
              message,
              sourceLabel: failed?.sourceLabel,
            ),
          ),
        );
      }),
    ]);
    // Se guarda aparte para cancelarla sola al cambiar la configuración de
    // crossfade; no se añade a `_subscriptions` para no cancelarla dos veces.
    _crossfadePositionSub = _player.stream.position.listen(
      _onCrossfadePosition,
    );
  }

  /// La UI solo necesita ~5 posiciones por segundo para animar con suavidad
  /// (2 por segundo en segundo plano; 1 Hz hacía que el contador pareciera
  /// congelado cuando la ventana pierde el foco).
  ///
  /// libmpv puede entregar decenas por segundo; filtrar las instantáneas evita
  /// reconstruir toda la app de más. El flujo sin filtrar se rebroadcast para
  /// A-B/letras, y un único timer de cola garantiza que la última posición
  /// recibida siempre llegue a la UI aunque caiga dentro del intervalo.
  void _onPositionChanged(Duration value) {
    if (!_positionEvents.isClosed) _positionEvents.add(value);

    final DateTime now = DateTime.now();
    final Duration interval = (isBackgrounded?.call() ?? false)
        ? const Duration(milliseconds: 500)
        : const Duration(milliseconds: 200);
    if (now.difference(_lastPositionEmit) < interval) {
      _pendingPosition = value;
      _positionTrailingTimer ??= Timer(interval, () {
        _positionTrailingTimer = null;
        final Duration? pending = _pendingPosition;
        _pendingPosition = null;
        if (pending != null) _emitPosition(pending);
      });
      return;
    }
    _emitPosition(value);
  }

  void _emitPosition(Duration value) {
    _lastPositionEmit = DateTime.now();
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

  /// Descarta posiciones pendientes del track anterior para que el primer tick
  /// de la nueva pista no se pierda en el filtro.
  void _resetPositionFeed() {
    _lastPositionEmit = DateTime.fromMillisecondsSinceEpoch(0);
    _pendingPosition = null;
    _positionTrailingTimer?.cancel();
    _positionTrailingTimer = null;
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
    List<Track> apply(List<Track> source) {
      return source
          .map((Track track) {
            if (track.id == trackId && track.isFavorite != value) {
              queueChanged = true;
              return track.copyWith(isFavorite: value);
            }
            return track;
          })
          .toList(growable: false);
    }

    final List<Track> queue = apply(_state.queue);
    final List<Track> shuffled = _state.shuffledQueue.isEmpty
        ? const <Track>[]
        : List<Track>.unmodifiable(apply(_state.shuffledQueue));

    if (queueChanged) {
      _state = _state.copyWith(
        queue: List<Track>.unmodifiable(queue),
        shuffledQueue: shuffled,
        currentTrack: _state.currentTrack,
      );
    }
    _emit(_state);
  }

  /// Resuelve la pista que corresponde a un `Media.uri` de mpv.
  ///
  /// Es la traducción definitiva índice de mpv → pista: funciona tanto con la
  /// cola original como con la barajada, porque compara la ruta del archivo y
  /// no una posición de lista que mpv ya ha reordenado.
  Track? _trackForUri(String uri) {
    for (final Track track in _state.activeQueue) {
      if (track.path == uri) return track;
    }
    for (final Track track in _state.queue) {
      if (track.path == uri) return track;
    }
    return null;
  }

  static bool _samePlaylistOrder(List<Track> a, List<Track> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].path != b[i].path) return false;
    }
    return true;
  }

  void _onPlaylistChanged(Playlist playlist) {
    final int eventIndex = playlist.index;
    final List<Track> mapped = playlist.medias
        .map((Media media) => _trackForUri(media.uri))
        .whereType<Track>()
        .toList(growable: false);

    // `playlist-shuffle` reordena físicamente la playlist de mpv. El índice del
    // evento pertenece a ESE orden, nunca a `_state.queue`: lo reflejamos en
    // `shuffledQueue` y derivamos la pista del propio `Media` sonoro. Solo
    // inferimos aleatorio del orden cuando el evento viene de un `setShuffle`:
    // `add`/`move`/`remove` también reordenan transitoriamente y no deben
    // activar el modo aleatorio por error.
    final bool orderChanged =
        _awaitingShuffleEvent &&
        mapped.isNotEmpty &&
        !_samePlaylistOrder(mapped, _state.queue);
    final bool isShuffled = orderChanged || _state.shuffle;
    final List<Track> shuffled = isShuffled
        ? List<Track>.unmodifiable(mapped)
        : const <Track>[];
    final List<Track> active = shuffled.isNotEmpty ? shuffled : _state.queue;

    final int index = eventIndex < 0 || active.isEmpty
        ? _state.index
        : eventIndex.clamp(0, active.length - 1);
    final Track? track = eventIndex >= 0 && eventIndex < mapped.length
        ? mapped[eventIndex]
        : (index >= 0 && index < active.length
              ? active[index]
              : _state.currentTrack);

    final bool trackChanged =
        track != null && track.id != _state.currentTrack?.id;
    if (trackChanged) _resetPositionFeed();

    _emit(
      _state.copyWith(
        index: index,
        currentTrack: track,
        shuffledQueue: shuffled,
        shuffle: isShuffled,
        duration: trackChanged ? track.duration : _state.duration,
        position: trackChanged ? Duration.zero : _state.position,
        completed: trackChanged ? false : _state.completed,
        buffering: trackChanged ? false : _state.buffering,
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
    _resetPositionFeed();
    // Cola nueva: los reintentos de la cola anterior ya no proceden.
    _streamAttempts.clear();
    _retryingStreams.clear();
    final int index = startIndex.clamp(0, tracks.length - 1);
    _state = _state.copyWith(
      queue: List<Track>.unmodifiable(tracks),
      // La cola vieja no debe filtrarse: `_open` volverá a aplicar `shuffle`
      // sobre el orden original y `_onPlaylistChanged` reconstruirá el espejo.
      shuffledQueue: const <Track>[],
      index: index,
      currentTrack: tracks[index],
      position: Duration.zero,
      duration: tracks[index].duration,
      completed: false,
      buffering: false,
      playing: autoPlay,
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
    // Las pistas de InnerTube necesitan las cabeceras devueltas por `player`;
    // para el resto la ausencia de cabeceras es equivalente a `null`.
    final Map<String, String>? headers = track.httpHeaders.isEmpty
        ? null
        : track.httpHeaders;
    if (_trimStart <= Duration.zero && _trimEnd <= Duration.zero) {
      return Media(track.path, httpHeaders: headers);
    }
    final Duration end = track.duration - _trimEnd;
    return Media(
      track.path,
      start: _trimStart > Duration.zero ? _trimStart : null,
      end: end > _trimStart ? end : null,
      httpHeaders: headers,
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
    if (_disposed) return;
    final int epoch = ++_openEpoch;
    // La playlist nativa se abre SIEMPRE en el orden activo. Así `playlist.index`
    // y `activeQueue[index]` significan lo mismo incluso con aleatorio activo.
    final List<Track> order = _state.activeQueue;
    if (order.isEmpty) return;
    MemoryProbe.mark('queue:open:${order.length}');

    final int wanted = _state.index.clamp(0, order.length - 1);
    // Si el archivo desapareció, arrancamos en la siguiente pista disponible sin
    // tocar `queue`/`shuffledQueue`, para no desalinear el orden de mpv.
    final int start = _nextPlayableIndex(order, wanted);
    if (start < 0) {
      _emit(
        _state.copyWith(
          buffering: false,
          playing: false,
          error: 'No hay pistas disponibles en la cola',
        ),
      );
      return;
    }
    if (start != wanted) {
      _state = _state.copyWith(
        index: start,
        currentTrack: order[start],
        position: Duration.zero,
        duration: order[start].duration,
        buffering: false,
        error: 'Archivo no disponible: ${order[wanted].title}',
      );
      _emit(_state);
    }

    final List<Media> medias = order.map(_mediaFor).toList(growable: false);

    try {
      await _player.open(Playlist(medias, index: start), play: autoPlay);
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
      _emit(
        _state.copyWith(
          buffering: false,
          playing: false,
          error: sanitizePlaybackError(
            error,
            sourceLabel: _state.currentTrack?.sourceLabel,
            exhausted: _state.currentTrack?.streamAlternatives.isEmpty ?? true,
          ),
        ),
      );
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
    final List<Track> shuffled = _state.shuffledQueue.isEmpty
        ? const <Track>[]
        : List<Track>.unmodifiable(<Track>[..._state.shuffledQueue, track]);
    _emit(
      _state.copyWith(
        queue: List<Track>.unmodifiable(queue),
        shuffledQueue: shuffled,
      ),
    );
    // mpv mantiene su playlist en el orden activo, así que `add` reproduce la
    // misma posición que acabamos de registrar en el espejo.
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

    // La inserción se calcula sobre el orden activo: con aleatorio, "a
    // continuación" significa después de la pista en orden barajado.
    final List<Track> active = _state.activeQueue;
    final int insertIndex = _state.index < 0
        ? 0
        : (_state.index + 1).clamp(0, active.length);
    final List<Track> updatedActive = <Track>[...active]
      ..insert(insertIndex, track);
    final bool isShuffled = _state.shuffledQueue.isNotEmpty;
    final List<Track> queue = isShuffled
        ? <Track>[..._state.queue, track]
        : updatedActive;
    _emit(
      _state.copyWith(
        queue: List<Track>.unmodifiable(queue),
        shuffledQueue: isShuffled
            ? List<Track>.unmodifiable(updatedActive)
            : const <Track>[],
      ),
    );

    final int appendedIndex = active.length;
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
    final List<Track> shuffled = _state.shuffledQueue.isEmpty
        ? const <Track>[]
        : List<Track>.unmodifiable(
            _state.shuffledQueue.map(updatedTrack).toList(growable: false),
          );
    if (!changed) return;

    _emit(
      _state.copyWith(
        currentTrack: updatedCurrent,
        queue: List<Track>.unmodifiable(queue),
        shuffledQueue: shuffled,
      ),
    );
  }

  Future<void> removeAt(int index) async {
    // [index] viene de la cola que ve la UI: el orden activo.
    final List<Track> active = _state.activeQueue;
    if (index < 0 || index >= active.length) return;
    await _cancelCrossfade();
    final Track removed = active[index];
    final List<Track> updatedActive = <Track>[...active]..removeAt(index);
    final List<Track> queue = <Track>[..._state.queue]
      ..removeWhere(
        (Track track) =>
            identical(track, removed) ||
            (track.id == removed.id && track.path == removed.path),
      );

    int newIndex = _state.index;
    if (index < _state.index) {
      newIndex--;
    } else if (index == _state.index && updatedActive.isNotEmpty) {
      newIndex = index.clamp(0, updatedActive.length - 1);
    }
    final Track? nextTrack = updatedActive.isEmpty
        ? null
        : updatedActive[newIndex.clamp(0, updatedActive.length - 1)];
    _emit(
      _state.copyWith(
        queue: List<Track>.unmodifiable(queue),
        shuffledQueue: _state.shuffledQueue.isEmpty
            ? const <Track>[]
            : List<Track>.unmodifiable(updatedActive),
        index: newIndex < 0 ? 0 : newIndex,
        currentTrack: index == _state.index ? nextTrack : _state.currentTrack,
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
    // Buscar primero en el orden activo evita saltar a otra pista cuando el
    // mismo id aparece en una posición distinta de la cola original.
    final List<Track> active = _state.activeQueue;
    int index = active.indexWhere((Track t) => t.id == track.id);
    if (index < 0) {
      index = _state.queue.indexWhere((Track t) => t.id == track.id);
    }
    if (index >= 0 && index < active.length) {
      await playIndex(index);
    } else {
      await setQueue(<Track>[track]);
    }
  }

  Future<void> playIndex(int index) async {
    final List<Track> active = _state.activeQueue;
    if (index < 0 || index >= active.length) return;
    final Track target = active[index];
    if (!_isPlayable(target)) {
      final int fallback = _nextPlayableIndex(
        active,
        index + 1,
        wrap: _state.repeat == RepeatMode.all,
      );
      if (fallback < 0) {
        _emit(
          _state.copyWith(
            buffering: false,
            playing: false,
            error: 'No hay pistas disponibles en la cola',
          ),
        );
        return;
      }
      _emit(_state.copyWith(error: 'Archivo no disponible: ${target.title}'));
      await playIndex(fallback);
      return;
    }
    await _cancelCrossfade();
    _resetPositionFeed();
    // Elegir explícitamente una pista vuelve a intentar su URL principal.
    _streamAttempts.remove(_streamKey(target));
    _state = _state.copyWith(
      index: index,
      currentTrack: target,
      position: Duration.zero,
      duration: target.duration,
      buffering: false,
      completed: false,
      playing: true,
    );
    _emit(_state);
    // Si la cola nativa no se abrió (sesión restaurada, open fallido o stop),
    // `jump` no hace nada y la pista nunca arrancaría: reabrimos la cola.
    if (_player.state.playlist.medias.isEmpty) {
      await _open(autoPlay: true);
      return;
    }
    // mpv ya tiene su playlist en el orden activo, así que el índice coincide.
    await _player.jump(index);
    await _player.play();
  }

  Future<void> play() async {
    _emit(_state.copyWith(playing: true, buffering: false));
    await _player.play();
  }

  Future<void> pause() async {
    _emit(_state.copyWith(playing: false));
    await _player.pause();
  }

  Future<void> playOrPause() => _state.playing ? pause() : play();

  Future<void> stop() async {
    _resetPositionFeed();
    _emit(_state.copyWith(playing: false, position: Duration.zero));
    await _player.stop();
  }

  Future<void> next() async {
    if (!_state.hasQueue) return;
    await _cancelCrossfade();
    final int target = _nextPlayableIndex(
      _state.activeQueue,
      _state.index + 1,
      wrap: _state.repeat == RepeatMode.all,
    );
    if (target < 0) return;
    await playIndex(target);
  }

  Future<void> previous() async {
    if (!_state.hasQueue) return;
    await _cancelCrossfade();
    // Comportamiento estándar: si llevamos más de 4 s, reinicia la pista.
    if (_state.position > const Duration(seconds: 4)) {
      await seek(Duration.zero);
      return;
    }
    final int target = _nextPlayableIndex(
      _state.activeQueue,
      _state.index - 1,
      forward: false,
      wrap: _state.repeat == RepeatMode.all,
    );
    if (target < 0) return;
    await playIndex(target);
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
      // Con el crossfade apagado no debe quedar ningún mpv secundario vivo.
      await _releaseFadeDeck();
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
    final int activeLength = _state.activeQueue.length;
    if (nextIndex >= activeLength && _state.repeat != RepeatMode.all) {
      return;
    }
    final Duration total = _effectiveDuration(_state.currentTrack);
    if (total <= Duration.zero) return;
    final Duration remaining = total - _toEffectivePosition(position);
    if (remaining > Duration(milliseconds: _crossfadeMs)) return;
    unawaited(_startCrossfade(nextIndex % activeLength));
  }

  Future<void> _startCrossfade(int nextIndex) async {
    final List<Track> active = _state.activeQueue;
    if (_crossfading || nextIndex < 0 || nextIndex >= active.length) {
      return;
    }
    // Si la siguiente pista no está disponible, se deja avanzar la playlist
    // normal: el handler de error/`next()` hará el salto seguro.
    if (!_isPlayable(active[nextIndex])) return;
    _crossfading = true;
    MemoryProbe.mark('crossfade:start');
    try {
      final Player incoming = _fadePlayer ??= _createPlayer();
      await incoming.stop();
      // El deck entrante usa el MISMO orden activo, así que su `playlist.index`
      // vuelve a significar lo mismo que `activeQueue[index]`.
      await incoming.open(
        Playlist(
          active.map(_mediaFor).toList(growable: false),
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
    // Esta suscripción pertenece al deck saliente: cancelarla antes de
    // reenlazar evita dejar un listener vivo sobre un mpv a punto de liberarse.
    await _crossfadePositionSub?.cancel();
    _crossfadePositionSub = null;
    for (final StreamSubscription<dynamic> sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    _player = incoming;
    _fadePlayer = outgoing;
    final Playlist incomingPlaylist = incoming.state.playlist;
    final int incomingIndex = incomingPlaylist.index;
    final int activeLength = _state.activeQueue.length;
    final int newIndex = incomingIndex < 0 || activeLength == 0
        ? _state.index
        : incomingIndex.clamp(0, activeLength - 1);
    final Track? newTrack =
        incomingIndex >= 0 && incomingIndex < incomingPlaylist.medias.length
        ? _trackForUri(incomingPlaylist.medias[incomingIndex].uri)
        : (newIndex >= 0 && newIndex < activeLength
              ? _state.activeQueue[newIndex]
              : _state.currentTrack);
    final List<Track> shuffled = _state.shuffledQueue.isEmpty
        ? const <Track>[]
        : List<Track>.unmodifiable(_state.activeQueue);
    _state = _state.copyWith(
      index: newIndex,
      currentTrack: newTrack,
      shuffledQueue: shuffled,
      position: Duration(milliseconds: _crossfadeMs),
      completed: false,
      error: null,
      duration: _effectiveDuration(newTrack),
    );
    _bindPlayer();
    await outgoing.pause();
    // El deck saliente ya no volverá a usarse: liberar su contexto mpv evita
    // retener para siempre una segunda caché de demuxer y otra playlist.
    await _releaseFadeDeck();
    await _applyVolume();
    _crossfading = false;
    MemoryProbe.mark('crossfade:finish');
    AppLog.i(_tag, 'Crossfade completado');
  }

  /// Aborta un fundido en curso y devuelve el volumen al deck principal.
  Future<void> _cancelCrossfade() async {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    _crossfadeGain = 1;
    if (!_crossfading) return;
    _crossfading = false;
    await _releaseFadeDeck();
    await _applyVolume();
  }

  /// Libera el deck secundario y sus recursos nativos (idempotente).
  Future<void> _releaseFadeDeck() async {
    final Player? deck = _fadePlayer;
    _fadePlayer = null;
    if (deck == null || identical(deck, _player)) return;
    try {
      await deck.stop();
    } catch (_) {
      // Un deck ya detenido no impide liberarlo.
    }
    try {
      await deck.dispose();
    } catch (_) {
      // No debe interrumpir la reproducción del deck principal.
    }
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

  /// Activa/desactiva el aleatorio sin tocar la pista que suena.
  ///
  /// mpv ejecuta `playlist-shuffle`/`playlist-unshuffle` y conserva la entrada
  /// actual; `_onPlaylistChanged` reconstruye `shuffledQueue` desde el propio
  /// `Media` sonoro. Por eso la carátula nunca se elige por índice ni cambia al
  /// conmutar el modo.
  Future<void> setShuffle(bool value) async {
    if (_state.shuffle == value) return;
    _emit(_state.copyWith(shuffle: value));

    if (_player.state.shuffle == value) {
      // Tras un crossfade mpv ya está en el modo pedido; si aún arrastramos un
      // espejo barajado hay que reconstruir la playlist en orden secuencial.
      if (!value && _state.shuffledQueue.isNotEmpty) {
        final Track? current = _state.currentTrack;
        final Duration absolute = _trimStart + _state.position;
        final int found = current == null
            ? 0
            : _state.queue.indexWhere((Track track) => track.id == current.id);
        final int index = found < 0 ? 0 : found;
        _state = _state.copyWith(
          shuffledQueue: const <Track>[],
          index: index,
          currentTrack:
              current ?? (_state.queue.isEmpty ? null : _state.queue[index]),
        );
        final bool wasPlaying = _state.playing;
        await _open(autoPlay: wasPlaying);
        if (absolute > Duration.zero) await _player.seek(absolute);
      }
      return;
    }

    _awaitingShuffleEvent = true;
    try {
      await _player.setShuffle(value);
    } finally {
      _awaitingShuffleEvent = false;
    }
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
    if (_disposed) return;
    _disposed = true;
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    _positionTrailingTimer?.cancel();
    _positionTrailingTimer = null;
    await _crossfadePositionSub?.cancel();
    _crossfadePositionSub = null;
    for (final StreamSubscription<dynamic> sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _states.close();
    await _positionEvents.close();
    await _releaseFadeDeck();
    await _player.dispose();
  }
}
