part of '../app_database.dart';

/// Fila del historial con datos de la pista resueltos por JOIN.
class RecentPlay {
  const RecentPlay({required this.entry, required this.track});

  final PlayHistoryRow entry;
  final TrackRow track;
}

/// Escucha agregada por día (para gráficas y "Wrapped").
class DailyListening {
  const DailyListening({
    required this.day,
    required this.msPlayed,
    required this.plays,
  });

  final DateTime day;
  final int msPlayed;
  final int plays;
}

@DriftAccessor(tables: [PlayHistory, Tracks])
class HistoryDao extends DatabaseAccessor<AppDatabase> with _$HistoryDaoMixin {
  HistoryDao(super.db);

  /// Abre una entrada de historial al empezar una pista.
  Future<int> startPlay(int trackId) =>
      into(playHistory).insert(PlayHistoryCompanion.insert(trackId: trackId));

  Future<void> finishPlay(
    int historyId, {
    required int msPlayed,
    required bool completed,
  }) => (update(playHistory)..where((h) => h.id.equals(historyId))).write(
    PlayHistoryCompanion(
      msPlayed: Value(msPlayed),
      completed: Value(completed),
    ),
  );

  Future<List<RecentPlay>> recent({int limit = 50}) async {
    final JoinedSelectStatement<HasResultSet, dynamic> query =
        select(playHistory)
            .join([innerJoin(tracks, tracks.id.equalsExp(playHistory.trackId))])
          ..orderBy([OrderingTerm.desc(playHistory.startedAt)])
          ..limit(limit);

    final List<TypedResult> rows = await query.get();
    return rows
        .map(
          (TypedResult row) => RecentPlay(
            entry: row.readTable(playHistory),
            track: row.readTable(tracks),
          ),
        )
        .toList(growable: false);
  }

  Future<int> totalListeningMs({DateTime? since}) async {
    final Expression<int> sum = playHistory.msPlayed.sum();
    final JoinedSelectStatement<HasResultSet, dynamic> query = selectOnly(
      playHistory,
    )..addColumns([sum]);
    if (since != null) {
      query.where(playHistory.startedAt.isBiggerOrEqualValue(since));
    }
    final TypedResult row = await query.getSingle();
    return row.read(sum) ?? 0;
  }

  Future<int> listeningTodayMs() {
    final DateTime now = DateTime.now();
    final DateTime startOfDay = DateTime(now.year, now.month, now.day);
    return totalListeningMs(since: startOfDay);
  }

  Future<List<DailyListening>> listeningByDay({int days = 30}) async {
    final List<QueryRow> rows = await customSelect(
      "SELECT date(started_at, 'localtime') AS day, "
      'sum(ms_played) AS ms, count(*) AS plays '
      'FROM play_history WHERE ms_played > 0 '
      'GROUP BY 1 ORDER BY 1 DESC LIMIT ?',
      variables: [Variable.withInt(days)],
      readsFrom: {playHistory},
    ).get();

    return rows
        .map(
          (QueryRow row) => DailyListening(
            day: DateTime.parse(row.read<String>('day')),
            msPlayed: row.read<int>('ms'),
            plays: row.read<int>('plays'),
          ),
        )
        .toList(growable: false);
  }

  /// Cuenta cuántas veces se completó una pista (>= 90% escuchada).
  Future<int> completedCount(int trackId) async {
    final Expression<int> count = playHistory.id.count();
    final TypedResult row =
        await (selectOnly(playHistory)
              ..addColumns([count])
              ..where(
                playHistory.trackId.equals(trackId) &
                    playHistory.completed.equals(true),
              ))
            .getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> clearHistory() => delete(playHistory).go();
}
