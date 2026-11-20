import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../utils/artwork_paths.dart';
import '../utils/metadata_text.dart';

/// Procedencia de una pista.
///
/// - [local]: archivo indexado de una carpeta del usuario.
/// - [downloaded]: archivo traído por el módulo online y registrado en Drift.
/// - [online]: transmisión en red; no se persiste y su `id` es efímero.
enum TrackOrigin { local, downloaded, online }

/// URL alternativa de audio para la misma pista.
///
/// YouTube Music entrega varios formatos ligados a un cliente InnerTube
/// concreto (`IOS`, `ANDROID_MUSIC`, `WEB_REMIX`). Cada URL debe abrirse con el
/// `User-Agent` de ese cliente; mezclarlos produce el temido error 403 de
/// `googlevideo.com`. Guardamos las alternativas junto a la pista para que el
/// motor pueda probarlas sin volver a consultar la red.
@immutable
class StreamAlternative {
  const StreamAlternative({
    required this.url,
    required this.httpHeaders,
    this.label = '',
  });

  final String url;
  final Map<String, String> httpHeaders;

  /// Etiqueta legible del cliente/usuario que generó esta URL (solo logs).
  final String label;
}

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
    this.artworkUrl,
    this.replayGainTrackDb,
    this.replayGainAlbumDb,
    this.isFavorite = false,
    this.playCount = 0,
    this.lastPlayedAt,
    this.addedAt,
    this.updatedAt,
    this.origin = TrackOrigin.local,
    this.externalId,
    this.sourceLabel,
    this.httpHeaders = const <String, String>{},
    this.streamAlternatives = const <StreamAlternative>[],
  });

  /// Pista efímera de streaming: no existe en la biblioteca.
  ///
  /// El [id] se deriva del identificador externo para que la cola, el widget
  /// activo y la carátula sean estables entre reconstrucciones.
  factory Track.online({
    required String externalId,
    required String streamUrl,
    required String title,
    required String artist,
    String album = 'Online',
    required int durationMs,
    String? artworkPath,
    String? artworkUrl,
    String? sourceLabel,
    Map<String, String> httpHeaders = const <String, String>{},
    List<StreamAlternative> streamAlternatives = const <StreamAlternative>[],
  }) => Track(
    id: ephemeralId(externalId),
    path: streamUrl,
    title: title,
    artist: artist,
    album: album,
    durationMs: durationMs,
    artworkPath: artworkPath,
    artworkUrl: artworkUrl,
    format: 'STREAM',
    origin: TrackOrigin.online,
    externalId: externalId,
    sourceLabel: sourceLabel,
    httpHeaders: httpHeaders,
    streamAlternatives: streamAlternatives,
  );

  /// Id negativo y estable para pistas que no viven en Drift.
  static int ephemeralId(String externalId) {
    int hash = 0x811c9dc5;
    for (final int codeUnit in externalId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return -(hash % 0x7fffffff) - 1;
  }

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

  /// URL de carátula remota (solo pistas [TrackOrigin.online]).
  final String? artworkUrl;
  final double? replayGainTrackDb;
  final double? replayGainAlbumDb;
  final bool isFavorite;
  final int playCount;
  final DateTime? lastPlayedAt;
  final DateTime? addedAt;
  final DateTime? updatedAt;
  final TrackOrigin origin;

  /// Identificador en la fuente online; `null` para pistas locales puras.
  final String? externalId;

  /// Nombre de la fuente online (p. ej. `Audius`).
  final String? sourceLabel;

  /// Cabeceras HTTP necesarias para abrir la URL de una pista online.
  final Map<String, String> httpHeaders;

  /// URLs de respaldo con sus propias cabeceras, en orden de preferencia.
  final List<StreamAlternative> streamAlternatives;

  bool get isOnline => origin == TrackOrigin.online;
  bool get isDownloaded => origin == TrackOrigin.downloaded;
  bool get isLocal => origin == TrackOrigin.local;

  /// Solo las pistas persistidas admiten favoritos, estadísticas y letras en
  /// caché.
  bool get isPersisted => id > 0;

  Duration get duration => Duration(milliseconds: durationMs);

  String get subtitle =>
      album.isEmpty || album == 'Desconocido' ? artist : '$artist · $album';

  factory Track.fromRow(TrackRow row) => Track(
    id: row.id,
    path: row.path,
    title: MetadataText.clean(row.title, p.basenameWithoutExtension(row.path)),
    artist: MetadataText.clean(row.artist, 'Desconocido'),
    album: MetadataText.clean(row.album, 'Desconocido'),
    albumArtist: MetadataText.clean(row.albumArtist, ''),
    genre: MetadataText.clean(row.genre, ''),
    year: row.year,
    trackNumber: row.trackNumber,
    discNumber: row.discNumber,
    bitrate: row.bitrate,
    sampleRate: row.sampleRate,
    format: row.format ?? '',
    fileSize: row.fileSize,
    durationMs: row.durationMs,
    artworkPath: resolveArtworkPath(row.artworkPath, row.path),
    replayGainTrackDb: row.replayGainTrackDb,
    replayGainAlbumDb: row.replayGainAlbumDb,
    isFavorite: row.isFavorite,
    playCount: row.playCount,
    lastPlayedAt: row.lastPlayedAt,
    addedAt: row.addedAt,
    updatedAt: row.updatedAt,
    origin: row.source == 'download'
        ? TrackOrigin.downloaded
        : TrackOrigin.local,
    externalId: row.externalId,
  );

  Track copyWith({
    String? path,
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? genre,
    int? year,
    int? trackNumber,
    int? discNumber,
    String? artworkPath,
    bool? isFavorite,
    int? playCount,
    DateTime? lastPlayedAt,
    DateTime? addedAt,
    DateTime? updatedAt,
    double? replayGainTrackDb,
    double? replayGainAlbumDb,
    Map<String, String>? httpHeaders,
    List<StreamAlternative>? streamAlternatives,
  }) => Track(
    id: id,
    path: path ?? this.path,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    albumArtist: albumArtist ?? this.albumArtist,
    genre: genre ?? this.genre,
    year: year ?? this.year,
    trackNumber: trackNumber ?? this.trackNumber,
    discNumber: discNumber ?? this.discNumber,
    bitrate: bitrate,
    sampleRate: sampleRate,
    format: format,
    fileSize: fileSize,
    durationMs: durationMs,
    artworkPath: artworkPath ?? this.artworkPath,
    artworkUrl: artworkUrl,
    replayGainTrackDb: replayGainTrackDb ?? this.replayGainTrackDb,
    replayGainAlbumDb: replayGainAlbumDb ?? this.replayGainAlbumDb,
    isFavorite: isFavorite ?? this.isFavorite,
    playCount: playCount ?? this.playCount,
    lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    addedAt: addedAt ?? this.addedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    origin: origin,
    externalId: externalId,
    sourceLabel: sourceLabel,
    httpHeaders: httpHeaders ?? this.httpHeaders,
    streamAlternatives: streamAlternatives ?? this.streamAlternatives,
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
