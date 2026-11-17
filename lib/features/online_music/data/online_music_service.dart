import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../core/constants/app_paths.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/logger.dart';
import '../domain/online_music_repository.dart';
import '../domain/online_track.dart';
import 'audius_models.dart';

/// Error legible del catálogo online.
class OnlineMusicException implements Exception {
  const OnlineMusicException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Cliente del catálogo abierto de Audius.
///
/// - Descubre un nodo con `GET https://api.audius.co` (sin clave de API).
/// - Busca con `/v1/tracks/search` y lista tendencias con `/v1/tracks/trending`.
/// - Resuelve la URL directa de audio siguiendo las redirecciones de
///   `/v1/tracks/{id}/stream` con `dart:io` (sin descargar el audio).
///
/// Audius publica música con licencias abiertas; este módulo no hace rip ni
/// elude DRM de ninguna plataforma.
class OnlineMusicService implements OnlineMusicRepository {
  OnlineMusicService({Dio? dio, HttpClient? httpClient})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 30),
              headers: <String, String>{
                'User-Agent': 'PolarisMusic/1.0 (Flutter)',
              },
            ),
          ),
      _client =
          httpClient ??
          (HttpClient()..connectionTimeout = const Duration(seconds: 12));

  static const String _tag = 'OnlineMusic';
  static const String _appName = 'PolarisMusic';
  static const String _gateway = 'https://api.audius.co';

  final Dio _dio;
  final HttpClient _client;

  Future<String>? _hostFuture;

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 25}) async {
    final String term = query.trim();
    if (term.isEmpty) return const <OnlineTrack>[];
    return _fetchTracks('/v1/tracks/search', <String, dynamic>{
      'query': term,
      'limit': limit,
      'app_name': _appName,
    });
  }

  @override
  Future<List<OnlineTrack>> trending({int limit = 25}) => _fetchTracks(
    '/v1/tracks/trending',
    <String, dynamic>{'limit': limit, 'app_name': _appName},
  );

  Future<List<OnlineTrack>> _fetchTracks(
    String path,
    Map<String, dynamic> query,
  ) async {
    final String host = await _host();
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '$host$path',
        queryParameters: query,
        options: Options(responseType: ResponseType.json),
      );
      final Object? payload = response.data;
      final Object? list = payload is Map ? payload['data'] : payload;
      if (list is! List) return const <OnlineTrack>[];

      final List<OnlineTrack> tracks = <OnlineTrack>[];
      for (final Object? entry in list) {
        if (entry is! Map) continue;
        final AudiusTrackDto dto = AudiusTrackDto.fromJson(
          entry.map((Object? key, Object? value) => MapEntry('$key', value)),
        );
        if (!dto.isStreamable || dto.id.isEmpty || dto.title.isEmpty) continue;
        tracks.add(dto.toEntity());
      }
      return tracks;
    } on DioException catch (error, stack) {
      AppLog.w(_tag, 'Fallo consultando $path', error, stack);
      throw const OnlineMusicException(
        'No se pudo consultar el catálogo online. Revisa tu conexión.',
      );
    }
  }

  @override
  Future<ResolvedStream> resolveStream(OnlineTrack track) async {
    final String host = await _host();
    final Uri endpoint = Uri.parse(
      '$host/v1/tracks/${Uri.encodeComponent(track.sourceId)}/stream',
    ).replace(queryParameters: <String, String>{'app_name': _appName});

    try {
      final HttpClientRequest request = await _client.getUrl(endpoint);
      request.followRedirects = true;
      request.headers.set(HttpHeaders.acceptHeader, 'audio/*,*/*;q=0.8');
      final HttpClientResponse response = await request.close();

      final Uri resolved = response.redirects.isEmpty
          ? endpoint
          : response.redirects.last.location;
      final String mime = response.headers.contentType?.mimeType ?? '';
      final int status = response.statusCode;

      // Cerrar sin consumir el cuerpo: solo interesa la URL final.
      await response.listen(null).cancel();

      if (status >= 400) {
        throw const OnlineMusicException(
          'La pista no está disponible para streaming.',
        );
      }

      return ResolvedStream(
        url: resolved.toString(),
        extension: _extensionForMime(mime),
        mimeType: mime,
      );
    } on OnlineMusicException {
      rethrow;
    } catch (error, stack) {
      AppLog.w(
        _tag,
        'No se pudo resolver el stream de ${track.externalId}',
        error,
        stack,
      );
      // El endpoint redirige por sí mismo: libmpv puede seguirlo.
      return ResolvedStream(url: endpoint.toString());
    }
  }

  @override
  Future<String?> cacheArtwork(String? artworkUrl) async {
    if (artworkUrl == null || artworkUrl.isEmpty) return null;
    try {
      final Directory dir = await AppPaths.artwork();
      final File target = File(
        p.join(dir.path, 'online_${FileUtils.fnv1a(artworkUrl)}.jpg'),
      );
      if (await target.exists() && await target.length() > 0) {
        return target.path;
      }

      final Response<List<int>> response = await _dio.get<List<int>>(
        artworkUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final List<int>? bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo cachear la carátula online', error, stack);
      return null;
    }
  }

  Future<String> _host() => _hostFuture ??= _discoverHost();

  Future<String> _discoverHost() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        _gateway,
        options: Options(responseType: ResponseType.json),
      );
      final Object? payload = response.data;
      if (payload is Map) {
        final Object? hosts = payload['data'];
        if (hosts is List) {
          for (final Object? host in hosts) {
            final String value = '$host'.trim();
            if (value.startsWith('http')) {
              return value.replaceFirst(RegExp(r'/+$'), '');
            }
          }
        }
      }
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo descubrir un nodo de Audius', error, stack);
    }
    return _gateway;
  }

  static String _extensionForMime(String mime) {
    final String value = mime.toLowerCase();
    if (value.contains('mpeg') || value.contains('mp3')) return 'mp3';
    if (value.contains('mp4') ||
        value.contains('m4a') ||
        value.contains('aac')) {
      return 'm4a';
    }
    if (value.contains('opus')) return 'opus';
    if (value.contains('ogg')) return 'ogg';
    if (value.contains('webm')) return 'webm';
    if (value.contains('flac')) return 'flac';
    if (value.contains('wav')) return 'wav';
    return 'mp3';
  }

  Future<void> dispose() async {
    _client.close(force: true);
    _dio.close(force: true);
  }
}
