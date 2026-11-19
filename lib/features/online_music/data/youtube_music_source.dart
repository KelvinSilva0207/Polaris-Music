import 'dart:convert';

import 'package:dio/dio.dart';

import '../domain/music_source.dart';
import '../domain/online_track.dart';
import 'source_helpers.dart';

/// Proveedor de metadatos de YouTube Music mediante el endpoint público de
/// InnerTube usado por el propio cliente web (sin credenciales de socio).
///
/// Permite encontrar artistas comerciales y lanzamientos actuales. Para cada
/// resultado se expone el enlace a YouTube Music; la resolución de audio queda
/// a cargo de las fuentes con streams legales declarados, igual que Spotify.
class YouTubeMusicSource implements MusicSourceProvider {
  YouTubeMusicSource({Dio? dio, ArtworkCache? artworkCache})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 25),
              headers: const <String, String>{
                'User-Agent': 'PolarisMusic/1.0 (Flutter)',
                'Accept-Language': 'es,en;q=0.9',
              },
            ),
          ),
      _artworkCache = artworkCache ?? ArtworkCache();

  static const String _baseUrl = 'https://music.youtube.com/youtubei/v1';

  final Dio _dio;
  final ArtworkCache _artworkCache;
  final Map<String, String> _clientVersion = <String, String>{};

  MusicSourceStatus _status = const MusicSourceStatus();

  @override
  MusicSourceId get id => MusicSourceId.youtube;

  @override
  bool get canSearch => true;

  @override
  bool get canTrending => true;

  /// InnerTube solo entrega metadatos: no se expone un stream directo.
  @override
  bool get canStream => false;

  @override
  bool get canDownload => false;

  @override
  MusicSourceStatus get status => _status;

  Future<String> _version() async {
    final String cached = _clientVersion['web'] ?? '';
    if (cached.isNotEmpty) return cached;
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        'https://music.youtube.com/',
        options: Options(responseType: ResponseType.plain),
      );
      final String html = '${response.data ?? ''}';
      final RegExp regex = RegExp(r'"INNERTUBE_CLIENT_VERSION":"([^"]+)"');
      final RegExpMatch? match = regex.firstMatch(html);
      final String version = match?.group(1) ?? '2.20250312.04.00';
      _clientVersion['web'] = version;
      return version;
    } on Object {
      const String fallback = '2.20250312.04.00';
      _clientVersion['web'] = fallback;
      return fallback;
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final String version = await _version();
    final Response<dynamic> response = await _dio.post<dynamic>(
      '$_baseUrl/$path',
      data: <String, dynamic>{
        ...body,
        'context': <String, dynamic>{
          'client': <String, dynamic>{
            'clientName': 'WEB_REMIX',
            'clientVersion': version,
            'hl': 'es',
            'gl': 'ES',
          },
        },
      },
      options: Options(
        responseType: ResponseType.json,
        headers: <String, String>{'X-YouTube-Client-Version': version},
      ),
    );
    return SourceJson.map(response.data) ?? <String, dynamic>{};
  }

  @override
  Future<MusicSourceStatus> checkAvailability() async {
    try {
      await _post('search', <String, dynamic>{
        'query': 'music',
        'searchContext': const <String, dynamic>{
          'clientSearchContext': <String, dynamic>{},
        },
      });
      _status = MusicSourceStatus(available: true, checkedAt: DateTime.now());
    } catch (error) {
      _status = MusicSourceErrorMapper.map(error, id);
    }
    return _status;
  }

  @override
  Future<SourceResult> search(String query, {int limit = 25}) async {
    if (query.trim().isEmpty) {
      return const SourceResult(source: MusicSourceId.youtube);
    }
    try {
      final Map<String, dynamic> payload = await _post(
        'search',
        <String, dynamic>{
          'query': query.trim(),
          'searchContext': const <String, dynamic>{
            'clientSearchContext': <String, dynamic>{},
          },
        },
      );
      return SourceResult(source: id, items: _parse(_shelves(payload), limit));
    } catch (error) {
      return SourceResult(
        source: id,
        status: MusicSourceErrorMapper.map(error, id),
      );
    }
  }

  @override
  Future<SourceResult> trending({int limit = 25}) async {
    const String query = 'canciones populares 2026';
    return search(query, limit: limit);
  }

  List<Object?> _shelves(Map<String, dynamic> payload) {
    final List<Object?> result = <Object?>[];
    final Object? contents = payload['contents'];
    void walk(Object? node) {
      final Map<String, dynamic>? map = SourceJson.map(node);
      if (map == null) return;
      if (map.containsKey('videoRenderer')) result.add(map['videoRenderer']);
      if (map.containsKey('musicResponsiveListItemRenderer')) {
        result.add(map['musicResponsiveListItemRenderer']);
      }
      for (final Object? value in map.values) {
        if (value is Map || value is List) walk(value);
      }
    }

    walk(contents);
    return result;
  }

  List<OnlineTrack> _parse(List<Object?> renderers, int limit) {
    final List<OnlineTrack> tracks = <OnlineTrack>[];
    final Set<String> seen = <String>{};
    for (final Object? entry in renderers) {
      if (tracks.length >= limit) break;
      final Map<String, dynamic>? renderer = SourceJson.map(entry);
      if (renderer == null) continue;

      final String id = SourceJson.text(renderer['videoId']);
      if (id.isEmpty || !seen.add(id)) continue;
      final String title = _text(renderer['title']) ?? '';
      if (title.isEmpty) continue;

      final String? artist = _text(renderer['ownerText']) ?? _artist(renderer);
      final String? artwork = _artwork(renderer);
      final int duration = _duration(renderer);

      tracks.add(
        OnlineTrack(
          externalId: 'youtube:$id',
          sourceId: id,
          title: title,
          artist: artist ?? 'Desconocido',
          album: '',
          durationMs: duration,
          artworkUrl: artwork,
          permalink: 'https://music.youtube.com/watch?v=$id',
          sourceLabel: 'YouTube Music',
        ),
      );
    }
    return tracks;
  }

  String? _text(Object? node) {
    final Map<String, dynamic>? map = SourceJson.map(node);
    if (map == null) return null;
    final String value = SourceJson.text(map['simpleText']);
    if (value.isNotEmpty) return value;
    final Object? runs = map['runs'];
    if (runs is List) {
      final StringBuffer buffer = StringBuffer();
      for (final Object? run in runs) {
        final Map<String, dynamic>? runMap = SourceJson.map(run);
        if (runMap == null) continue;
        buffer.write(SourceJson.text(runMap['text']));
      }
      if (buffer.isNotEmpty) return buffer.toString();
    }
    return null;
  }

  String? _artist(Map<String, dynamic> renderer) {
    final Object? lines = renderer['flexColumns'];
    if (lines is List && lines.isNotEmpty) {
      final Object? first = SourceJson.map(
        lines.first,
      )?['musicResponsiveListItemFlexColumnRenderer'];
      final String? text = _text(SourceJson.map(first)?['text'] ?? first);
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  String? _artwork(Map<String, dynamic> renderer) {
    final Map<String, dynamic>? thumbnail = SourceJson.map(
      renderer['thumbnail'],
    );
    Object? thumbnails = thumbnail?['thumbnails'];
    thumbnails ??= SourceJson.map(
      thumbnail?['musicThumbnailRenderer'],
    )?['thumbnails'];
    final List<Object?> candidates = thumbnails is List
        ? thumbnails
        : SourceJson.list(thumbnails);
    for (final Object? entry in candidates) {
      final String? url = SourceJson.url(SourceJson.map(entry)?['url']);
      if (url != null) return url;
    }
    // Algunos renderers anidan la miniatura dentro de flexColumns.
    final String encoded = jsonEncode(renderer);
    final RegExpMatch? match = RegExp(r'"url":"(https://i\.ytimg\.com/[^"]+)"')
        .firstMatch(encoded);
    return match?.group(1);
  }

  int _duration(Map<String, dynamic> renderer) {
    final String encoded = jsonEncode(renderer);
    final RegExpMatch? match = RegExp(r'"approxDurationMs":"(\d+)"')
        .firstMatch(encoded);
    if (match != null) return int.tryParse(match.group(1) ?? '') ?? 0;
    final RegExpMatch? textMatch = RegExp(r'"text":"(?:(\d+):)?(\d+):(\d+)"')
        .firstMatch(encoded);
    if (textMatch == null) return 0;
    final int hours = int.tryParse(textMatch.group(1) ?? '0') ?? 0;
    final int minutes = int.tryParse(textMatch.group(2) ?? '0') ?? 0;
    final int seconds = int.tryParse(textMatch.group(3) ?? '0') ?? 0;
    return ((hours * 3600) + (minutes * 60) + seconds) * 1000;
  }

  @override
  Future<ResolvedStream> resolveStream(OnlineTrack track) => Future.error(
    const MusicSourceException(
      'YouTube Music se usa solo para búsqueda; el audio no se puede '
      'reproducir directamente desde esta fuente.',
      source: MusicSourceId.youtube,
      issue: MusicSourceIssue.unsupported,
    ),
  );

  @override
  Future<String?> cacheArtwork(String? artworkUrl) =>
      _artworkCache.cache(artworkUrl, id);
}
