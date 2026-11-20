import 'package:flutter/material.dart';

import 'music_source.dart';

/// Tipo de resultado de una búsqueda en el catálogo online.
enum OnlineSearchType {
  songs,
  albums,
  artists,
  playlists;

  String get label => switch (this) {
    OnlineSearchType.songs => 'Canciones',
    OnlineSearchType.albums => 'Álbumes',
    OnlineSearchType.artists => 'Artistas',
    OnlineSearchType.playlists => 'Playlists',
  };

  IconData get icon => switch (this) {
    OnlineSearchType.songs => Icons.music_note_rounded,
    OnlineSearchType.albums => Icons.album_rounded,
    OnlineSearchType.artists => Icons.person_rounded,
    OnlineSearchType.playlists => Icons.queue_music_rounded,
  };
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

  @override
  bool operator ==(Object other) =>
      other is OnlineCollectionRef && other.externalId == externalId;

  @override
  int get hashCode => externalId.hashCode;

  @override
  String toString() => 'OnlineCollectionRef($externalId, $title)';
}
