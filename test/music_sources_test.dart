import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/features/online_music/data/online_catalog_repository.dart';
import 'package:polaris_music/features/online_music/data/source_helpers.dart';
import 'package:polaris_music/features/online_music/domain/music_source.dart';
import 'package:polaris_music/features/online_music/domain/music_source_catalog.dart';
import 'package:polaris_music/features/online_music/domain/online_catalog_items.dart';
import 'package:polaris_music/features/online_music/domain/online_track.dart';

OnlineTrack track(String externalId) => OnlineTrack(
  externalId: externalId,
  sourceId: externalId.split(':').last,
  title: 'Pista $externalId',
  artist: 'Artista',
  durationMs: 1000,
);

class FakeSource implements MusicSourceProvider {
  FakeSource(
    this.id, {
    this.items = const <OnlineTrack>[],
    this.error,
    this.status = const MusicSourceStatus(),
    this.canStream = true,
    this.canDownload = true,
  });

  @override
  final MusicSourceId id;
  final List<OnlineTrack> items;
  final Object? error;
  @override
  final MusicSourceStatus status;

  @override
  final bool canStream;
  @override
  final bool canDownload;

  @override
  bool get canSearch => true;

  @override
  bool get canTrending => true;

  int resolveCalls = 0;

  @override
  Future<MusicSourceStatus> checkAvailability() async => status;

  @override
  Future<SourceResult> search(String query, {int limit = 25}) async {
    if (error != null) throw error!;
    return SourceResult(source: id, items: items.take(limit).toList());
  }

  @override
  Future<SourceResult> trending({int limit = 25}) async {
    if (error != null) throw error!;
    return SourceResult(source: id, items: items.take(limit).toList());
  }

  @override
  Future<List<OnlineCollectionRef>> searchCollections(
    String query, {
    required OnlineSearchType type,
    int limit = 25,
  }) async => const <OnlineCollectionRef>[];

  @override
  Future<List<OnlineTrack>> collectionTracks(
    OnlineCollectionRef collection, {
    int limit = 50,
  }) async => const <OnlineTrack>[];

  @override
  Future<ResolvedStream> resolveStream(OnlineTrack track) async {
    resolveCalls++;
    return ResolvedStream(url: 'https://audio.example/${id.prefix}.mp3');
  }

  @override
  Future<String?> cacheArtwork(String? artworkUrl) async => null;
}

