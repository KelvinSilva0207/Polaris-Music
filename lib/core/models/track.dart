import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../database/app_database.dart';

/// Entidad de canción usada por reproductor, letras y estadísticas.
///
/// Es una proyección inmutable de `TrackRow` (modelo de persistencia): la UI y
/// la lógica de dominio nunca tocan drift directamente.
@immutable
class Track {
  const Track({
    required this.id,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    this.albumArtist = '',
    this.genre = '',
    this.year,
    this.trackNumber,
    this.discNumber,
    this.bitrate,
    this.sampleRate,
    this.format = '',
    this.fileSize = 0,
    this.artworkPath,
    this.replayGainTrackDb,
    this.replayGainAlbumDb,
    this.isFavorite = false,
    this.playCount = 0,
    this.lastPlayedAt,
  });

  final int id;
  final String path;
  final String title;
  final String artist;
  final String album;
  final String albumArtist;
  final String genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final int? bitrate;
  final int? sampleRate;
  final String format;
  final int fileSize;
  final int durationMs;
  final String? artworkPath;
  final double? replayGainTrackDb;
  final double? replayGainAlbumDb;
  final bool isFavorite;
  final int playCount;
  final DateTime? lastPlayedAt;

  Duration get duration => Duration(milliseconds: durationMs);

  String get subtitle =>
      album.isEmpty || album == 'Desconocido' ? artist : '$artist · $album';

  factory Track.fromRow(TrackRow row) => Track(
    id: row.id,
    path: row.path,
    title: row.title,
    artist: row.artist,
    album: row.album,
    albumArtist: row.albumArtist ?? '',
    genre: row.genre ?? '',
    year: row.year,
    trackNumber: row.trackNumber,
    discNumber: row.discNumber,
    bitrate: row.bitrate,
    sampleRate: row.sampleRate,
    format: row.format ?? '',
    fileSize: row.fileSize,
    durationMs: row.durationMs,
    artworkPath: row.artworkPath,
    replayGainTrackDb: row.replayGainTrackDb,
    replayGainAlbumDb: row.replayGainAlbumDb,
    isFavorite: row.isFavorite,
    playCount: row.playCount,
    lastPlayedAt: row.lastPlayedAt,
  );

  Track copyWith({
    String? title,
    String? artist,
    String? album,
    String? artworkPath,
    bool? isFavorite,
    int? playCount,
    DateTime? lastPlayedAt,
    double? replayGainTrackDb,
    double? replayGainAlbumDb,
  }) => Track(
    id: id,
    path: path,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    albumArtist: albumArtist,
    genre: genre,
    year: year,
    trackNumber: trackNumber,
    discNumber: discNumber,
    bitrate: bitrate,
    sampleRate: sampleRate,
    format: format,
    fileSize: fileSize,
    durationMs: durationMs,
    artworkPath: artworkPath ?? this.artworkPath,
    replayGainTrackDb: replayGainTrackDb ?? this.replayGainTrackDb,
    replayGainAlbumDb: replayGainAlbumDb ?? this.replayGainAlbumDb,
    isFavorite: isFavorite ?? this.isFavorite,
    playCount: playCount ?? this.playCount,
    lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
  );

  /// Valores listos para actualizar solo la fila de estadísticas.
  TracksCompanion get favoriteCompanion =>
      TracksCompanion(isFavorite: Value(isFavorite));

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Track($id, $artist - $title)';
}
