import 'package:dio/dio.dart';

import '../../../core/services/settings_service.dart';
import '../domain/music_source.dart';
import '../domain/online_catalog_items.dart';
import '../domain/online_source_settings.dart';
import '../domain/online_track.dart';
import '../domain/request_cancellation.dart';
import 'dio_request_cancellation.dart';
import 'source_helpers.dart';

/// Proveedor de metadatos de Spotify mediante Web API.
///
/// Spotify no permite descargar ni reproducir su audio fuera de sus SDK y
/// exige atribución, por lo que esta fuente busca y muestra canciones, pero
/// desactiva explícitamente streaming y descarga. El token se introduce en
/// ajustes (OAuth de la app del usuario); nunca se guarda un `client_secret`.
class SpotifySource
    implements MusicSourceProvider, CancellableMusicSourceProvider {
  SpotifySource({required this.settings, Dio? dio, ArtworkCache? artworkCache})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 25),
            ),
          ),
      _artworkCache = artworkCache ?? ArtworkCache();

  static const String _baseUrl = 'https://api.spotify.com/v1';

  final SettingsService settings;
  final Dio _dio;
  final ArtworkCache _artworkCache;

  String? _checkedToken;
  MusicSourceStatus _status = const MusicSourceStatus();

  String? get _token {
    final String? raw = settings
        .getString(OnlineSourceSettings.spotifyToken)
        ?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  String get _market {
    final String market = settings
        .stringOr(
          OnlineSourceSettings.spotifyMarket,
          OnlineSourceSettings.defaultSpotifyMarket,
        )
        .trim();
    return market.isEmpty ? OnlineSourceSettings.defaultSpotifyMarket : market;
  }

  @override
  MusicSourceId get id => MusicSourceId.spotify;

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
        detail: 'Añade un token OAuth de Spotify para buscar en esta fuente.',
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
      await _get('/search', <String, dynamic>{
        'q': 'polaris',
        'type': 'track',
        'limit': 1,
        'market': _market,
      });
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
    final MusicSourceStatus current = status;
    if (!current.available && current.issue == MusicSourceIssue.notConfigured) {
      return SourceResult(source: id, status: current);
    }
    try {
      final Response<dynamic> response = await _get(
        '/search',
        <String, dynamic>{
          'q': query.trim(),
          'type': 'track',
          'limit': limit,
          'market': _market,
        },
        dioCancelTokenOf(token),
      );
      final Map<String, dynamic>? payload = SourceJson.map(response.data);
      final Map<String, dynamic>? tracks = SourceJson.map(payload?['tracks']);
      return SourceResult(
        source: id,
        items: _parseTracks(SourceJson.list(tracks?['items']), limit),
      );
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
    SourceResult(
      source: id,
      status: const MusicSourceStatus(
        available: false,
        issue: MusicSourceIssue.unsupported,
        detail:
            'Spotify no publica un endpoint de tendencias para terceros; '
            'busca por título o artista para ver resultados.',
      ),
    ),
  );

  /// Las colecciones se consultan con el mismo token OAuth; Spotify solo
  /// entrega metadatos, pero son útiles como entrada al puente de audio.
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
    if (query.trim().isEmpty ||
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
      final Response<dynamic> response = await _get(
        '/search',
        <String, dynamic>{
          'q': query.trim(),
          'type': section,
          'limit': limit,
          'market': _market,
        },
        dioCancelTokenOf(token),
      );
      final Map<String, dynamic>? payload = SourceJson.map(response.data);
      final Map<String, dynamic>? page = SourceJson.map(payload?[section]);
      return _parseCollections(SourceJson.list(page?['items']), type, limit);
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
    try {
      final Response<dynamic> response = await _get(
        switch (collection.kind) {
          OnlineSearchType.artists =>
            '/artists/${Uri.encodeComponent(collection.id)}/top-tracks',
          OnlineSearchType.albums =>
            '/albums/${Uri.encodeComponent(collection.id)}/tracks',
          _ => '/playlists/${Uri.encodeComponent(collection.id)}/tracks',
        },
        <String, dynamic>{'market': _market, 'limit': limit},
        dioCancelTokenOf(token),
      );
      final Map<String, dynamic>? payload = SourceJson.map(response.data);
      final List<Object?> items = collection.kind == OnlineSearchType.artists
          ? SourceJson.list(payload?['tracks'])
          : SourceJson.list(payload?['items']);
      final List<Object?> tracks = collection.kind == OnlineSearchType.playlists
          ? items
                .map((Object? entry) => SourceJson.map(entry)?['track'])
                .toList(growable: false)
          : items;
      return _parseTracks(tracks, limit);
    } on Object {
      return const <OnlineTrack>[];
    }
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
      final String title = SourceJson.text(json['name']);
      if (id.isEmpty || title.isEmpty) continue;

      final List<Object?> images = SourceJson.list(json['images']);
      final String? artwork = images.isEmpty
          ? null
          : SourceJson.url(SourceJson.map(images.first)?['url']);
      final List<Object?> artists = SourceJson.list(json['artists']);
      final String artist = artists.isEmpty
          ? ''
          : SourceJson.text(SourceJson.map(artists.first)?['name']);
      final Map<String, dynamic>? owner = SourceJson.map(json['owner']);
      final String subtitle = artist.isNotEmpty
          ? artist
          : SourceJson.text(owner?['display_name']);
      final Map<String, dynamic>? tracks = SourceJson.map(json['tracks']);
      final Map<String, dynamic>? external = SourceJson.map(
        json['external_urls'],
      );
      result.add(
        OnlineCollectionRef(
          externalId: 'spotify:${type.name}:$id',
          id: id,
          title: title.trim(),
          subtitle: subtitle,
          artworkUrl: artwork,
          permalink: SourceJson.url(external?['spotify']),
          source: MusicSourceId.spotify,
          kind: type,
          trackCount: SourceJson.integer(
            json['total_tracks'] ?? tracks?['total'],
          ),
        ),
      );
    }
    return result;
  }

  @override
  Future<ResolvedStream> resolveStream(OnlineTrack track) => Future.error(
    const MusicSourceException(
      'Spotify no permite reproducir ni descargar audio fuera de sus SDK '
      'oficiales. Abre la pista en Spotify desde el enlace del resultado.',
      source: MusicSourceId.spotify,
      issue: MusicSourceIssue.unsupported,
    ),
  );

  @override
  Future<String?> cacheArtwork(String? artworkUrl) =>
      _artworkCache.cache(artworkUrl, id);

  Future<Response<dynamic>> _get(
    String path, [
    Map<String, dynamic>? query,
    CancelToken? cancel,
  ]) {
    final String? token = _token;
    if (token == null) {
      throw const MusicSourceException(
        'Falta el token de Spotify.',
        source: MusicSourceId.spotify,
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
      if (json == null || SourceJson.text(json['is_local']) == 'true') continue;
      final String id = SourceJson.text(json['id']);
      final String title = SourceJson.text(json['name']);
      if (id.isEmpty || title.isEmpty) continue;

      final List<Object?> artists = SourceJson.list(json['artists']);
      final String artist = artists.isEmpty
          ? 'Desconocido'
          : SourceJson.text(SourceJson.map(artists.first)?['name']);
      final Map<String, dynamic>? album = SourceJson.map(json['album']);
      final List<Object?> images = SourceJson.list(album?['images']);
      final String? artwork = images.isEmpty
          ? null
          : SourceJson.url(SourceJson.map(images.first)?['url']);
      final Map<String, dynamic>? external = SourceJson.map(
        json['external_urls'],
      );

      tracks.add(
        OnlineTrack(
          externalId: 'spotify:$id',
          sourceId: id,
          title: title,
          artist: artist.isEmpty ? 'Desconocido' : artist,
          album: SourceJson.text(album?['name']),
          durationMs: SourceJson.integer(json['duration_ms']),
          artworkUrl: artwork,
          permalink: SourceJson.url(external?['spotify']),
          sourceLabel: 'Spotify',
          playCount: SourceJson.integer(json['popularity']),
        ),
      );
    }
    return tracks;
  }
}
