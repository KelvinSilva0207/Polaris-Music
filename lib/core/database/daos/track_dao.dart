part of '../app_database.dart';

/// Grupo de pistas que probablemente son el mismo archivo duplicado.
class DuplicateGroup {
  const DuplicateGroup({
    required this.title,
    required this.artist,
    required this.durationMs,
    required this.ids,
  });

  final String title;
  final String artist;
  final int durationMs;
  final List<int> ids;

  int get count => ids.length;
}

@DriftAccessor(tables: [Tracks])
class TrackDao extends DatabaseAccessor<AppDatabase> with _$TrackDaoMixin {
  TrackDao(super.db);

  Stream<List<TrackRow>> watchAll({String query = ''}) {
    final SimpleSelectStatement<$TracksTable, TrackRow> selectStatement =
        select(tracks);
    final String term = query.trim();
    if (term.isNotEmpty) {
      final String pattern = '%${_escapeLike(term)}%';
      selectStatement.where(
        (t) =>
            t.title.like(pattern) |
            t.artist.like(pattern) |
            t.album.like(pattern),
      );
    }
    selectStatement.orderBy([
      (t) => OrderingTerm(expression: t.artist),
      (t) => OrderingTerm(expression: t.album),
      (t) => OrderingTerm(expression: t.trackNumber),
    ]);
    return selectStatement.watch();
  }

  Stream<List<TrackRow>> watchFavorites() =>
      (select(tracks)
            ..where((t) => t.isFavorite.equals(true))
            ..orderBy([(t) => OrderingTerm(expression: t.title)]))
          .watch();

  Future<List<TrackRow>> getAll() => select(tracks).get();

