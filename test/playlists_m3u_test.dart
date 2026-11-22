import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/models/track.dart';
import 'package:polaris_music/core/utils/m3u_parser.dart';
import 'package:polaris_music/features/library/domain/smart_playlist.dart';

Track _track(
  int id, {
  String title = 'Pista',
  bool favorite = false,
  int plays = 0,
  Duration duration = const Duration(minutes: 3),
  DateTime? added,
  DateTime? played,
}) {
  return Track(
    id: id,
    path: '/musica/$id.mp3',
    title: title,
    artist: 'Artista',
    album: 'Álbum',
    durationMs: duration.inMilliseconds,
    isFavorite: favorite,
    playCount: plays,
    addedAt: added,
    lastPlayedAt: played,
  );
}

void main() {
  group('M3U', () {
    test('lee EXTINF y resuelve rutas relativas', () {
      final M3uDocument document = M3uDocument.parse(
        '#EXTM3U\n'
        '#EXTINF:123,Artista - Canción\n'
        'cancion.mp3\n'
        '#EXTINF:-1,Sin duración\n'
        'sub/otra.mp3\n',
        basePath: r'C:\Musica',
      );

      expect(document.entries, hasLength(2));
      expect(document.entries.first.title, 'Artista - Canción');
      expect(document.entries.first.durationSeconds, 123);
      expect(document.entries.first.location, r'C:\Musica\cancion.mp3');
      expect(document.entries.last.durationSeconds, isNull);
    });

    test('conserva las URLs y aplica el filtro', () {
      final M3uDocument document = M3uDocument.parse(
        '#EXTM3U\nhttps://ejemplo/audio.mp3\nignorar.mp3\n',
        basePath: r'C:\Musica',
        keep: (String location) => location.startsWith('https'),
      );

      expect(document.entries, hasLength(1));
      expect(document.entries.single.location, 'https://ejemplo/audio.mp3');
    });

    test('el texto exportado se puede volver a leer', () {
      final M3uDocument original = M3uDocument(<M3uEntry>[
        const M3uEntry(
          location: r'C:\Musica\a.mp3',
          title: 'Artista - A',
          durationSeconds: 42,
        ),
      ]);
      final M3uDocument reread = M3uDocument.parse(original.serialize());

      expect(reread.entries.single.location, r'C:\Musica\a.mp3');
      expect(reread.entries.single.title, 'Artista - A');
      expect(reread.entries.single.durationSeconds, 42);
    });
  });

  group('Listas inteligentes', () {
    final DateTime now = DateTime(2026, 11, 21);
    final List<Track> tracks = <Track>[
      _track(1, title: 'Favorita', favorite: true, plays: 9),
      _track(
        2,
        title: 'Reciente',
        added: now.subtract(const Duration(days: 2)),
        played: now.subtract(const Duration(hours: 1)),
      ),
      _track(
        3,
        title: 'Larga',
        duration: const Duration(minutes: 7),
        added: now.subtract(const Duration(days: 90)),
      ),
    ];

    test('favoritos y duración larga', () {
      expect(
        SmartPlaylistRule.favorites.apply(tracks).map((Track t) => t.id),
        <int>[1],
      );
      expect(
        SmartPlaylistRule.longTracks.apply(tracks).map((Track t) => t.id),
        <int>[3],
      );
    });

    test('más reproducidas y recientes', () {
      expect(
        SmartPlaylistRule.mostPlayed.apply(tracks).map((Track t) => t.id).first,
        1,
      );
      expect(
        SmartPlaylistRule.recentlyAdded
            .apply(tracks, now: now)
            .map((Track t) => t.id),
        <int>[2],
      );
      expect(
        SmartPlaylistRule.recentlyPlayed
            .apply(tracks, now: now)
            .map((Track t) => t.id),
        <int>[2],
      );
    });

    test('la regla se guarda y se recupera por nombre', () {
      for (final SmartPlaylistRule rule in SmartPlaylistRule.values) {
        expect(SmartPlaylistRule.fromName(rule.name), rule);
      }
      expect(SmartPlaylistRule.fromName('no existe'), isNull);
    });
  });
}
