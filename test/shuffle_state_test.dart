import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/models/playback_state.dart';
import 'package:polaris_music/core/models/track.dart';

Track _track(int id) => Track(
  id: id,
  path: '/music/$id.mp3',
  title: 'Track $id',
  artist: 'Artista',
  album: 'Álbum',
  durationMs: 100000,
);

void main() {
  group('Cola activa y aleatorio', () {
    final List<Track> original = <Track>[
      _track(1),
      _track(2),
      _track(3),
      _track(4),
    ];
    final List<Track> shuffled = <Track>[
      _track(3),
      _track(1),
      _track(4),
      _track(2),
    ];

    test('sin aleatorio la cola activa es la original', () {
      const PlaybackSnapshot state = PlaybackSnapshot();
      final PlaybackSnapshot withQueue = state.copyWith(queue: original);
      expect(withQueue.activeQueue, same(original));
      expect(withQueue.shuffledQueue, isEmpty);
    });

    test('con aleatorio la cola activa es el espejo barajado', () {
      final PlaybackSnapshot state = PlaybackSnapshot(
        queue: original,
        shuffledQueue: shuffled,
        shuffle: true,
        index: 2,
      );
      expect(state.activeQueue, same(shuffled));
      expect(state.activeQueue[state.index].id, 4);
      expect(state.queue[state.index].id, 3);
    });

    test('hasNext y hasPrevious usan el orden activo', () {
      final PlaybackSnapshot state = PlaybackSnapshot(
        queue: original,
        // Orden activo más corto: el último de la cola ya no es el último activo.
        shuffledQueue: shuffled.sublist(0, 2),
        shuffle: true,
        index: 0,
      );
      expect(state.hasNext, isTrue);
      expect(state.hasPrevious, isFalse);

      final PlaybackSnapshot sequential = state.copyWith(shuffle: false);
      expect(sequential.hasNext, isTrue);
      expect(
        PlaybackSnapshot(
          queue: original,
          shuffledQueue: shuffled.sublist(0, 2),
          shuffle: true,
          index: 1,
        ).hasNext,
        isFalse,
      );
    });

    test('shuffledOrder conserva la pista actual y no pierde ninguna', () {
      final List<Track> order = PlaybackSnapshot.shuffledOrder(original, 3);
      expect(order.first.id, 3);
      expect(order.map((Track track) => track.id).toSet(), <int>{1, 2, 3, 4});
      expect(order.length, original.length);
    });

    test('copyWith conserva y permite limpiar el espejo', () {
      final PlaybackSnapshot state = PlaybackSnapshot(
        queue: original,
        shuffledQueue: shuffled,
        shuffle: true,
      );
      expect(state.copyWith(playing: true).shuffledQueue, same(shuffled));

      final PlaybackSnapshot restored = state.copyWith(
        shuffle: false,
        shuffledQueue: const <Track>[],
      );
      expect(restored.shuffledQueue, isEmpty);
      expect(restored.activeQueue, same(original));
    });
  });
}
