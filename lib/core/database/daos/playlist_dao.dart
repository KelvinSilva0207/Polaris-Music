part of '../app_database.dart';

@DriftAccessor(tables: [Playlists, PlaylistEntries, Tracks])
class PlaylistDao extends DatabaseAccessor<AppDatabase>
    with _$PlaylistDaoMixin {
  PlaylistDao(super.db);

  Stream<List<PlaylistRow>> watchAll() => (select(
    playlists,
  )..orderBy([(p) => OrderingTerm(expression: p.createdAt)])).watch();

  Future<List<PlaylistRow>> getAll() => select(playlists).get();

  Future<int> create(String name, {String? description}) => into(playlists)
      .insert(
        PlaylistsCompanion.insert(name: name, description: Value(description)),
      );

  Future<void> rename(int id, String name) =>
      (update(playlists)..where((p) => p.id.equals(id))).write(
        PlaylistsCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
      );

  Future<void> deletePlaylist(int id) =>
      (delete(playlists)..where((p) => p.id.equals(id))).go();

  Future<void> addTrack(int playlistId, int trackId) => transaction(() async {
    final Expression<int> maxPos = playlistEntries.position.max();
    final TypedResult row =
        await (selectOnly(playlistEntries)
              ..addColumns([maxPos])
              ..where(playlistEntries.playlistId.equals(playlistId)))
            .getSingle();
    final int position = (row.read(maxPos) ?? -1) + 1;

    await into(playlistEntries).insert(
      PlaylistEntriesCompanion.insert(
        playlistId: playlistId,
        trackId: trackId,
        position: Value(position),
      ),
    );
    await (update(playlists)..where((p) => p.id.equals(playlistId))).write(
      PlaylistsCompanion(updatedAt: Value(DateTime.now())),
    );
  });

  Future<void> removeEntry(int entryId) =>
      (delete(playlistEntries)..where((e) => e.id.equals(entryId))).go();

  Future<List<TrackRow>> tracksOf(int playlistId) async {
    final JoinedSelectStatement<HasResultSet, dynamic> query =
        select(playlistEntries).join([
            innerJoin(tracks, tracks.id.equalsExp(playlistEntries.trackId)),
          ])
          ..where(playlistEntries.playlistId.equals(playlistId))
          ..orderBy([OrderingTerm.asc(playlistEntries.position)]);

    final List<TypedResult> rows = await query.get();
    return rows
        .map((TypedResult row) => row.readTable(tracks))
        .toList(growable: false);
  }

  Future<int> trackCount(int playlistId) async {
    final Expression<int> count = playlistEntries.id.count();
    final TypedResult row =
        await (selectOnly(playlistEntries)
              ..addColumns([count])
              ..where(playlistEntries.playlistId.equals(playlistId)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Rutas de las pistas, en el orden de la lista (para backups).
  Future<List<String>> trackPaths(int playlistId) async {
    final List<QueryRow> rows = await customSelect(
      'SELECT t.path AS path FROM playlist_entries e '
      'INNER JOIN tracks t ON t.id = e.track_id '
      'WHERE e.playlist_id = ? ORDER BY e.position',
      variables: [Variable.withInt(playlistId)],
      readsFrom: {playlistEntries, tracks},
    ).get();
    return rows
        .map((QueryRow row) => row.read<String>('path'))
        .toList(growable: false);
  }

  /// Reordena en una transacción para mantener consistencia si algo falla.
  Future<void> reorder(int playlistId, List<int> entryIdsInOrder) =>
      transaction(() async {
        for (int i = 0; i < entryIdsInOrder.length; i++) {
          await (update(playlistEntries)
                ..where((e) => e.id.equals(entryIdsInOrder[i])))
              .write(PlaylistEntriesCompanion(position: Value(i)));
        }
      });
}
