import 'package:dio/dio.dart';

import '../../../core/services/settings_service.dart';
import '../domain/music_source.dart';
import '../domain/online_catalog_items.dart';
import '../domain/online_source_settings.dart';
import '../domain/online_track.dart';
import '../domain/request_cancellation.dart';
import 'dio_request_cancellation.dart';
import 'source_helpers.dart';

/// Proveedor de metadatos de Tidal.
///
/// Tidal no ofrece audio abierto para aplicaciones de terceros: aquí solo se
/// consulta su catálogo (con el token OAuth que el usuario introduce en
/// ajustes) y el reproductor resuelve un equivalente reproducible mediante
/// [MetadataAudioBridge], etiquetando siempre el origen real del audio.
class TidalSource
    implements MusicSourceProvider, CancellableMusicSourceProvider {
  TidalSource({required this.settings, Dio? dio, ArtworkCache? artworkCache})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 25),
            ),
          ),
      _artworkCache = artworkCache ?? ArtworkCache();

  static const String _baseUrl = 'https://api.tidal.com/v1';
  static const String _market = 'US';

  final SettingsService settings;
  final Dio _dio;
  final ArtworkCache _artworkCache;

  String? _checkedToken;
  MusicSourceStatus _status = const MusicSourceStatus();

  String? get _token {
    final String? raw = settings
        .getString(OnlineSourceSettings.tidalToken)
        ?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  @override
  MusicSourceId get id => MusicSourceId.tidal;

  @override
  bool get canSearch => true;

  @override
  bool get canTrending => false;

  @override
  bool get canStream => false;

  @override
  bool get canDownload => false;

  @override
  MusicSourceStatus get status {
    final String? token = _token;
    if (token == null) {
      return const MusicSourceStatus(
        available: false,
        issue: MusicSourceIssue.notConfigured,
        detail: 'Añade un token OAuth de Tidal para buscar en esta fuente.',
      );
    }
    if (_checkedToken != token) {
      return const MusicSourceStatus(
        available: true,
        detail: 'Token configurado. Pendiente de comprobación.',
      );
    }
    return _status;
  }

  @override
  Future<MusicSourceStatus> checkAvailability() async {
    final String? token = _token;
    if (token == null) {
      _checkedToken = null;
      _status = status;
      return status;
    }
    try {
      await _searchItems('tracks', 'polaris', 1);
      _checkedToken = token;
      _status = MusicSourceStatus(available: true, checkedAt: DateTime.now());
    } catch (error) {
      _checkedToken = token;
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
    final String term = query.trim();
    if (term.isEmpty) {
      return const SourceResult(source: MusicSourceId.tidal);
    }
    final MusicSourceStatus current = status;
    if (!current.available && current.issue == MusicSourceIssue.notConfigured) {
      return SourceResult(source: id, status: current);
    }
    try {
      final List<Object?> entries = await _searchItems(
        'tracks',
        term,
        limit,
        dioCancelTokenOf(token),
      );
      return SourceResult(source: id, items: _parseTracks(entries, limit));
    } catch (error) {
      return SourceResult(
        source: id,
        status: MusicSourceErrorMapper.map(error, id),
      );
    }
  }

  @override
  Future<SourceResult> trendingCancellable({
    int limit = 25,
    required OnlineRequestToken token,
  }) => trending(limit: limit);

  @override
  Future<SourceResult> trending({int limit = 25}) => Future<SourceResult>.value(
    const SourceResult(
      source: MusicSourceId.tidal,
      status: MusicSourceStatus(
        detail: 'Tidal no publica tendencias abiertas; usa la búsqueda.',
      ),
    ),
  );

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
    final String term = query.trim();
    if (term.isEmpty ||
        type == OnlineSearchType.songs ||
        type == OnlineSearchType.all) {
      return const <OnlineCollectionRef>[];
    }
    final MusicSourceStatus current = status;
    if (!current.available && current.issue == MusicSourceIssue.notConfigured) {
      return const <OnlineCollectionRef>[];
    }
    final String section = switch (type) {
      OnlineSearchType.albums => 'albums',
      OnlineSearchType.artists => 'artists',
      OnlineSearchType.playlists => 'playlists',
      OnlineSearchType.songs || OnlineSearchType.all => '',
    };
    try {
      final List<Object?> entries = await _searchItems(
        section,
        term,
        limit,
        dioCancelTokenOf(token),
      );
      return _parseCollections(entries, type, limit);
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
    return CollectionPage.only(
      await _collectionTracks(collection, limit: limit, token: token),
    );
  }

  Future<List<OnlineTrack>> _collectionTracks(
    OnlineCollectionRef collection, {
    int limit = 50,
    OnlineRequestToken? token,
  }) async {
    if (collection.id.isEmpty) return const <OnlineTrack>[];
    final String path = switch (collection.kind) {
      OnlineSearchType.artists =>
        '/artists/${Uri.encodeComponent(collection.id)}/toptracks',
      OnlineSearchType.albums =>
        '/albums/${Uri.encodeComponent(collection.id)}/tracks',
      _ => '/playlists/${Uri.encodeComponent(collection.id)}/items',
    };
    try {
      final Response<dynamic> response = await _get(path, <String, dynamic>{
        'limit': limit,
        'countryCode': _market,
      }, dioCancelTokenOf(token));
      final Map<String, dynamic>? payload = SourceJson.map(response.data);
      final List<Object?> entries = SourceJson.list(payload?['items']);
      final List<Object?> tracks = collection.kind == OnlineSearchType.playlists
          ? entries
                .map((Object? entry) => SourceJson.map(entry)?['item'])
                .toList(growable: false)
          : entries;
      return _parseTracks(tracks, limit);
    } on Object {
      return const <OnlineTrack>[];
    }
  }

  @override
  Future<ResolvedStream> resolveStream(OnlineTrack track) => Future.error(
    const MusicSourceException(
      'Tidal no permite reproducir ni descargar audio fuera de sus SDK '
      'oficiales. Buscamos una versión reproducible equivalente.',
      source: MusicSourceId.tidal,
      issue: MusicSourceIssue.unsupported,
    ),
  );

  @override
  Future<String?> cacheArtwork(String? artworkUrl) =>
      _artworkCache.cache(artworkUrl, id);

  Future<List<Object?>> _searchItems(
    String section,
    String query,
    int limit, [
    CancelToken? cancel,
  ]) async {
    final Response<dynamic> response = await _get('/search', <String, dynamic>{
      'query': query,
      'types': section.toUpperCase(),
      'limit': limit,
      'countryCode': _market,
    }, cancel);
    final Map<String, dynamic>? payload = SourceJson.map(response.data);
    final Map<String, dynamic>? page = SourceJson.map(payload?[section]);
    return SourceJson.list(page?['items'] ?? payload?['items']);
  }

  Future<Response<dynamic>> _get(
    String path, [
    Map<String, dynamic>? query,
    CancelToken? cancel,
  ]) {
    final String? token = _token;
    if (token == null) {
      throw const MusicSourceException(
        'Falta el token de Tidal.',
        source: MusicSourceId.tidal,
        issue: MusicSourceIssue.notConfigured,
      );
    }
    return _dio.get<dynamic>(
      '$_baseUrl$path',
      queryParameters: query,
      cancelToken: cancel,
      options: Options(
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'X-Tidal-Token': token,
          'Accept': 'application/json',
        },
      ),
    );
  }

  List<OnlineTrack> _parseTracks(List<Object?> entries, int limit) {
    final List<OnlineTrack> tracks = <OnlineTrack>[];
    for (final Object? entry in entries) {
      if (tracks.length >= limit) break;
      final Map<String, dynamic>? json = SourceJson.map(entry);
      if (json == null) continue;
      final String id = SourceJson.text(json['id']);
      final String title = SourceJson.text(json['title']);
      if (id.isEmpty || title.isEmpty) continue;
      final Map<String, dynamic>? artist = SourceJson.map(json['artist']);
      final Map<String, dynamic>? album = SourceJson.map(json['album']);
      final int seconds = SourceJson.integer(json['duration']);
      tracks.add(
        OnlineTrack(
          externalId: 'tidal:$id',
          sourceId: id,
          title: title,
          artist: SourceJson.text(artist?['name']).isEmpty
              ? 'Desconocido'
              : SourceJson.text(artist?['name']),
          album: SourceJson.text(album?['title']),
          durationMs: seconds * 1000,
          artworkUrl: _cover(json['cover'] ?? album?['cover']),
          permalink: 'https://tidal.com/browse/track/$id',
          sourceLabel: 'Tidal',
        ),
      );
    }
    return tracks;
  }

  List<OnlineCollectionRef> _parseCollections(
    List<Object?> entries,
    OnlineSearchType type,
    int limit,
  ) {
    final List<OnlineCollectionRef> result = <OnlineCollectionRef>[];
    for (final Object? entry in entries) {
      if (result.length >= limit) break;
      final Map<String, dynamic>? json = SourceJson.map(entry);
      if (json == null) continue;
      final String id = SourceJson.text(json['id']);
      final String title =
          SourceJson.text(json['title']) + SourceJson.text(json['name']);
      if (id.isEmpty || title.isEmpty) continue;
      final Map<String, dynamic>? artist = SourceJson.map(json['artist']);
      result.add(
        OnlineCollectionRef(
          externalId: 'tidal:${type.name}:$id',
          id: id,
          title: title,
          subtitle: SourceJson.text(json['name']).isNotEmpty
              ? SourceJson.text(json['name'])
              : SourceJson.text(artist?['name']),
          artworkUrl: _cover(json['cover']),
          permalink: 'https://tidal.com/browse/${type.name}/$id',
          source: MusicSourceId.tidal,
          kind: type,
          trackCount: SourceJson.integer(
            json['numberOfTracks'] ?? json['numberOfItems'],
          ),
        ),
      );
    }
    return result;
  }

  static String? _cover(Object? value) {
    final String uuid = SourceJson.text(value);
    if (uuid.isEmpty) return null;
    return 'https://resources.tidal.com/images/'
        '${uuid.replaceAll('-', '/')}/640x640.jpg';
  }
}
