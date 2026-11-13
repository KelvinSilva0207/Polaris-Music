import 'dart:math' as math;

import '../../../core/database/app_database.dart';
import '../../../core/models/track.dart';

/// Totales de escucha para el panel de estadísticas.
class ListeningStats {
  const ListeningStats({
    required this.totalMs,
    required this.todayMs,
    required this.totalPlays,
    required this.completedPlays,
    required this.topTracks,
    required this.recent,
    required this.byDay,
  });

  final int totalMs;
  final int todayMs;
  final int totalPlays;
  final int completedPlays;
  final List<Track> topTracks;
  final List<RecentPlay> recent;
  final List<DailyListening> byDay;

  Duration get total => Duration(milliseconds: totalMs);
  Duration get today => Duration(milliseconds: todayMs);
}

/// Resumen anual estilo "Wrapped".
class WrappedStats {
  const WrappedStats({
    required this.year,
    required this.totalMs,
    required this.totalPlays,
    required this.uniqueTracks,
    required this.topArtist,
    required this.topTrack,
    required this.byDay,
  });

  final int year;
  final int totalMs;
  final int totalPlays;
  final int uniqueTracks;
  final String topArtist;
  final Track? topTrack;
  final List<DailyListening> byDay;

  Duration get total => Duration(milliseconds: totalMs);
  bool get isEmpty => totalPlays == 0;
}

/// Consultas de estadísticas y recomendaciones.
class StatsService {
  StatsService(AppDatabase db)
    : _history = db.historyDao,
      _tracks = db.trackDao;

  final HistoryDao _history;
  final TrackDao _tracks;

  Future<ListeningStats> listeningStats() async {
    final int totalMs = await _history.totalListeningMs();
    final int todayMs = await _history.listeningTodayMs();
    final List<DailyListening> byDay = await _history.listeningByDay(days: 30);
    final List<RecentPlay> recent = await _history.recent(limit: 50);
    final List<TrackRow> topRows = await _tracks.topTracks(limit: 25);
    final List<Track> topTracks = topRows
        .map(Track.fromRow)
        .toList(growable: false);

    final int totalPlays = byDay.fold<int>(
      0,
      (int sum, DailyListening day) => sum + day.plays,
    );
    final int completedPlays = topTracks.fold<int>(
      0,
      (int sum, Track t) => sum + t.playCount,
    );

    return ListeningStats(
      totalMs: totalMs,
      todayMs: todayMs,
      totalPlays: totalPlays,
      completedPlays: completedPlays,
      topTracks: topTracks,
      recent: recent,
      byDay: byDay,
    );
  }

  Future<WrappedStats> wrapped({int? year}) async {
    final int targetYear = year ?? DateTime.now().year;
    final List<DailyListening> byDay = await _history.listeningByDay(days: 366);
    final List<DailyListening> yearDays = byDay
        .where((DailyListening d) => d.day.year == targetYear)
        .toList(growable: false);

    final int totalMs = yearDays.fold<int>(
      0,
      (int sum, DailyListening d) => sum + d.msPlayed,
    );
    final int totalPlays = yearDays.fold<int>(
      0,
      (int sum, DailyListening d) => sum + d.plays,
    );

    final List<TrackRow> all = await _tracks.getAll();
    final List<TrackRow> played = all
        .where((TrackRow t) => t.playCount > 0)
        .toList(growable: false);
    final List<TrackRow> top = List<TrackRow>.of(played)
      ..sort((TrackRow a, TrackRow b) => b.playCount.compareTo(a.playCount));

    final Map<String, int> artistPlays = <String, int>{};
    for (final TrackRow track in played) {
      artistPlays.update(
        track.artist,
        (int value) => value + track.playCount,
        ifAbsent: () => track.playCount,
      );
    }
    String topArtist = 'Sin datos';
    int best = 0;
    for (final MapEntry<String, int> entry in artistPlays.entries) {
      if (entry.value > best) {
        best = entry.value;
        topArtist = entry.key;
      }
    }

    return WrappedStats(
      year: targetYear,
      totalMs: totalMs,
      totalPlays: totalPlays,
      uniqueTracks: played.length,
      topArtist: topArtist,
      topTrack: top.isEmpty ? null : Track.fromRow(top.first),
      byDay: yearDays.reversed.toList(growable: false),
    );
  }

  /// Recomendaciones simples y explicables:
  /// 1. Artistas favoritos con pistas aún no escuchadas.
  /// 2. Pistas nunca reproducidas de la biblioteca.
  /// 3. Favoritos como último recurso.
  Future<List<Track>> recommendations({int limit = 20}) async {
    final List<TrackRow> all = await _tracks.getAll();
    if (all.isEmpty) return const <Track>[];

    final Set<String> favoriteArtists = <String>{};
    final Set<int> favoriteIds = <int>{};
    for (final TrackRow row in all) {
      if (row.isFavorite) {
        favoriteArtists.add(row.artist);
        favoriteIds.add(row.id);
      }
    }
    for (final TrackRow row in await _tracks.topTracks(limit: 15)) {
      favoriteArtists.add(row.artist);
    }

    final List<TrackRow> byArtist =
        all
            .where(
              (TrackRow t) =>
                  t.playCount == 0 && favoriteArtists.contains(t.artist),
            )
            .toList(growable: false)
          ..sort(
            (TrackRow a, TrackRow b) =>
                a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
          );

    final List<TrackRow> unplayed =
        all
            .where((TrackRow t) => t.playCount == 0 && !byArtist.contains(t))
            .toList(growable: false)
          ..shuffle(math.Random(all.length));

    final List<TrackRow> favorites = all
        .where((TrackRow t) => favoriteIds.contains(t.id))
        .toList(growable: false);

    final List<TrackRow> selected = <TrackRow>[];
    final Set<int> seen = <int>{};
    for (final List<TrackRow> pool in <List<TrackRow>>[
      byArtist,
      unplayed,
      favorites,
    ]) {
      for (final TrackRow row in pool) {
        if (selected.length >= limit) break;
        if (seen.add(row.id)) selected.add(row);
      }
    }

    return selected.map(Track.fromRow).toList(growable: false);
  }

  Future<void> clearHistory() => _history.clearHistory();

  /// Umbral de escucha para contar reproducción (coincide con el recorder).
  static Duration countedThreshold(Duration duration) {
    final Duration half = Duration(milliseconds: duration.inMilliseconds ~/ 2);
    const Duration max = Duration(seconds: 30);
    return half < max ? half : max;
  }
}
