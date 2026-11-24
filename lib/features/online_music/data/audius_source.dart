import '../domain/music_source.dart';
import '../domain/online_catalog_items.dart';
import '../domain/online_track.dart';
import '../domain/request_cancellation.dart';
import 'dio_request_cancellation.dart';
import 'online_music_service.dart';
import 'source_helpers.dart';

/// Adaptador del catálogo abierto de Audius al contrato de proveedores.
///
/// Audius no requiere credenciales y entrega audio reproducible, por lo que es
/// la fuente por defecto de la aplicación.
class AudiusSource
    implements MusicSourceProvider, CancellableMusicSourceProvider {
  AudiusSource(this._repository);

  final OnlineMusicService _repository;

  MusicSourceStatus _status = const MusicSourceStatus();

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
  MusicSourceStatus get status => _status;

  @override
  Future<MusicSourceStatus> checkAvailability() async {
    try {
      await _repository.trending(limit: 1);
      _status = const MusicSourceStatus(
        available: true,
        checkedAt: null,
      ).copyWith(checkedAt: DateTime.now());
    } catch (error) {
      _status = MusicSourceErrorMapper.map(error, id);
    }
    return _status;
  }

  @override
  Future<SourceResult> search(String query, {int limit = 25}) =>
      _search(query, limit: limit);

  @override
  Future<SourceResult> searchCancellable(
    String query, {
    int limit = 25,
    required OnlineRequestToken token,
  }) {
    token.throwIfCancelled();
    return _search(query, limit: limit, token: token);
  }

  Future<SourceResult> _search(
    String query, {
    int limit = 25,
    OnlineRequestToken? token,
  }) async {
    try {
      return SourceResult(
        source: id,
        items: await _repository.search(
          query,
          limit: limit,
          cancel: dioCancelTokenOf(token),
        ),
      );
    } on RequestCanceledException {
      rethrow;
    } catch (error) {
      return SourceResult(
        source: id,
        status: MusicSourceErrorMapper.map(error, id),
      );
    }
  }

  @override
  Future<SourceResult> trending({int limit = 25}) => _trending(limit: limit);

  @override
  Future<SourceResult> trendingCancellable({
    int limit = 25,
    required OnlineRequestToken token,
  }) {
    token.throwIfCancelled();
    return _trending(limit: limit, token: token);
  }

  Future<SourceResult> _trending({
    int limit = 25,
    OnlineRequestToken? token,
  }) async {
    try {
      return SourceResult(
        source: id,
        items: await _repository.trending(
          limit: limit,
          cancel: dioCancelTokenOf(token),
        ),
      );
    } on RequestCanceledException {
      rethrow;
    } catch (error) {
      return SourceResult(
        source: id,
        status: MusicSourceErrorMapper.map(error, id),
      );
    }
  }

  @override
  Future<List<OnlineCollectionRef>> searchCollections(
    String query, {
    required OnlineSearchType type,
    int limit = 25,
  }) => _searchCollections(query, type: type, limit: limit);

  @override
  Future<List<OnlineCollectionRef>> searchCollectionsCancellable(
    String query, {
    required OnlineSearchType type,
    int limit = 25,
    required OnlineRequestToken token,
  }) {
    token.throwIfCancelled();
    return _searchCollections(query, type: type, limit: limit, token: token);
  }

  Future<List<OnlineCollectionRef>> _searchCollections(
    String query, {
    required OnlineSearchType type,
    int limit = 25,
    OnlineRequestToken? token,
  }) async {
    try {
      return await _repository.searchCollections(
        query,
        type: type,
        limit: limit,
        cancel: dioCancelTokenOf(token),
      );
    } on RequestCanceledException {
      rethrow;
    } on Object {
      return const <OnlineCollectionRef>[];
    }
  }

  @override
  Future<List<OnlineTrack>> collectionTracks(
    OnlineCollectionRef collection, {
    int limit = 50,
  }) => _collectionTracks(collection, limit: limit);

  @override
  Future<CollectionPage> collectionPage(
    OnlineCollectionRef collection, {
    String? continuation,
    int limit = 50,
    required OnlineRequestToken token,
  }) async {
    token.throwIfCancelled();
    // Audius no entrega tokens de continuación: una sola página basta.
    return CollectionPage.only(
      await _collectionTracks(collection, limit: limit, token: token),
    );
  }

  Future<List<OnlineTrack>> _collectionTracks(
    OnlineCollectionRef collection, {
    int limit = 50,
    OnlineRequestToken? token,
  }) async {
    try {
      return await _repository.collectionTracks(
        collection,
        limit: limit,
        cancel: dioCancelTokenOf(token),
      );
    } on RequestCanceledException {
      rethrow;
    } on Object {
      return const <OnlineTrack>[];
    }
  }

  @override
  Future<ResolvedStream> resolveStream(OnlineTrack track) =>
      _repository.resolveStream(track);

  @override
  Future<String?> cacheArtwork(String? artworkUrl) =>
      _repository.cacheArtwork(artworkUrl);
}
