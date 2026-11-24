import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart' as fake_async;
import 'package:polaris_music/features/online_music/domain/music_source.dart';
import 'package:polaris_music/features/online_music/domain/music_source_catalog.dart';
import 'package:polaris_music/features/online_music/domain/online_catalog_items.dart';
import 'package:polaris_music/features/online_music/domain/online_track.dart';
import 'package:polaris_music/features/online_music/domain/request_cancellation.dart';
import 'package:polaris_music/features/online_music/presentation/online_music_providers.dart';

import 'support/fake_settings_service.dart';

OnlineTrack _track(String id, String title) => OnlineTrack(
  externalId: 'audius:$id',
  sourceId: id,
  title: title,
  artist: 'Artista',
  durationMs: 1000,
);

class _FakeToken implements OnlineRequestToken {
  bool _cancelled = false;
  int cancelCalls = 0;

  @override
  bool get isCancelled => _cancelled;

  @override
  void cancel() {
    _cancelled = true;
    cancelCalls++;
  }

  @override
  void throwIfCancelled() {
    if (_cancelled) throw const RequestCanceledException();
  }
}

class _FakeCancellation implements OnlineRequestCancellation {
  final List<_FakeToken> issued = <_FakeToken>[];

  @override
  OnlineRequestToken issue() {
    final _FakeToken token = _FakeToken();
    issued.add(token);
    return token;
  }

  int get cancelledTokens =>
      issued.where((_FakeToken token) => token.isCancelled).length;
}

/// Proveedor controlable: permite decidir si una respuesta obsoleta llega
/// tarde (para probar la generación) o si se cancela HTTP (para probar que no
/// se convierte en error de red).
class _FakeProvider
    implements MusicSourceProvider, CancellableMusicSourceProvider {
  _FakeProvider({this.throwOnCancel = false});

  final bool throwOnCancel;
  final Map<String, Completer<SourceResult>> gates =
      <String, Completer<SourceResult>>{};
  final List<String> searchQueries = <String>[];
  final List<OnlineSearchType> collectionTypes = <OnlineSearchType>[];
  int trendingCalls = 0;

  OnlineCollectionRef collection = OnlineCollectionRef(
    externalId: 'audius:album-1',
    id: 'album-1',
    title: 'Álbum demo',
    source: MusicSourceId.audius,
    kind: OnlineSearchType.albums,
  );

  @override
  MusicSourceId get id => MusicSourceId.audius;

  @override
  bool get canSearch => true;

  @override
  bool get canTrending => true;

  @override
  bool get canStream => true;

  @override
  bool get canDownload => true;

  @override
  MusicSourceStatus get status => const MusicSourceStatus();

  @override
  Future<MusicSourceStatus> checkAvailability() async => status;

  Future<SourceResult> _guard(OnlineRequestToken token) async {
    if (throwOnCancel && token.isCancelled) {
      throw const RequestCanceledException();
    }
    return SourceResult(source: id);
  }

  @override
  Future<SourceResult> search(String query, {int limit = 25}) =>
      searchCancellable(
        query,
        limit: limit,
        token: const NoOpOnlineRequestToken(),
      );

  @override
  Future<SourceResult> searchCancellable(
    String query, {
    int limit = 25,
    required OnlineRequestToken token,
  }) {
    searchQueries.add(query);
    final Completer<SourceResult>? gate = gates[query];
    if (gate != null) {
      return gate.future.then((SourceResult value) async {
        if (token.isCancelled && throwOnCancel) {
          throw const RequestCanceledException();
        }
        return value;
      });
    }
    return Future<SourceResult>.value(
      SourceResult(source: id, items: <OnlineTrack>[_track(query, query)]),
    );
  }

  @override
  Future<SourceResult> trending({int limit = 25}) =>
      trendingCancellable(limit: limit, token: const NoOpOnlineRequestToken());

  @override
  Future<SourceResult> trendingCancellable({
    int limit = 25,
    required OnlineRequestToken token,
  }) async {
    trendingCalls++;
    await _guard(token);
    return SourceResult(source: id, items: <OnlineTrack>[_track('pop', 'Pop')]);
  }

  @override
  Future<List<OnlineCollectionRef>> searchCollections(
    String query, {
    required OnlineSearchType type,
    int limit = 25,
  }) => searchCollectionsCancellable(
    query,
    type: type,
    limit: limit,
    token: const NoOpOnlineRequestToken(),
  );

  @override
  Future<List<OnlineCollectionRef>> searchCollectionsCancellable(
    String query, {
    required OnlineSearchType type,
    int limit = 25,
    required OnlineRequestToken token,
  }) async {
    collectionTypes.add(type);
    await _guard(token);
    return <OnlineCollectionRef>[collection];
  }

  @override
  Future<List<OnlineTrack>> collectionTracks(
    OnlineCollectionRef collection, {
    int limit = 50,
  }) async => <OnlineTrack>[];

  @override
  Future<CollectionPage> collectionPage(
    OnlineCollectionRef collection, {
    String? continuation,
    int limit = 50,
    required OnlineRequestToken token,
  }) async {
    await _guard(token);
    return CollectionPage(
      tracks: <OnlineTrack>[_track('page-1', 'Página 1')],
      continuation: 'next-page',
      hasMore: true,
    );
  }

  @override
  Future<ResolvedStream> resolveStream(OnlineTrack track) async =>
      const ResolvedStream(url: 'https://example.invalid/audio.mp3');

  @override
  Future<String?> cacheArtwork(String? artworkUrl) async => null;
}

