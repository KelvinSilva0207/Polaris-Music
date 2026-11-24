import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/models/track.dart';
import 'package:polaris_music/features/online_music/data/source_helpers.dart';
import 'package:polaris_music/features/online_music/domain/music_source.dart';
import 'package:polaris_music/features/online_music/domain/online_catalog_items.dart';
import 'package:polaris_music/features/online_music/domain/online_music_repository.dart';
import 'package:polaris_music/features/online_music/domain/online_track.dart';
import 'package:polaris_music/features/online_music/domain/request_cancellation.dart';
import 'package:polaris_music/features/online_music/domain/stream_retry.dart';
import 'package:polaris_music/features/online_music/domain/stream_track_use_case.dart';

class FakeStreamRepository implements OnlineMusicRepository {
  FakeStreamRepository({this.transientFailures = 0, this.artworkFails = false});

  int transientFailures;
  final bool artworkFails;
  int resolveCalls = 0;
  int artworkCalls = 0;

  static const String freshUrl = 'https://cdn.example/fresh.m4a';

  @override
  Future<ResolvedStream> resolveStream(OnlineTrack track) async {
    resolveCalls++;
    if (resolveCalls <= transientFailures) {
      throw MusicSourceException(
        'HTTP 403',
        source: MusicSourceId.youtube,
        issue: MusicSourceIssue.unavailable,
      );
    }
    return ResolvedStream(
      url: freshUrl,
      httpHeaders: const <String, String>{'User-Agent': 'test-client'},
      alternatives: const <StreamAlternative>[
        StreamAlternative(
          url: 'https://cdn.example/alt.m4a',
          httpHeaders: <String, String>{'User-Agent': 'alt-client'},
          label: 'ANDROID_MUSIC',
        ),
      ],
    );
  }

  @override
  Future<String?> cacheArtworkFor(OnlineTrack track) async {
    artworkCalls++;
    if (artworkFails) throw StateError('sin carátula');
    return 'cover.jpg';
  }

  @override
  Future<String?> cacheArtwork(String? artworkUrl) async => 'cover.jpg';

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 25}) async =>
      <OnlineTrack>[];

  @override
  Future<List<OnlineTrack>> trending({int limit = 25}) async => <OnlineTrack>[];

  @override
  bool canStreamTrack(OnlineTrack track) => true;

  @override
  bool canDownloadTrack(OnlineTrack track) => false;

  @override
  Future<List<OnlineTrack>> collectionTracks(
    OnlineCollectionRef collection, {
    int limit = 50,
  }) async => <OnlineTrack>[];

  @override
  Future<List<OnlineTrack>> searchCancellable(
    String query, {
    int limit = 25,
    required OnlineRequestToken token,
  }) => search(query, limit: limit);

  @override
  Future<List<OnlineTrack>> trendingCancellable({
    int limit = 25,
    required OnlineRequestToken token,
  }) => trending(limit: limit);

  @override
  Future<CollectionPage> collectionPage(
    OnlineCollectionRef collection, {
    String? continuation,
    int limit = 50,
    required OnlineRequestToken token,
  }) async =>
      CollectionPage.only(await collectionTracks(collection, limit: limit));
}

OnlineTrack get _track => const OnlineTrack(
  externalId: 'youtube:abc123',
  sourceId: 'abc123',
  title: 'Luna',
  artist: 'Kelvin',
  durationMs: 180000,
);

void main() {
  group('ResilientStreamResolver', () {
    test('reintenta un 403 y devuelve la URL vigente', () async {
      final FakeStreamRepository repo = FakeStreamRepository(
        transientFailures: 1,
      );
      final ResilientStreamResolver resolver = ResilientStreamResolver(
        repo,
        policy: const StreamRetryPolicy(attempts: 2, delay: Duration.zero),
      );

      final ResolvedAudio result = await resolver.resolve(_track);

      expect(repo.resolveCalls, 2);
      expect(result.stream.url, FakeStreamRepository.freshUrl);
      expect(result.artworkPath, 'cover.jpg');
    });

    test('un fallo de carátula nunca impide obtener el audio', () async {
      final FakeStreamRepository repo = FakeStreamRepository(
        artworkFails: true,
      );
      final ResilientStreamResolver resolver = ResilientStreamResolver(repo);

      final ResolvedAudio result = await resolver.resolve(_track);

      expect(result.stream.url, FakeStreamRepository.freshUrl);
      expect(result.artworkPath, isNull);
    });

    test('no reintenta un error de región', () async {
      final FakeStreamRepository repo = FakeStreamRepository();
      final ResilientStreamResolver resolver = ResilientStreamResolver(repo);
      final StreamRetryPolicy policy = resolver.policy;

      expect(
        policy.isTransient(
          MusicSourceException(
            'Bloqueado',
            source: MusicSourceId.youtube,
            issue: MusicSourceIssue.region,
          ),
        ),
        isFalse,
      );
      expect(repo.resolveCalls, 0);
    });
  });

  group('StreamTrackUseCase.refresh', () {
    test(
      'reconstruye el sourceId desde externalId y conserva las alternativas',
      () async {
        final FakeStreamRepository repo = FakeStreamRepository();
        final StreamTrackUseCase useCase = StreamTrackUseCase(repo);
        final Track playable = _track.toTrack(
          streamUrl: 'https://cdn.example/expired.m4a',
          artworkPath: 'cover.jpg',
        );

        final Track? fresh = await useCase.refresh(playable);

        expect(fresh, isNotNull);
        expect(fresh!.path, FakeStreamRepository.freshUrl);
        expect(fresh.externalId, 'youtube:abc123');
        expect(fresh.id, playable.id);
        expect(fresh.streamAlternatives, hasLength(1));
        expect(fresh.httpHeaders['User-Agent'], 'test-client');
      },
    );
  });
}
