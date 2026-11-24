import 'dart:collection';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/track.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/lrc_parser.dart';
import '../../../core/utils/text_decoder.dart';

/// Letra resuelta para una pista.
class LyricsResult {
  const LyricsResult({
    required this.document,
    required this.source,
    this.fromCache = false,
  });

  final LrcDocument document;
  final String source;
  final bool fromCache;

  bool get isEmpty => document.lines.isEmpty;
  bool get synced => document.synced;
}

/// Resolución de letras: `.lrc` local → caché → LRCLIB.
///
/// LRCLIB es una API pública sin clave. Se respeta su etiqueta de uso con un
/// User-Agent identificable y se cachea en Drift para no repetir peticiones.
class LyricsService {
  LyricsService(this._dao, {Dio? dio}) : _dio = dio ?? Dio();

  static const String _tag = 'Lyrics';
  static const String _baseUrl = 'https://lrclib.net/api';

  final LyricsDao _dao;
  final Dio _dio;

  /// Caché LRU acotada para no consultar Drift al reconstruir la UI sin
  /// retener el documento de cada pista escuchada en una sesión larga.
  static const int _maxMemoryEntries = 64;
  final LinkedHashMap<int, LyricsResult> _memory =
      LinkedHashMap<int, LyricsResult>();

  void _cacheResult(int trackId, LyricsResult result) {
    _memory.remove(trackId);
    _memory[trackId] = result;
    if (_memory.length > _maxMemoryEntries) {
      _memory.remove(_memory.keys.first);
    }
  }

  Future<LyricsResult?> resolve(Track track, {bool allowOnline = true}) async {
    final LyricsResult? cached = _memory[track.id];
    if (cached != null) return cached;

    final File? local = await FileUtils.siblingLyrics(track.path);
    if (local != null) {
      try {
        final String raw = await TextDecoder.readFile(local);
        final LyricsResult result = LyricsResult(
          document: LrcDocument.parse(raw),
          source: 'local',
        );
        _cacheResult(track.id, result);
        return result;
      } catch (error, stack) {
        AppLog.w(_tag, 'No se pudo leer ${local.path}', error, stack);
      }
    }

    final LyricRow? row = await _dao.forTrack(track.id);
    if (row != null && row.content.trim().isNotEmpty) {
      final LyricsResult result = LyricsResult(
        document: LrcDocument.parse(row.content),
        source: row.source,
        fromCache: true,
      );
      _cacheResult(track.id, result);
      return result;
    }

    if (!allowOnline) return null;

    final _OnlineLyrics? online = await _fetchOnline(track);
    if (online == null) return null;

    final String content = online.synced && online.syncedLyrics.isNotEmpty
        ? online.syncedLyrics
        : online.plainLyrics;
    if (content.trim().isEmpty) return null;

    // Las pistas de streaming no existen en Drift: la letra se mantiene solo
    // en memoria para no violar la clave foránea de `Lyrics`.
    if (track.isPersisted) {
      await _dao.save(
        track.id,
        content,
        synced: online.synced,
        source: 'lrclib',
      );
    }
    final LyricsResult result = LyricsResult(
      document: LrcDocument.parse(content),
      source: 'lrclib',
    );
    _cacheResult(track.id, result);
    return result;
  }

  /// Descarga la letra desde LRCLIB, sustituyendo la caché en memoria.
  Future<LyricsResult?> download(Track track) async {
    invalidate(track.id);
    final _OnlineLyrics? online = await _fetchOnline(track);
    if (online == null) return null;
    final String content = online.synced && online.syncedLyrics.isNotEmpty
        ? online.syncedLyrics
        : online.plainLyrics;
    if (content.trim().isEmpty) return null;
    final LrcDocument document = LrcDocument.parse(content);
    await saveLyrics(track, document, source: 'lrclib', synced: online.synced);
    return LyricsResult(document: document, source: 'lrclib');
  }

