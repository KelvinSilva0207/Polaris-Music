import 'package:dio/dio.dart';

import '../../../core/services/settings_service.dart';
import '../domain/music_source.dart';
import '../domain/online_source_settings.dart';
import '../domain/online_track.dart';
import 'source_helpers.dart';

/// Proveedor de metadatos de Spotify mediante Web API.
///
/// Spotify no permite descargar ni reproducir su audio fuera de sus SDK y
/// exige atribución, por lo que esta fuente busca y muestra canciones, pero
/// desactiva explícitamente streaming y descarga. El token se introduce en
/// ajustes (OAuth de la app del usuario); nunca se guarda un `client_secret`.
class SpotifySource implements MusicSourceProvider {
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
  Future<SourceResult> search(String query, {int limit = 25}) async {
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

  Future<Response<dynamic>> _get(String path, [Map<String, dynamic>? query]) {
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
