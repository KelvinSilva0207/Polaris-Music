import '../../../core/models/track.dart';

/// Reglas para listas inteligentes: no guardan pistas, se evalúan al abrir.
enum SmartPlaylistRule {
  favorites('Favoritos', 'Pistas marcadas con estrella.'),
  mostPlayed('Más reproducidas', 'Ordenadas por número de reproducciones.'),
  recentlyAdded(
    'Añadidas recientemente',
    'Últimas incorporadas a la biblioteca.',
  ),
  recentlyPlayed('Escuchadas recientemente', 'Últimas que sonaron.'),
  longTracks('Duración larga', 'Pistas de más de cinco minutos.');

  const SmartPlaylistRule(this.label, this.description);

  final String label;
  final String description;

  static SmartPlaylistRule? fromName(String value) {
    for (final SmartPlaylistRule rule in SmartPlaylistRule.values) {
      if (rule.name == value) return rule;
    }
    return null;
  }

  /// Aplica la regla sobre la biblioteca y devuelve un orden nuevo.
  List<Track> apply(List<Track> tracks, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    switch (this) {
      case SmartPlaylistRule.favorites:
        return tracks
            .where((Track track) => track.isFavorite)
            .toList(growable: false);
      case SmartPlaylistRule.mostPlayed:
        final List<Track> result = tracks.toList(growable: false);
        result.sort((Track a, Track b) => b.playCount.compareTo(a.playCount));
        return result;
      case SmartPlaylistRule.recentlyAdded:
        final List<Track> result = tracks
            .where(
              (Track track) =>
                  track.addedAt != null &&
                  reference.difference(track.addedAt!).inDays <= 30,
            )
            .toList(growable: false);
        result.sort((Track a, Track b) => b.addedAt!.compareTo(a.addedAt!));
        return result;
      case SmartPlaylistRule.recentlyPlayed:
        final List<Track> result = tracks
            .where((Track track) => track.lastPlayedAt != null)
            .toList(growable: false);
        result.sort(
          (Track a, Track b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!),
        );
        return result;
      case SmartPlaylistRule.longTracks:
        return tracks
            .where(
              (Track track) => track.duration >= const Duration(minutes: 5),
            )
            .toList(growable: false);
    }
  }
}