  /// Importa un archivo `.lrc` local y lo asocia a la pista.
  Future<LyricsResult?> importLrc(Track track, String path) async {
    if (!FileUtils.isLrcFile(path)) {
      throw const FormatException('El archivo debe tener extensión .lrc');
    }
    final String raw = await TextDecoder.readFile(File(path));
    if (raw.trim().isEmpty) return null;
    final LrcDocument document = LrcDocument.parse(raw);
    await saveLyrics(track, document, source: 'local', synced: document.synced);
    return LyricsResult(document: document, source: 'local');
  }

  /// Guarda una letra creada o sincronizada por el usuario.
  Future<void> saveLyrics(
    Track track,
    LrcDocument document, {
    String source = 'user',
    bool? synced,
  }) async {
    if (track.isPersisted) {
      await _dao.save(
        track.id,
        document.toLrc(),
        synced: synced ?? document.synced,
        source: source,
      );
    }
    _cacheResult(
      track.id,
      LyricsResult(document: document, source: source, fromCache: true),
    );
  }

  /// Exporta el documento a un archivo `.lrc`.
  Future<File> exportLrc(Track track, LrcDocument document, String path) {
    final String target = FileUtils.isLrcFile(path) ? path : '$path.lrc';
    return File(target).writeAsString(document.toLrc());
  }

  Future<_OnlineLyrics?> _fetchOnline(Track track) async {
    try {
      final Map<String, dynamic>? exact = await _request(<String, dynamic>{
        'artist_name': track.artist,
        'track_name': track.title,
        if (track.album.isNotEmpty && track.album != 'Desconocido')
          'album_name': track.album,
        if (track.durationMs > 0) 'duration': (track.durationMs / 1000).round(),
      });
      if (exact != null) return _OnlineLyrics.fromJson(exact);

      final Response<List<dynamic>> search = await _dio.get<List<dynamic>>(
        '$_baseUrl/search',
        queryParameters: <String, dynamic>{
          'artist_name': track.artist,
          'track_name': track.title,
        },
        options: _options,
      );
      final List<dynamic> results = search.data ?? const <dynamic>[];
      for (final dynamic raw in results.whereType<Map<String, dynamic>>()) {
        final _OnlineLyrics lyrics = _OnlineLyrics.fromJson(raw);
        if (lyrics.hasContent) return lyrics;
      }
      return null;
    } on DioException catch (error, stack) {
      AppLog.w(
        _tag,
        'LRCLIB no respondió: ${error.response?.statusCode ?? error.type.name}',
        error,
        stack,
      );
      return null;
    } catch (error, stack) {
      AppLog.w(_tag, 'Error inesperado consultando letras', error, stack);
      return null;
    }
  }

  Future<Map<String, dynamic>?> _request(Map<String, dynamic> query) async {
    final Response<Map<String, dynamic>> response = await _dio
        .get<Map<String, dynamic>>(
          '$_baseUrl/get',
          queryParameters: query,
          options: _options,
        );
    if (response.statusCode == 404) return null;
    return response.data;
  }

  Options get _options => Options(
    headers: <String, String>{
      'User-Agent':
          'PolarisMusic/0.1 (https://github.com/KelvinSilva0207/Polaris-Music)',
      'Accept': 'application/json',
    },
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 10),
    validateStatus: (int? status) => status != null && status < 500,
  );

  void invalidate(int trackId) {
    _memory.remove(trackId);
  }

  void clearCache() => _memory.clear();
}

class _OnlineLyrics {
  const _OnlineLyrics({required this.syncedLyrics, required this.plainLyrics});

  final String syncedLyrics;
  final String plainLyrics;

  bool get synced => syncedLyrics.trim().isNotEmpty;
  bool get hasContent =>
      syncedLyrics.trim().isNotEmpty || plainLyrics.trim().isNotEmpty;

  factory _OnlineLyrics.fromJson(Map<String, dynamic> json) => _OnlineLyrics(
    syncedLyrics: (json['syncedLyrics'] as String?) ?? '',
    plainLyrics: (json['plainLyrics'] as String?) ?? '',
  );
}
