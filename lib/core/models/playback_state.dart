import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'track.dart';

enum RepeatMode {
  off,
  one,
  all;

  RepeatMode get next => switch (this) {
    RepeatMode.off => RepeatMode.all,
    RepeatMode.all => RepeatMode.one,
    RepeatMode.one => RepeatMode.off,
  };
}

const Object _unset = Object();

/// Estado inmutable del motor de reproducción.
///
/// Es la única fuente de verdad que consume la UI: no se expone `media_kit`
/// fuera de `AudioEngineService`.
@immutable
class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.currentTrack,
    this.queue = const <Track>[],
    this.shuffledQueue = const <Track>[],
    this.index = -1,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 100,
    this.speed = 1,
    this.shuffle = false,
    this.repeat = RepeatMode.off,
    this.error,
    this.completed = false,
  });

  final Track? currentTrack;

  /// Orden original/secuencial. Nunca se baraja: es el orden canónico que se
  /// guarda en la sesión y el que se restaura al desactivar el aleatorio.
  final List<Track> queue;

  /// Espejo del orden real de reproducción de mpv cuando el aleatorio está
  /// activo. Vacío cuando la cola se reproduce en orden secuencial.
  ///
  /// [index] SIEMPRE se interpreta dentro de [activeQueue], nunca dentro de
  /// [queue] a secas. Esa distinción evita que un índice barajado seleccione
  /// otra pista (y por tanto otra carátula).
  final List<Track> shuffledQueue;
  final int index;
  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;

  /// Volumen efectivo ya normalizado (0..100), listo para media_kit.
  final double volume;
  final double speed;
  final bool shuffle;
  final RepeatMode repeat;
  final String? error;
  final bool completed;

  /// Cola en el orden en que realmente se reproducirá.
  List<Track> get activeQueue =>
      shuffle && shuffledQueue.isNotEmpty ? shuffledQueue : queue;

  bool get hasTrack => currentTrack != null;
  bool get hasQueue => queue.isNotEmpty;
  bool get hasNext =>
      repeat == RepeatMode.all || index < activeQueue.length - 1;
  bool get hasPrevious => index > 0 || repeat == RepeatMode.all;
  double get progress => duration.inMilliseconds == 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  /// Orden aleatorio con la pista activa en primera posición.
  ///
  /// Se usa solo cuando hay que reconstruir la playlist de mpv (por ejemplo al
  /// deshacer un crossfade con el aleatorio activo). Nunca elige carátulas ni
  /// sustituye la pista sonora: solo reordena referencias a [queue].
  static List<Track> shuffledOrder(List<Track> tracks, Object? currentId) {
    final List<Track> order = List<Track>.from(tracks)..shuffle(math.Random());
    if (currentId == null) return List<Track>.unmodifiable(order);
    final int at = order.indexWhere((Track track) => track.id == currentId);
    if (at <= 0) return List<Track>.unmodifiable(order);
    final Track current = order.removeAt(at);
    order.insert(0, current);
    return List<Track>.unmodifiable(order);
  }

  PlaybackSnapshot copyWith({
    Object? currentTrack = _unset,
    List<Track>? queue,
    List<Track>? shuffledQueue,
    int? index,
    bool? playing,
    bool? buffering,
    Duration? position,
    Duration? duration,
    double? volume,
    double? speed,
    bool? shuffle,
    RepeatMode? repeat,
    Object? error = _unset,
    bool? completed,
  }) => PlaybackSnapshot(
    currentTrack: identical(currentTrack, _unset)
        ? this.currentTrack
        : currentTrack as Track?,
    queue: queue ?? this.queue,
    shuffledQueue: shuffledQueue ?? this.shuffledQueue,
    index: index ?? this.index,
    playing: playing ?? this.playing,
    buffering: buffering ?? this.buffering,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    volume: volume ?? this.volume,
    speed: speed ?? this.speed,
    shuffle: shuffle ?? this.shuffle,
    repeat: repeat ?? this.repeat,
    error: identical(error, _unset) ? this.error : error as String?,
    completed: completed ?? this.completed,
  );
}
