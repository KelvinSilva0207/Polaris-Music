import 'package:flutter/foundation.dart';

import '../../../core/models/track.dart';

/// Pista del catálogo online (aún no descargada).
///
/// `externalId` incluye la fuente (`audius:<id>`) para poder convivir con otros
/// proveedores sin colisiones; `sourceId` es el identificador crudo que usa la
/// API de ese proveedor.
@immutable
class OnlineTrack {
  const OnlineTrack({
    required this.externalId,
    required this.sourceId,
    required this.title,
    required this.artist,
    required this.durationMs,
    this.album = '',
    this.genre = '',
    this.artworkUrl,
    this.permalink,
    this.sourceLabel = 'Audius',
    this.playCount = 0,
  });

  final String externalId;
  final String sourceId;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final int durationMs;
  final String? artworkUrl;
  final String? permalink;
  final String sourceLabel;
  final int playCount;

  Duration get duration => Duration(milliseconds: durationMs);

  /// Proyección reproducible. [streamUrl] es la URL directa de audio y
  /// [artworkPath] la carátula ya cacheada en disco.
  Track toTrack({required String streamUrl, String? artworkPath}) =>
      Track.online(
        externalId: externalId,
        streamUrl: streamUrl,
        title: title,
        artist: artist,
        album: album.isEmpty ? sourceLabel : album,
        durationMs: durationMs,
        artworkPath: artworkPath,
        artworkUrl: artworkUrl,
        sourceLabel: sourceLabel,
      );

  @override
  bool operator ==(Object other) =>
      other is OnlineTrack && other.externalId == externalId;

  @override
  int get hashCode => externalId.hashCode;

  @override
  String toString() => 'OnlineTrack($externalId, $artist - $title)';
}

/// Resultado de resolver una pista online a una URL que `media_kit` puede abrir.
@immutable
class ResolvedStream {
  const ResolvedStream({
    required this.url,
    this.extension = 'mp3',
    this.mimeType = '',
  });

  final String url;

  /// Extensión sugerida para el archivo cuando se descarga.
  final String extension;
  final String mimeType;

  @override
  String toString() => 'ResolvedStream($url)';
}
