part of '../app_database.dart';

@DriftAccessor(tables: [Lyrics, Tracks])
class LyricsDao extends DatabaseAccessor<AppDatabase> with _$LyricsDaoMixin {
  LyricsDao(super.db);

  Future<LyricRow?> forTrack(int trackId) => (select(
    lyrics,
  )..where((l) => l.trackId.equals(trackId))).getSingleOrNull();

  Future<void> save(
    int trackId,
    String content, {
    bool synced = true,
    String source = 'local',
  }) => into(lyrics).insertOnConflictUpdate(
    LyricsCompanion.insert(
      trackId: Value(trackId),
      content: content,
      synced: Value(synced),
      source: Value(source),
      fetchedAt: Value(DateTime.now()),
    ),
  );

  Future<void> deleteForTrack(int trackId) =>
      (delete(lyrics)..where((l) => l.trackId.equals(trackId))).go();

  /// Todas las letras junto a la ruta de su pista (para backups).
  Future<List<LyricBackupEntry>> allWithPaths() async {
    final List<QueryRow> rows = await customSelect(
      'SELECT t.path AS path, l.content AS content, '
      'l.synced AS synced, l.source AS source '
      'FROM lyrics l INNER JOIN tracks t ON t.id = l.track_id',
      readsFrom: {lyrics, tracks},
    ).get();
    return rows
        .map(
          (QueryRow row) => LyricBackupEntry(
            path: row.read<String>('path'),
            content: row.read<String>('content'),
            synced: row.read<bool>('synced'),
            source: row.read<String>('source'),
          ),
        )
        .toList(growable: false);
  }
}

/// Letra serializada para exportar/importar respaldos.
class LyricBackupEntry {
  const LyricBackupEntry({
    required this.path,
    required this.content,
    required this.synced,
    required this.source,
  });

  final String path;
  final String content;
  final bool synced;
  final String source;
}