void main() {
  group('MusicSourceId', () {
    test('extrae la fuente del externalId', () {
      expect(
        MusicSourceIdX.fromExternalId('soundcloud:123'),
        MusicSourceId.soundcloud,
      );
      expect(
        MusicSourceIdX.fromExternalId('spotify:abc'),
        MusicSourceId.spotify,
      );
      expect(MusicSourceIdX.fromExternalId('tidal:9'), MusicSourceId.tidal);
      expect(MusicSourceIdX.fromExternalId('desconocido:1'), isNull);
      expect(MusicSourceIdX.fromExternalId('sin-prefijo'), isNull);
    });

    test('Audius, SoundCloud y YouTube declaran audio reproducible', () {
      expect(MusicSourceId.audius.canStreamAudio, isTrue);
      expect(MusicSourceId.soundcloud.canStreamAudio, isTrue);
      expect(MusicSourceId.youtube.canStreamAudio, isTrue);
      expect(MusicSourceId.spotify.canStreamAudio, isFalse);
      expect(MusicSourceId.tidal.canStreamAudio, isFalse);
    });
  });

  group('MusicSourceCatalog', () {
    test('unifica resultados y elimina duplicados por externalId', () async {
      final MusicSourceCatalog catalog = MusicSourceCatalog(
        <MusicSourceProvider>[
          FakeSource(
            MusicSourceId.audius,
            items: <OnlineTrack>[track('audius:1'), track('audius:2')],
          ),
          FakeSource(
            MusicSourceId.soundcloud,
            items: <OnlineTrack>[track('audius:2'), track('soundcloud:3')],
          ),
        ],
      );

      final CatalogResult result = await catalog.search('consulta');

      expect(result.sources, hasLength(2));
      expect(result.tracks.map((OnlineTrack item) => item.externalId), <String>[
        'audius:1',
        'audius:2',
        'soundcloud:3',
      ]);
      expect(result.failed, isEmpty);
      expect(result.query, 'consulta');
      expect(result.isTrending, isFalse);
    });

    test('un fallo parcial no impide mostrar el resto de fuentes', () async {
      final MusicSourceCatalog catalog = MusicSourceCatalog(
        <MusicSourceProvider>[
          FakeSource(
            MusicSourceId.soundcloud,
            error: StateError('SoundCloud caído'),
          ),
          FakeSource(
            MusicSourceId.audius,
            items: <OnlineTrack>[track('audius:1')],
          ),
        ],
      );

      final CatalogResult result = await catalog.trending();

      expect(result.tracks, hasLength(1));
      expect(result.failed, hasLength(1));
      expect(result.failed.single.source, MusicSourceId.soundcloud);
      expect(result.failed.single.status.available, isFalse);
      expect(result.failed.single.status.issue, MusicSourceIssue.unavailable);
      expect(result.isTrending, isTrue);
    });

    test('permite consultar solo una fuente', () async {
      final FakeSource audius = FakeSource(MusicSourceId.audius);
      final FakeSource spotify = FakeSource(MusicSourceId.spotify);
      final MusicSourceCatalog catalog = MusicSourceCatalog(
        <MusicSourceProvider>[audius, spotify],
      );

      final CatalogResult result = await catalog.search(
        'x',
        only: <MusicSourceId>{MusicSourceId.spotify},
      );

      expect(result.sources, hasLength(1));
      expect(result.sources.single.source, MusicSourceId.spotify);
    });

    test('providerFor devuelve el proveedor registrado', () {
      final FakeSource soundcloud = FakeSource(MusicSourceId.soundcloud);
      final MusicSourceCatalog catalog = MusicSourceCatalog(
        <MusicSourceProvider>[soundcloud],
      );

      expect(catalog.providerFor(MusicSourceId.soundcloud), soundcloud);
      expect(catalog.providerFor(MusicSourceId.tidal), isNull);
    });
  });

  group('OnlineCatalogRepository', () {
    test('enruta el stream según el prefijo de externalId', () async {
      final FakeSource audius = FakeSource(MusicSourceId.audius);
      final FakeSource soundcloud = FakeSource(MusicSourceId.soundcloud);
      final OnlineCatalogRepository repository = OnlineCatalogRepository(
        catalog: MusicSourceCatalog(<MusicSourceProvider>[audius, soundcloud]),
        artworkCache: ArtworkCache(),
      );

      final ResolvedStream result = await repository.resolveStream(
        track('soundcloud:88'),
      );

      expect(result.url, 'https://audio.example/soundcloud.mp3');
      expect(soundcloud.resolveCalls, 1);
      expect(audius.resolveCalls, 0);
    });

    test('rechaza fuentes que no pueden reproducir audio', () async {
      final FakeSource spotify = FakeSource(
        MusicSourceId.spotify,
        canStream: false,
      );
      final OnlineCatalogRepository repository = OnlineCatalogRepository(
        catalog: MusicSourceCatalog(<MusicSourceProvider>[spotify]),
        artworkCache: ArtworkCache(),
      );

      expect(
        repository.resolveStream(track('spotify:1')),
        throwsA(
          isA<MusicSourceException>()
              .having(
                (MusicSourceException error) => error.issue,
                'issue',
                MusicSourceIssue.unsupported,
              )
              .having(
                (MusicSourceException error) => error.source,
                'source',
                MusicSourceId.spotify,
              ),
        ),
      );
    });

    test('los identificadores antiguos caen al proveedor Audius', () async {
      final FakeSource audius = FakeSource(MusicSourceId.audius);
      final OnlineCatalogRepository repository = OnlineCatalogRepository(
        catalog: MusicSourceCatalog(<MusicSourceProvider>[audius]),
        artworkCache: ArtworkCache(),
      );

      await repository.resolveStream(track('legado:1'));

      expect(audius.resolveCalls, 1);
    });
  });

  group('MusicSourceErrorMapper', () {
    test('traduce errores de dominio sin perder el motivo', () {
      const MusicSourceException error = MusicSourceException(
        'Token caducado',
        source: MusicSourceId.spotify,
        issue: MusicSourceIssue.authentication,
      );

      final MusicSourceStatus status = MusicSourceErrorMapper.map(
        error,
        MusicSourceId.spotify,
      );

      expect(status.available, isFalse);
      expect(status.issue, MusicSourceIssue.authentication);
      expect(status.detail, 'Token caducado');
    });

    test('distingue autenticación, región y límite de peticiones', () {
      MusicSourceStatus statusFor(int code, Object data) {
        final RequestOptions request = RequestOptions(path: '/x');
        return MusicSourceErrorMapper.map(
          DioException(
            requestOptions: request,
            response: Response<dynamic>(
              statusCode: code,
              data: data,
              requestOptions: request,
            ),
          ),
          MusicSourceId.soundcloud,
        );
      }

      expect(
        statusFor(401, 'unauthorized').issue,
        MusicSourceIssue.authentication,
      );
      expect(
        statusFor(403, 'not available in your region').issue,
        MusicSourceIssue.region,
      );
      expect(statusFor(429, 'slow down').issue, MusicSourceIssue.rateLimited);
      expect(statusFor(503, 'down').issue, MusicSourceIssue.unavailable);
    });
  });
}
