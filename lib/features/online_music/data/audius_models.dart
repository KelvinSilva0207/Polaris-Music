import 'package:flutter/foundation.dart';

import '../domain/online_track.dart';

/// DTO de una pista de Audius tal como llega por JSON.
///
/// Se mantiene separado de [OnlineTrack] para que un cambio de API no filtre
/// detalles de transporte al dominio. Audius sirve audio abierto y no requiere
/// clave de API.
@immutable
class AudiusTrackDto {
  const AudiusTrackDto({
    required this.id,
    required this.title,
    required this.artist,
    required this.durationMs,
    this.album = '',
    this.genre = '',
    this.artworkUrl,
    this.permalink,
    this.isStreamable = true,
    this.playCount = 0,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final int durationMs;
  final String? artworkUrl;
  final String? permalink;
  final bool isStreamable;
  final int playCount;

  factory AudiusTrackDto.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? user = _asMap(json['user']);
    final Map<String, dynamic>? artwork = _asMap(json['artwork']);

    final Object? duration = json['duration'];
    final int seconds = duration is num
        ? duration.toInt()
        : int.tryParse('${duration ?? ''}') ?? 0;

    final String? artworkUrl = _pickArtwork(artwork);

    return AudiusTrackDto(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}'.trim(),
      artist: _clean(user?['name']) ?? 'Desconocido',
      album: _clean(json['album']) ?? '',
      genre: _clean(json['genre']) ?? '',
      durationMs: seconds * 1000,
      artworkUrl: artworkUrl,
      permalink: _clean(json['permalink']),
      isStreamable: json['is_streamable'] != false,
      playCount: json['play_count'] is num
          ? (json['play_count'] as num).toInt()
          : 0,
    );
  }

  /// Prefiere carátulas medianas para no gastar datos en listas.
  static String? _pickArtwork(Map<String, dynamic>? artwork) {
    if (artwork == null) return null;
    for (final String key in <String>[
      '480x480',
      '1000x1000',
      '150x150',
      'mirror',
    ]) {
      final Object? value = artwork[key];
      if (value is String && value.isNotEmpty && value.startsWith('http')) {
        return value;
      }
    }
    return null;
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((Object? key, Object? item) => MapEntry('$key', item));
    }
    return null;
  }

  static String? _clean(Object? value) {
    if (value is! String) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  OnlineTrack toEntity() => OnlineTrack(
    externalId: 'audius:$id',
    sourceId: id,
    title: title,
    artist: artist,
    album: album,
    genre: genre,
    durationMs: durationMs,
    artworkUrl: artworkUrl,
    permalink: permalink,
    sourceLabel: 'Audius',
    playCount: playCount,
  );
}