class _Harness {
  _Harness({bool throwOnCancel = false}) {
    provider = _FakeProvider(throwOnCancel: throwOnCancel);
    cancellation = _FakeCancellation();
    controller = OnlineSearchController(
      MusicSourceCatalog(<MusicSourceProvider>[provider]),
      FakeSettingsService(),
      cancellation: cancellation,
    );
  }

  late final _FakeProvider provider;
  late final _FakeCancellation cancellation;
  late final OnlineSearchController controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // `fakeAsync` es transitivo de `test` y no puede añadirse a un pubspec que
  // otros agentes están modificando; el analizador avisa solo por el imports.
  // ignore_for_file: depend_on_referenced_packages

  group('OnlineSearchController (cancelación y paginación)', () {
    test('debounce de 450 ms y generación descarta respuesta obsoleta', () {
      fake_async.fakeAsync((fake_async.FakeAsync async) {
        final _Harness harness = _Harness();
        final OnlineSearchController controller = harness.controller;
        async.flushMicrotasks();
        expect(harness.provider.trendingCalls, 1);

        final Completer<SourceResult> first = Completer<SourceResult>();
        final Completer<SourceResult> second = Completer<SourceResult>();
        harness.provider.gates['primera'] = first;
        harness.provider.gates['segunda'] = second;

        controller.onQueryChanged('primera');
        async.elapse(const Duration(milliseconds: 449));
        async.flushMicrotasks();
        expect(harness.provider.searchQueries, isEmpty);

        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();
        expect(harness.provider.searchQueries, <String>['primera']);

        controller.onQueryChanged('segunda');
        expect(harness.cancellation.cancelledTokens, greaterThanOrEqualTo(1));
        async.elapse(const Duration(milliseconds: 450));
        async.flushMicrotasks();
        expect(harness.provider.searchQueries, <String>['primera', 'segunda']);

        first.complete(
          SourceResult(
            source: MusicSourceId.audius,
            items: <OnlineTrack>[_track('old', 'Respuesta obsoleta')],
          ),
        );
        async.flushMicrotasks();
        expect(
          controller.state.tracks.map((OnlineTrack t) => t.title),
          isNot(contains('Respuesta obsoleta')),
        );

        second.complete(
          SourceResult(
            source: MusicSourceId.audius,
            items: <OnlineTrack>[_track('new', 'Respuesta vigente')],
          ),
        );
        async.flushMicrotasks();
        expect(controller.state.tracks.single.title, 'Respuesta vigente');
        expect(controller.state.error, isNull);
        controller.dispose();
      });
    });

    test('cancelación HTTP no se muestra como error de red', () {
      fake_async.fakeAsync((fake_async.FakeAsync async) {
        final _Harness harness = _Harness(throwOnCancel: true);
        final OnlineSearchController controller = harness.controller;
        async.flushMicrotasks();

        final Completer<SourceResult> stale = Completer<SourceResult>();
        harness.provider.gates['uno'] = stale;
        controller.onQueryChanged('uno');
        async.elapse(const Duration(milliseconds: 450));
        async.flushMicrotasks();

        controller.onQueryChanged('dos');
        async.elapse(const Duration(milliseconds: 450));
        async.flushMicrotasks();

        stale.completeError(const RequestCanceledException());
        async.flushMicrotasks();
        expect(controller.state.error, isNull);
        expect(controller.state.issues, isEmpty);
        controller.dispose();
      });
    });

    test('cambio de tipo consulta colecciones y mantiene la pestaña', () {
      fake_async.fakeAsync((fake_async.FakeAsync async) {
        final _Harness harness = _Harness();
        final OnlineSearchController controller = harness.controller;
        async.flushMicrotasks();

        controller.setResultType(OnlineSearchType.albums);
        async.flushMicrotasks();

        expect(controller.state.resultType, OnlineSearchType.albums);
        expect(
          harness.provider.collectionTypes,
          contains(OnlineSearchType.albums),
        );
        expect(controller.state.collections.single.title, 'Álbum demo');
        controller.dispose();
      });
    });

    test('Cargar más concatena sin duplicar y conserva la continuación', () {
      fake_async.fakeAsync((fake_async.FakeAsync async) {
        final _Harness harness = _Harness();
        final OnlineSearchController controller = harness.controller;
        async.flushMicrotasks();

        final OnlineCollectionRef collection = harness.provider.collection;
        controller.openCollection(collection);
        async.flushMicrotasks();
        expect(controller.state.tracks.single.title, 'Página 1');
        expect(controller.state.collectionHasMore, isTrue);

        controller.loadMoreCollection();
        async.flushMicrotasks();
        expect(
          controller.state.tracks.map((OnlineTrack t) => t.externalId),
          <String>['audius:page-1'],
        );
        expect(controller.state.collectionContinuation, 'next-page');
        expect(controller.state.loadMoreError, isNull);
        controller.dispose();
      });
    });
  });
}
