import 'package:flutter/foundation.dart';

/// Pista descargada desde una fuente online y lista para entrar en la
/// biblioteca local.
///
/// Es un modelo de transferencia entre la capa de descargas y la biblioteca:
/// no conoce Drift ni la UI. `externalId` es la clave que evita duplicados al
/// volver a descargar la misma pista.
@immutable
class DownloadedTrack {
  const DownloadedTrack({
    required this.externalId,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    this.artworkPath,
    this.format = 'MP3',
    this.fileSize = 0,
    this.bitrate,
    this.sourceLabel = 'Online',
  });

  /// Identificador estable en la fuente original (p. ej. `audius:abc123`).
  final String externalId;

  /// Ruta absoluta del archivo de audio ya descargado.
  final String path;

  final String title;
  final String artist;
  final String album;
  final int durationMs;

  /// Carátula cacheada localmente (nunca una URL).
  final String? artworkPath;

  /// Extensión en mayúsculas: `MP3`, `M4A`...
  final String format;
  final int fileSize;
  final int? bitrate;

  /// Etiqueta legible de la fuente (se guarda como álbum si falta metadata).
  final String sourceLabel;

  DownloadedTrack copyWith({String? path, String? artworkPath, int? fileSize}) {
    return DownloadedTrack(
      externalId: externalId,
      path: path ?? this.path,
      title: title,
      artist: artist,
      album: album,
      durationMs: durationMs,
      artworkPath: artworkPath ?? this.artworkPath,
      format: format,
      fileSize: fileSize ?? this.fileSize,
      bitrate: bitrate,
      sourceLabel: sourceLabel,
    );
  }

  @override
  String toString() => 'DownloadedTrack($externalId, $artist - $title)';
}
