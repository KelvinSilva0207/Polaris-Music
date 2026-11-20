import 'package:dio/dio.dart';

import '../../../core/services/settings_service.dart';
import '../domain/music_source.dart';
import '../domain/online_catalog_items.dart';
import '../domain/online_source_settings.dart';
import '../domain/online_track.dart';
import 'source_helpers.dart';

/// Proveedor de SoundCloud usando la API v2 oficial.
///
/// SoundCloud exige una app registrada y un token OAuth; el secreto de cliente
/// no se distribuye con la app. El usuario pega su token en ajustes y esta
/// clase lo usa solo en memoria persistida localmente. Las pistas `blocked`
/// (región, suscripción o autor) se descartan o se informan como estado.
class SoundCloudSource implements MusicSourceProvider {
  SoundCloudSource({
    required this.settings,
    Dio? dio,
    ArtworkCache? artworkCache,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 12),
               receiveTimeout: const Duration(seconds: 25),
             ),
           ),
       _artworkCache = artworkCache ?? ArtworkCache();

  static const String _baseUrl = 'https://api.soundcloud.com';

  final SettingsService settings;
  final Dio _dio;
  final ArtworkCache _artworkCache;

  String? _checkedToken;
  MusicSourceStatus _status = const MusicSourceStatus();

  String? get _token {
    final String? raw = settings
        .getString(OnlineSourceSettings.soundCloudToken)
        ?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  @override
  MusicSourceId get id => MusicSourceId.soundcloud;

  @override
  bool get canSearch => true;

  @override
  bool get canTrending => true;

  @override
  bool get canStream => true;

  @override
  bool get canDownload => true;

  @override
  MusicSourceStatus get status {
    final String? token = _token;
    if (token == null) {
      return const MusicSourceStatus(
        available: false,
        issue: MusicSourceIssue.notConfigured,
        detail:
            'Añade un token OAuth de SoundCloud para buscar en esta fuente.',
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
      await _get('/tracks', <String, dynamic>{
        'q': 'test',
        'access': 'playable',
        'limit': 1,
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
  Future<SourceResult> search(String query, {int limit = 25}) async {
    final MusicSourceStatus current = status;
    if (!current.available && current.issue == MusicSourceIssue.notConfigured) {
      return SourceResult(source: id, status: current);
    }
    try {
      final Response<dynamic> response = await _get(
        '/tracks',
        <String, dynamic>{
          'q': query.trim(),
          'access': 'playable',
          'limit': limit,
        },
      );
      return SourceResult(
        source: id,
        items: _parseTracks(response.data, limit),
      );
    } catch (error) {
      return SourceResult(
        source: id,
        status: MusicSourceErrorMapper.map(error, id),
      );
    }
  }

  @override
  Future<SourceResult> trending({int limit = 25}) async {
    final MusicSourceStatus current = status;
    if (!current.available && current.issue == MusicSourceIssue.notConfigured) {
      return SourceResult(source: id, status: current);
    }
    try {
      Response<dynamic> response;
      try {
        response = await _get('/charts/tracks', <String, dynamic>{
          'limit': limit,
          'access': 'playable',
        });
      } on DioException catch (error) {
        // Algunas cuentas no tienen acceso al género "charts"; se usa el
        // catálogo reproducible ordinario como lista de descubrimiento.
        if (error.response?.statusCode != 404) rethrow;
        response = await _get('/tracks', <String, dynamic>{
          'access': 'playable',
          'limit': limit,
        });
      }
      return SourceResult(
        source: id,
        items: _parseTracks(response.data, limit),
      );
    } catch (error) {
      return SourceResult(
        source: id,
        status: MusicSourceErrorMapper.map(error, id),
      );
    }
  }

  /// SoundCloud no tiene un índice de álbumes propio: las playlists marcadas
  /// como `is_album` se muestran en Álbumes y el resto en Playlists.
  @override
  Future<List<OnlineCollectionRef>> searchCollections(
    String query, {
    required OnlineSearchType type,
    int limit = 25,
  }) async {
    if (query.trim().isEmpty || type == OnlineSearchType.songs) {
      return const <OnlineCollectionRef>[];
    }
    final MusicSourceStatus current = status;
    if (!current.available && current.issue == MusicSourceIssue.notConfigured) {
      return const <OnlineCollectionRef>[];
    }
    try {
      final Response<dynamic> response = await _get(
        type == OnlineSearchType.artists ? '/users' : '/playlists',
        <String, dynamic>{'q': query.trim(), 'limit': limit},
      );
      return _parseCollections(response.data, type, limit);
    } on Object {
      return const <OnlineCollectionRef>[];
    }
  }

  @override
  Future<List<OnlineTrack>> collectionTracks(
    OnlineCollectionRef collection, {
    int limit = 50,
  }) async {
    if (collection.id.isEmpty) return const <OnlineTrack>[];
    try {
      final Response<dynamic> response = await _get(
        collection.kind == OnlineSearchType.artists
            ? '/users/${Uri.encodeComponent(collection.id)}/tracks'
            : '/playlists/${Uri.encodeComponent(collection.id)}',
        <String, dynamic>{'limit': limit, 'access': 'playable'},
      );
      return _parseTracks(response.data, limit);
    } on Object {
      return const <OnlineTrack>[];
    }
  }

  List<OnlineCollectionRef> _parseCollections(
    Object? payload,
    OnlineSearchType type,
    int limit,
  ) {
    final Map<String, dynamic>? map = SourceJson.map(payload);
    final Object? collection = map?['collection'] ?? map?['data'] ?? payload;
    final List<OnlineCollectionRef> result = <OnlineCollectionRef>[];
    for (final Object? entry in SourceJson.list(collection)) {
      if (result.length >= limit) break;
      final Map<String, dynamic>? json = SourceJson.map(entry);
      if (json == null) continue;
      final String id = SourceJson.text(json['id']);
      final String title = SourceJson.text(json['title']);
      if (id.isEmpty || title.isEmpty) continue;
      final bool isAlbum =
          SourceJson.text(json['is_album']).toLowerCase() == 'true';
      if (type == OnlineSearchType.albums && !isAlbum) continue;
      if (type == OnlineSearchType.playlists && isAlbum) continue;

      final Map<String, dynamic>? user = SourceJson.map(json['user']);
      final String? artwork = SourceJson.soundCloudArtwork(
        json['artwork_url'] ?? user?['avatar_url'],
      );
      result.add(
        OnlineCollectionRef(
          externalId: 'soundcloud:${type.name}:$id',
          id: id,
          title: title,
          subtitle: SourceJson.text(user?['username']).isNotEmpty
              ? SourceJson.text(user?['username'])
              : SourceJson.text(json['description']),
          artworkUrl: artwork,
          permalink: SourceJson.url(json['permalink_url']),
          source: MusicSourceId.soundcloud,
          kind: type,
          trackCount: SourceJson.integer(
            json['track_count'] ?? SourceJson.list(json['tracks']).length,
          ),
        ),
      );
    }
    return result;
  }

  @override
  Future<ResolvedStream> resolveStream(OnlineTrack track) async {
    final String? token = _token;
    if (token == null) {
      throw const MusicSourceException(
        'Configura un token de SoundCloud para reproducir esta pista.',
        source: MusicSourceId.soundcloud,
        issue: MusicSourceIssue.notConfigured,
      );
    }
    try {
      final Response<dynamic> response = await _get(
        '/tracks/${Uri.encodeComponent(track.sourceId)}/stream',
      );
      final Map<String, dynamic>? payload = SourceJson.map(response.data);
      final List<Object?> transcodings = SourceJson.list(
        payload?['transcodings'],
      );
      String? selected;
      String preset = '';
      for (final Object? entry in transcodings) {
        final Map<String, dynamic>? item = SourceJson.map(entry);
        if (item == null) continue;
        final Map<String, dynamic>? format = SourceJson.map(item['format']);
        if (SourceJson.text(format?['protocol']) != 'progressive') continue;
        selected = SourceJson.url(item['url']);
        preset = SourceJson.text(item['preset']);
        if (selected != null) break;
      }
      if (selected == null) {
        throw const MusicSourceException(
          'SoundCloud no ofrece esta pista para reproducción externa.',
          source: MusicSourceId.soundcloud,
          issue: MusicSourceIssue.region,
        );
      }

      final Response<dynamic> media = await _get(selected);
      final String? direct = SourceJson.url(SourceJson.map(media.data)?['url']);
      if (direct == null) {
        throw const MusicSourceException(
          'SoundCloud no devolvió una URL de audio utilizable.',
          source: MusicSourceId.soundcloud,
        );
      }
      return ResolvedStream(
        url: direct,
        extension: preset.toLowerCase().contains('ogg')
            ? 'ogg'
            : preset.toLowerCase().contains('aac')
            ? 'm4a'
            : 'mp3',
        mimeType: preset.contains('/') ? preset : 'audio/mpeg',
      );
    } on MusicSourceException {
      rethrow;
    } catch (error) {
      throw MusicSourceException(
        'No se pudo resolver el audio de SoundCloud.',
        source: id,
        issue:
            MusicSourceErrorMapper.map(error, id).issue ??
            MusicSourceIssue.unavailable,
      );
    }
  }

  @override
  Future<String?> cacheArtwork(String? artworkUrl) =>
      _artworkCache.cache(artworkUrl, id);

  Future<Response<dynamic>> _get(String path, [Map<String, dynamic>? query]) {
    final String? token = _token;
    if (token == null) {
      throw const MusicSourceException(
        'Falta el token de SoundCloud.',
        source: MusicSourceId.soundcloud,
        issue: MusicSourceIssue.notConfigured,
      );
    }
    Uri uri = Uri.parse(path.startsWith('http') ? path : '$_baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(
        queryParameters: <String, dynamic>{...uri.queryParameters, ...query},
      );
    }
    return _dio.getUri<dynamic>(
      uri,
      options: Options(
        headers: <String, String>{
          'Authorization': 'OAuth $token',
          'Accept': 'application/json; charset=utf-8',
        },
      ),
    );
  }

  List<OnlineTrack> _parseTracks(Object? payload, int limit) {
    final Map<String, dynamic>? map = SourceJson.map(payload);
    final Object? collection = map?['collection'] ?? map?['data'] ?? payload;
    final List<OnlineTrack> tracks = <OnlineTrack>[];
    for (final Object? entry in SourceJson.list(collection)) {
      if (tracks.length >= limit) break;
      final Map<String, dynamic>? json = SourceJson.map(entry);
      if (json == null) continue;
      if (SourceJson.text(json['access']).toLowerCase() == 'blocked') continue;
      final String id = SourceJson.text(json['id']);
      final String title = SourceJson.text(json['title']);
      if (id.isEmpty || title.isEmpty) continue;
      final Map<String, dynamic>? user = SourceJson.map(json['user']);
      final String artist = SourceJson.text(json['metadata_artist']).isNotEmpty
          ? SourceJson.text(json['metadata_artist'])
          : SourceJson.text(user?['username']);
      tracks.add(
        OnlineTrack(
          externalId: 'soundcloud:$id',
          sourceId: id,
          title: title,
          artist: artist.isEmpty ? 'Desconocido' : artist,
          album: SourceJson.text(json['album_name']),
          genre: SourceJson.text(json['genre']),
          durationMs: SourceJson.integer(json['duration']),
          artworkUrl: SourceJson.soundCloudArtwork(json['artwork_url']),
          permalink: SourceJson.url(json['permalink_url']),
          sourceLabel: 'SoundCloud',
          playCount: SourceJson.integer(json['playback_count']),
        ),
      );
    }
    return tracks;
  }
}
