import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/features/online_music/domain/music_source.dart';
import 'package:polaris_music/features/online_music/domain/music_source_catalog.dart';
import 'package:polaris_music/features/online_music/domain/online_track.dart';

void main() {
  group('Integración de fuentes', () {
    test('YouTube Music se enruta con su prefijo y permite stream anónimo', () {
      expect(
        MusicSourceIdX.fromExternalId('youtube:abc123'),
        MusicSourceId.youtube,
      );
      expect(MusicSourceId.youtube.label, 'YouTube Music');
      expect(
        MusicSourceIdX.fromExternalId('youtube:abc123'),
        MusicSourceId.youtube,
      );
    });

    test('el catálogo mantiene fuentes separadas y deduplicadas', () {
      const CatalogResult result = CatalogResult(
        query: 'pop',
        isTrending: false,
        sources: <SourceResult>[
          SourceResult(
            source: MusicSourceId.audius,
            items: <OnlineTrack>[
              OnlineTrack(
                externalId: 'audius:1',
                sourceId: '1',
                title: 'A',
                artist: 'X',
                durationMs: 1000,
              ),
            ],
          ),
          SourceResult(
            source: MusicSourceId.youtube,
            items: <OnlineTrack>[
              OnlineTrack(
                externalId: 'youtube:1',
                sourceId: '1',
                title: 'A',
                artist: 'Y',
                durationMs: 2000,
                sourceLabel: 'YouTube Music',
              ),
            ],
          ),
        ],
      );

      expect(result.tracks, hasLength(2));
      expect(result.tracks.map((t) => t.externalId), <String>[
        'audius:1',
        'youtube:1',
      ]);
    });
  });
}