  Future<int> count() async {
    final Expression<int> c = tracks.id.count();
    final TypedResult row = await (selectOnly(
      tracks,
    )..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }

  Future<TrackRow?> byId(int id) =>
      (select(tracks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<TrackRow?> byPath(String path) =>
      (select(tracks)..where((t) => t.path.equals(path))).getSingleOrNull();

  Future<TrackRow?> byExternalId(String externalId) => (select(
    tracks,
  )..where((t) => t.externalId.equals(externalId))).getSingleOrNull();

  Future<bool> hasExternalId(String externalId) async =>
      await byExternalId(externalId) != null;

  /// Identificadores externos ya descargados, para pintar la nube en la UI.
  Stream<Set<String>> watchDownloadedExternalIds() =>
      (select(tracks)..where((t) => t.source.equals('download'))).watch().map(
        (List<TrackRow> rows) => rows
            .map((TrackRow row) => row.externalId)
            .whereType<String>()
            .toSet(),
      );

  Future<List<String>> favoritePaths() async {
    final List<TypedResult> rows =
        await (selectOnly(tracks)
              ..addColumns([tracks.path])
              ..where(tracks.isFavorite.equals(true)))
            .get();
    return rows
        .map((TypedResult r) => r.read(tracks.path)!)
        .toList(growable: false);
  }

  Future<void> setFavoriteByPath(String path, bool value) =>
      (update(tracks)..where((t) => t.path.equals(path))).write(
        TracksCompanion(isFavorite: Value(value)),
      );

  Future<List<TrackRow>> search(String term) {
    final String pattern = '%${_escapeLike(term.trim())}%';
    return (select(tracks)
          ..where(
            (t) =>
                t.title.like(pattern) |
                t.artist.like(pattern) |
                t.album.like(pattern),
          )
          ..limit(100))
        .get();
  }

  /// Inserta o actualiza una pista escaneada sin perder estadísticas.
  ///
  /// Devuelve el id de la fila.
  Future<int> upsertScanned(TracksCompanion companion) {
    return transaction(() async {
      final String path = companion.path.value;
      final TrackRow? existing = await (select(
        tracks,
      )..where((t) => t.path.equals(path))).getSingleOrNull();

      if (existing == null) {
        return into(tracks).insert(companion);
      }

      await (update(tracks)..where((t) => t.id.equals(existing.id))).write(
        companion.copyWith(
          // Nunca sobrescribir datos de usuario/estadísticas ni el origen.
          addedAt: Value(existing.addedAt),
          isFavorite: Value(existing.isFavorite),
          playCount: Value(existing.playCount),
          skipCount: Value(existing.skipCount),
          lastPlayedAt: Value(existing.lastPlayedAt),
          source: Value(existing.source),
          externalId: Value(existing.externalId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return existing.id;
    });
  }

  /// Inserta o actualiza el registro de una pista descargada.
  ///
  /// La deduplicación prioriza el `externalId` y cae a la ruta cuando la fuente
  /// no expone identificador. Nunca pisa favoritos ni contadores.
  Future<int> upsertDownloaded(TracksCompanion companion) {
    return transaction(() async {
      final String? externalId = companion.externalId.present
          ? companion.externalId.value
          : null;

      TrackRow? match;
      if (externalId != null) {
        match = await byExternalId(externalId);
      }
      match ??= await byPath(companion.path.value);

      if (match == null) {
        return into(tracks).insert(companion);
      }

      final TrackRow existing = match;
      await (update(tracks)..where((t) => t.id.equals(existing.id))).write(
        companion.copyWith(
          addedAt: Value(existing.addedAt),
          isFavorite: Value(existing.isFavorite),
          playCount: Value(existing.playCount),
          skipCount: Value(existing.skipCount),
          lastPlayedAt: Value(existing.lastPlayedAt),
          source: const Value('download'),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return existing.id;
    });
  }

  Future<void> setFavorite(int id, bool value) =>
      (update(tracks)..where((t) => t.id.equals(id))).write(
        TracksCompanion(isFavorite: Value(value)),
      );

  /// Edición de metadatos desde la app (solo Drift).
  ///
  /// Escribir los tags en el archivo original queda para una fase posterior;
  /// aquí no se toca el audio, solo la proyección local.
  Future<void> updateMetadata(
    int id, {
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? genre,
    int? year,
    int? trackNumber,
    int? discNumber,
  }) => (update(tracks)..where((t) => t.id.equals(id))).write(
    TracksCompanion(
      title: title == null ? const Value.absent() : Value(title),
      artist: artist == null ? const Value.absent() : Value(artist),
      album: album == null ? const Value.absent() : Value(album),
      albumArtist: albumArtist == null
          ? const Value.absent()
          : Value(albumArtist.isEmpty ? null : albumArtist),
      genre: genre == null
          ? const Value.absent()
          : Value(genre.isEmpty ? null : genre),
      year: year == null ? const Value.absent() : Value(year),
      trackNumber: trackNumber == null
          ? const Value.absent()
          : Value(trackNumber),
      discNumber: discNumber == null ? const Value.absent() : Value(discNumber),
      updatedAt: Value(DateTime.now()),
    ),
  );

  Future<void> incrementSkip(int id) => customUpdate(
    'UPDATE tracks SET skip_count = skip_count + 1 WHERE id = ?',
    variables: [Variable.withInt(id)],
    updates: {tracks},
  );

  Future<void> registerPlay(int id, {required bool completed}) => customUpdate(
    'UPDATE tracks SET play_count = play_count + 1, '
    'last_played_at = ?, updated_at = ? WHERE id = ?',
    variables: [
      Variable.withDateTime(DateTime.now()),
      Variable.withDateTime(DateTime.now()),
      Variable.withInt(id),
    ],
    updates: {tracks},
  );

  Future<List<TrackRow>> topTracks({int limit = 25}) =>
      (select(tracks)
            ..where((t) => t.playCount.isBiggerThanValue(0))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.playCount,
                mode: OrderingMode.desc,
              ),
              (t) => OrderingTerm(
                expression: t.lastPlayedAt,
                mode: OrderingMode.desc,
              ),
            ])
            ..limit(limit))
          .get();

  /// Duplicados por título + artista + duración (tolerancia de 1 segundo).
  ///
  /// Se agrupa en SQL para no traer toda la biblioteca a memoria.
  Future<List<DuplicateGroup>> findDuplicates() async {
    final List<QueryRow> rows = await customSelect(
      'SELECT lower(title) AS t, lower(artist) AS a, '
      '(duration_ms / 1000) AS d, group_concat(id) AS ids, count(*) AS c '
      'FROM tracks '
      'GROUP BY 1, 2, 3 HAVING c > 1 ORDER BY c DESC LIMIT 200',
      readsFrom: {tracks},
    ).get();

    return rows
        .map((QueryRow row) {
          return DuplicateGroup(
            title: row.read<String>('t'),
            artist: row.read<String>('a'),
            durationMs: (row.read<int>('d')) * 1000,
            ids: (row.read<String>('ids'))
                .split(',')
                .map(int.parse)
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  Future<List<String>> allPaths() async {
    final List<TypedResult> rows = await (selectOnly(
      tracks,
    )..addColumns([tracks.path])).get();
    return rows
        .map((TypedResult r) => r.read(tracks.path)!)
        .toList(growable: false);
  }

  Future<void> deleteByIds(List<int> ids) async {
    if (ids.isEmpty) return;
    await (delete(tracks)..where((t) => t.id.isIn(ids))).go();
  }

  Future<void> deleteMissingPaths(Set<String> existingPaths) async {
    final List<TrackRow> all = await select(tracks).get();
    final List<int> missing = all
        .where(
          (TrackRow t) =>
              !existingPaths.contains(t.path) && t.source != 'download',
        )
        .map((TrackRow t) => t.id)
        .toList(growable: false);
    await deleteByIds(missing);
  }

  Future<void> clearLibrary() => delete(tracks).go();

  static String _escapeLike(String input) => input
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');
}
