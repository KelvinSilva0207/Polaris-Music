import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../models/scrobble_config.dart';
import '../models/track.dart';
import 'settings_service.dart';

/// Envío de escuchas a Last.fm (o a un servidor compatible con su API 2.0).
///
/// La sesión se guarda en preferencias: el usuario introduce su API key y su
/// secreto, autoriza la aplicación en la web y la app intercambia el token por
/// una clave de sesión. Las claves nunca se envían a ningún servidor que no sea
/// el configurado y los fallos de red jamás interrumpen la reproducción.
class ScrobbleService {
  ScrobbleService({required this.settings, Dio? dio}) : _dio = dio ?? Dio();

  static const String defaultEndpoint = 'https://ws.audioscrobbler.com/2.0/';

  final SettingsService settings;
  final Dio _dio;

  ScrobbleConfig get config => settings.scrobbleConfig;

  bool get isReady => config.ready;

  String get endpoint {
    final String configured = config.endpoint.trim();
    return configured.isEmpty ? defaultEndpoint : configured;
  }

  /// Firma exigida por Last.fm: parámetros ordenados por clave + secreto.
  ///
  /// `format` y `callback` se excluyen porque solo afectan a la respuesta.
  static String signature(Map<String, String> parameters, String secret) {
    final List<MapEntry<String, String>> sorted = parameters.entries.toList()
      ..sort(
        (MapEntry<String, String> a, MapEntry<String, String> b) =>
            a.key.compareTo(b.key),
      );
    final StringBuffer buffer = StringBuffer();
    for (final MapEntry<String, String> entry in sorted) {
      if (entry.key == 'format' || entry.key == 'callback') continue;
      buffer.write(entry.key);
      buffer.write(entry.value);
    }
    buffer.write(secret);
    return md5.convert(utf8.encode(buffer.toString())).toString();
  }

  /// Guarda las credenciales y pide un token de autorización.
  ///
  /// Devuelve el token para que la UI abra la página de autorización.
  Future<String> beginLogin({
    required String apiKey,
    required String apiSecret,
    String endpoint = '',
  }) async {
    final String cleanKey = apiKey.trim();
    final String cleanSecret = apiSecret.trim();
    if (cleanKey.isEmpty || cleanSecret.isEmpty) {
      throw const ScrobbleException('Faltan la API key o el secreto');
    }
    final String cleanEndpoint = endpoint.trim().isEmpty
        ? defaultEndpoint
        : endpoint.trim();
    final ScrobbleConfig next = ScrobbleConfig(
      apiKey: cleanKey,
      apiSecret: cleanSecret,
      endpoint: cleanEndpoint,
    );
    await settings.setScrobbleConfig(next);

    final Map<String, Object?> response = await _call(
      'auth.getToken',
      <String, String>{'api_key': cleanKey},
      config: next,
    );
    final String token = (response['token'] ?? '').toString().trim();
    if (token.isEmpty) {
      throw const ScrobbleException('Last.fm no devolvió un token');
    }
    await settings.setScrobbleConfig(next.copyWith(pendingToken: token));
    return token;
  }

  /// Página donde el usuario autoriza la aplicación con el token recibido.
  Uri authorizationUrl(String token) {
    final ScrobbleConfig current = config;
    final Map<String, String> query = <String, String>{
      'api_key': current.apiKey,
      'token': token,
    };
    final String configured = current.endpoint.trim();
    if (configured.isEmpty || configured.contains('audioscrobbler.com')) {
      return Uri.https('www.last.fm', '/api/auth/', query);
    }
    return Uri.parse(configured)
        .replace(path: '/api/auth/', queryParameters: query);
  }

  /// Intercambia el token autorizado por una clave de sesión persistida.
  Future<ScrobbleConfig> finishLogin() async {
    final ScrobbleConfig current = config;
    final String token = current.pendingToken;
    if (token.isEmpty || current.apiKey.isEmpty || current.apiSecret.isEmpty) {
      throw const ScrobbleException('No hay una autorización pendiente');
    }
    final Map<String, Object?> response = await _call(
      'auth.getSession',
      <String, String>{'api_key': current.apiKey, 'token': token},
      config: current,
    );
    final Object? rawSession = response['session'];
    final Map<dynamic, dynamic> session = rawSession is Map
        ? rawSession
        : const <dynamic, dynamic>{};
    final String key = (session['key'] ?? '').toString().trim();
    if (key.isEmpty) {
      throw const ScrobbleException('Last.fm no devolvió una sesión');
    }
    final ScrobbleConfig connected = current.copyWith(
      sessionKey: key,
      username: (session['name'] ?? '').toString().trim(),
      pendingToken: '',
      enabled: true,
    );
    await settings.setScrobbleConfig(connected);
    return connected;
  }

  /// Envía una escucha ya validada por el registrador de estadísticas.
  Future<void> scrobble(Track track, {DateTime? listenedAt}) async {
    final ScrobbleConfig current = config;
    if (!current.ready) return;
    final int timestamp =
        (listenedAt ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
    await _call('track.scrobble', <String, String>{
      'api_key': current.apiKey,
      'sk': current.sessionKey,
      'artist': track.artist.trim().isEmpty
          ? 'Desconocido'
          : track.artist.trim(),
      'track': track.title.trim().isEmpty ? 'Sin título' : track.title.trim(),
      'timestamp': '$timestamp',
    }, config: current);
  }

  Future<void> disconnect() => settings.setScrobbleConfig(
    config.copyWith(
      enabled: false,
      sessionKey: '',
      username: '',
      pendingToken: '',
    ),
  );

  Future<Map<String, Object?>> _call(
    String method,
    Map<String, String> parameters, {
    required ScrobbleConfig config,
  }) async {
    final Map<String, String> signed = <String, String>{
      ...parameters,
      'method': method,
    };
    signed['api_sig'] = signature(signed, config.apiSecret);
    signed['format'] = 'json';

    try {
      final Response<String> response = await _dio.post<String>(
        endpoint,
        data: signed,
        options: Options(
          responseType: ResponseType.plain,
          headers: <String, Object>{'User-Agent': 'PolarisMusic/1.0'},
        ),
      );
      final Object? decoded = jsonDecode(response.data ?? '');
      if (decoded is! Map) {
        throw const ScrobbleException('Respuesta inesperada del servidor');
      }
      final Object? error = decoded['error'];
      if (error != null) {
        final String detail = (decoded['message'] ?? '').toString();
        throw ScrobbleException(
          detail.isEmpty ? 'Error $error del servidor' : detail,
        );
      }
      return Map<String, Object?>.from(decoded);
    } on DioException catch (error) {
      throw ScrobbleException(
        error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.receiveTimeout
            ? 'El servidor no respondió a tiempo'
            : 'No se pudo contactar con el servidor',
      );
    } on FormatException {
      throw const ScrobbleException('Respuesta no válida del servidor');
    }
  }
}

class ScrobbleException implements Exception {
  const ScrobbleException(this.message);

  final String message;

  @override
  String toString() => message;
}
