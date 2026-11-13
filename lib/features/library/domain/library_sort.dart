import '../../../../core/models/track.dart';

/// Criterios de orden disponibles para la biblioteca y las colas.
enum LibrarySort {
  title('Título'),
  artist('Artista'),
  album('Álbum'),
  addedAt('Fecha de alta'),
  year('Año'),
  duration('Duración'),
  plays('Reproducciones');

  const LibrarySort(this.label);

  final String label;
}

/// Ordena (o invierte) una lista de pistas sin mutar la original.
List<Track> sortTracks(
  List<Track> tracks, {
  required LibrarySort sort,
  bool ascending = true,
}) {
  final List<Track> copy = List<Track>.of(tracks);
  int compare(Track a, Track b) {
    final int result = switch (sort) {
      LibrarySort.title => a.title.toLowerCase().compareTo(
        b.title.toLowerCase(),
      ),
      LibrarySort.artist => a.artist.toLowerCase().compareTo(
        b.artist.toLowerCase(),
      ),
      LibrarySort.album => a.album.toLowerCase().compareTo(
        b.album.toLowerCase(),
      ),
      LibrarySort.addedAt => a.id.compareTo(b.id),
      LibrarySort.year => (a.year ?? 0).compareTo(b.year ?? 0),
      LibrarySort.duration => a.durationMs.compareTo(b.durationMs),
      LibrarySort.plays => a.playCount.compareTo(b.playCount),
    };
    if (result != 0) return result;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  copy.sort(ascending ? compare : (Track a, Track b) => compare(b, a));
  return copy;
}
