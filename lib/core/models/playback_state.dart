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
  final List<Track> queue;
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

  bool get hasTrack => currentTrack != null;
  bool get hasQueue => queue.isNotEmpty;
  bool get hasNext => repeat == RepeatMode.all || index < queue.length - 1;
  bool get hasPrevious => index > 0 || repeat == RepeatMode.all;
  double get progress => duration.inMilliseconds == 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  PlaybackSnapshot copyWith({
    Object? currentTrack = _unset,
    List<Track>? queue,
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
