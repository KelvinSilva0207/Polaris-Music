import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../core/constants/app_paths.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/logger.dart';
import '../domain/music_source.dart';

/// Error de dominio lanzado por un proveedor cuando no puede resolver audio.
@immutable
class MusicSourceException implements Exception {
  const MusicSourceException(
    this.message, {
    required this.source,
    this.issue = MusicSourceIssue.unavailable,
  });

  final String message;
  final MusicSourceId source;
  final MusicSourceIssue issue;

  @override
  String toString() => message;
}

/// Convierte errores de transporte en estados que la interfaz puede explicar.
class MusicSourceErrorMapper {
  const MusicSourceErrorMapper._();

  static MusicSourceStatus map(Object error, MusicSourceId source) {
    if (error is MusicSourceException) {
      return MusicSourceStatus(
        available: false,
        issue: error.issue,
        detail: error.message,
        checkedAt: DateTime.now(),
      );
    }
    if (error is DioException) {
      final int? status = error.response?.statusCode;
      final String body = '${error.response?.data ?? ''}'.toLowerCase();
      if (status == null) {
        return _status(
          MusicSourceIssue.offline,
          'Sin conexión con ${source.label}.',
        );
      }
      if (status == 401) {
        return _status(
          MusicSourceIssue.authentication,
          'El token de ${source.label} no es válido o ha caducado.',
        );
      }
      if (status == 403) {
        final bool looksRegional =
            body.contains('region') ||
            body.contains('market') ||
            body.contains('country') ||
            body.contains('not available');
        return _status(
          looksRegional
              ? MusicSourceIssue.region
              : MusicSourceIssue.authentication,
          looksRegional
              ? '${source.label} no está disponible en tu región.'
              : 'Tu cuenta o token no tiene acceso en ${source.label}.',
        );
      }
      if (status == 451) {
        return _status(
          MusicSourceIssue.region,
          '${source.label} bloqueó este contenido en tu región.',
        );
      }
      if (status == 429) {
        return _status(
          MusicSourceIssue.rateLimited,
          '${source.label} limitó las consultas. Espera un momento.',
        );
      }
      if (status >= 500) {
        return _status(
          MusicSourceIssue.unavailable,
          '${source.label} no responde ahora mismo.',
        );
      }
      return _status(
        MusicSourceIssue.unavailable,
        '${source.label} rechazó la consulta ($status).',
      );
    }
    return _status(
      MusicSourceIssue.unavailable,
      'No se pudo consultar ${source.label}.',
    );
  }

  static MusicSourceStatus _status(MusicSourceIssue issue, String detail) =>
      MusicSourceStatus(
        available: false,
        issue: issue,
        detail: detail,
        checkedAt: DateTime.now(),
      );
}

/// Lectura tolerante de respuestas JSON de APIs externas.
class SourceJson {
  const SourceJson._();

  static Map<String, dynamic>? map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((Object? k, Object? v) => MapEntry('$k', v));
    }
    return null;
  }

  static List<Object?> list(Object? value) =>
      value is List ? value : const <Object?>[];

  static String text(Object? value) {
    if (value == null) return '';
    return '$value'.trim();
  }

  static int integer(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(SourceJson.text(value)) ?? 0;
  }

  static String? url(Object? value) {
    final String text = SourceJson.text(value);
    return text.startsWith('http') ? text : null;
  }

  /// SoundCloud sirve carátulas pequeñas por defecto; se pide una mediana.
  static String? soundCloudArtwork(Object? value) {
    final String? url = SourceJson.url(value);
    if (url == null) return null;
    return url.replaceFirst(
      RegExp(r'-(large|small|t67x67|badge)\.(jpg|png|webp)'),
      r'-t500x500.$2',
    );
  }
}

/// Caché de carátulas compartida por todos los proveedores.
class ArtworkCache {
  ArtworkCache({Dio? dio}) : _dio = dio ?? _defaultDio();

  static const String _tag = 'OnlineArtwork';
  final Dio _dio;

  static Dio _defaultDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      headers: const <String, String>{
        'User-Agent': 'PolarisMusic/1.0 (Flutter)',
      },
    ),
  );

  Future<String?> cache(String? url, MusicSourceId source) {
    final String? artworkUrl = url;
    if (artworkUrl == null || artworkUrl.isEmpty) {
      return Future<String?>.value(null);
    }
    return _cache(artworkUrl, source);
  }

  Future<String?> _cache(String url, MusicSourceId source) async {
    try {
      final Directory dir = await AppPaths.artwork();
      final File target = File(
        p.join(dir.path, 'online_${source.prefix}_${FileUtils.fnv1a(url)}.jpg'),
      );
      if (await target.exists() && await target.length() > 0) {
        return target.path;
      }
      final Response<List<int>> response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final List<int>? bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (error, stack) {
      AppLog.w(
        _tag,
        'No se pudo cachear una carátula de ${source.label}',
        error,
        stack,
      );
      return null;
    }
  }

  void dispose() => _dio.close(force: true);
}
