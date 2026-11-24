import 'package:flutter/material.dart';

import 'music_source.dart';
import 'online_track.dart';

/// Tipo de resultado de una búsqueda en el catálogo online.
enum OnlineSearchType {
  /// Vista agrupada: canciones + álbumes + artistas + playlists/vídeos.
  all,
  songs,
  albums,
  artists,
  playlists;

  String get label => switch (this) {
    OnlineSearchType.all => 'Todos',
    OnlineSearchType.songs => 'Canciones',
    OnlineSearchType.albums => 'Álbumes',
    OnlineSearchType.artists => 'Artistas',
    OnlineSearchType.playlists => 'Playlists',
  };

  IconData get icon => switch (this) {
    OnlineSearchType.all => Icons.apps_rounded,
    OnlineSearchType.songs => Icons.music_note_rounded,
    OnlineSearchType.albums => Icons.album_rounded,
    OnlineSearchType.artists => Icons.person_rounded,
    OnlineSearchType.playlists => Icons.queue_music_rounded,
  };

  /// Los tipos que implican una consulta de colecciones (no de pistas).
  static const List<OnlineSearchType> collectionTypes = <OnlineSearchType>[
    OnlineSearchType.albums,
    OnlineSearchType.artists,
    OnlineSearchType.playlists,
  ];
}

/// Referencia a una colección pública (álbum, artista o playlist) de un
/// proveedor. [id] es el identificador que espera la API (`browseId` en
/// InnerTube, `playlistId` en Spotify, etc.).
@immutable
class OnlineCollectionRef {
  const OnlineCollectionRef({
    required this.externalId,
    required this.id,
    required this.title,
    required this.source,
    required this.kind,
    this.subtitle = '',
    this.artworkUrl,
    this.permalink,
    this.trackCount = 0,
    this.continuation,
    this.hasMore = false,
  });

  final String externalId;
  final String id;
  final String title;
  final String subtitle;
  final String? artworkUrl;
  final String? permalink;
  final MusicSourceId source;
  final OnlineSearchType kind;
  final int trackCount;

  /// Token opcional para pedir la siguiente página de la colección.
  final String? continuation;
  final bool hasMore;

  OnlineCollectionRef copyWith({
    String? title,
    String? subtitle,
    String? artworkUrl,
    String? permalink,
    int? trackCount,
    String? continuation,
    bool? hasMore,
  }) => OnlineCollectionRef(
    externalId: externalId,
    id: id,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    artworkUrl: artworkUrl ?? this.artworkUrl,
    permalink: permalink ?? this.permalink,
    source: source,
    kind: kind,
    trackCount: trackCount ?? this.trackCount,
    continuation: continuation ?? this.continuation,
    hasMore: hasMore ?? this.hasMore,
  );

  @override
  bool operator ==(Object other) =>
      other is OnlineCollectionRef && other.externalId == externalId;

  @override
  int get hashCode => externalId.hashCode;

  @override
  String toString() => 'OnlineCollectionRef($externalId, $title)';
}

/// Una página de pistas de una colección.
///
/// [tracks] ya viene deduplicada por proveedor; [continuation] se reenvía tal
/// cual a la fuente para pedir la siguiente. Cuando [hasMore] es `false` no
/// debe ofrecerse "Cargar más".
@immutable
class CollectionPage {
  const CollectionPage({
    this.tracks = const <OnlineTrack>[],
    this.continuation,
    this.hasMore = false,
  });

  final List<OnlineTrack> tracks;
  final String? continuation;
  final bool hasMore;

  static const CollectionPage empty = CollectionPage();

  /// Página sin token: las fuentes que no soportan continuación devuelven
  /// toda la colección de una vez.
  factory CollectionPage.only(List<OnlineTrack> tracks) =>
      CollectionPage(tracks: List<OnlineTrack>.unmodifiable(tracks));
}
