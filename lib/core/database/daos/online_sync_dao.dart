part of '../app_database.dart';

/// Acceso a las referencias online guardadas para uso offline.
///
/// El upsert remoto solo toca columnas remotas: [isFavorite] y [playCount] se
/// dejan fuera a propósito para que una sincronización nunca borre el estado
/// local del usuario.
@DriftAccessor(tables: [OnlineReferences, OnlineReferenceTracks])
class OnlineSyncDao extends DatabaseAccessor<AppDatabase>
    with _$OnlineSyncDaoMixin {
  OnlineSyncDao(super.db);

  Stream<List<OnlineReferenceRow>> watchReferences() =>
      select(onlineReferences).watch();

  Stream<List<OnlineReferenceTrackRow>> watchTracks(String referenceId) =>
      (select(onlineReferenceTracks)
            ..where((t) => t.referenceId.equals(referenceId))
            ..orderBy(<OrderingTerm Function(OnlineReferenceTracks)>[
              (t) => OrderingTerm.asc(t.position),
            ]))
          .watch();

  Future<List<OnlineReferenceRow>> allReferences() =>
      select(onlineReferences).get();

  Future<List<OnlineReferenceTrackRow>> tracksFor(String referenceId) =>
      (select(onlineReferenceTracks)
            ..where((t) => t.referenceId.equals(referenceId))
            ..orderBy(<OrderingTerm Function(OnlineReferenceTracks)>[
              (t) => OrderingTerm.asc(t.position),
            ]))
          .get();

  /// Inserta o actualiza solo los campos que vienen de la fuente.
  Future<void> upsertReference({
    required String externalId,
    required String source,
    required String kind,
    required String nativeId,
    required String title,
    String subtitle = '',
    String? artworkPath,
    String? permalink,
    int trackCount = 0,
    String? continuation,
    bool hasMore = false,
  }) => into(onlineReferences).insertOnConflictUpdate(
    OnlineReferencesCompanion.insert(
      externalId: externalId,
      source: source,
      kind: kind,
      nativeId: nativeId,
      title: title,
      subtitle: Value(subtitle),
      artworkPath: Value(artworkPath),
      permalink: Value(permalink),
      trackCount: Value(trackCount),
      continuation: Value(continuation),
      hasMore: Value(hasMore),
      syncedAt: Value(DateTime.now()),
    ),
  );

  /// Intento fallido: se conservan datos y contadores anteriores.
  Future<void> recordSyncFailure(String externalId, String error) =>
      (update(
        onlineReferences,
      )..where((t) => t.externalId.equals(externalId))).write(
        OnlineReferencesCompanion(
          syncedAt: Value(DateTime.now()),
          lastError: Value(error),
        ),
      );

  Future<void> recordSyncSuccess({
    required String externalId,
    String? continuation,
    bool hasMore = false,
    int? trackCount,
  }) async {
    final OnlineReferencesCompanion companion = OnlineReferencesCompanion(
      syncedAt: Value(DateTime.now()),
      lastSuccessfulSyncAt: Value(DateTime.now()),
      lastError: const Value(null),
      continuation: Value(continuation),
      hasMore: Value(hasMore),
    );
    await (update(
      onlineReferences,
    )..where((t) => t.externalId.equals(externalId))).write(
      trackCount == null
          ? companion
          : companion.copyWith(trackCount: Value(trackCount)),
    );
  }

  Future<void> setFavorite(String externalId, bool value) =>
      (update(onlineReferences)..where((t) => t.externalId.equals(externalId)))
          .write(OnlineReferencesCompanion(isFavorite: Value(value)));

  /// Contador local: nunca lo escribe la sincronización.
  Future<void> recordPlay(String externalId) => customStatement(
    'UPDATE online_references SET play_count = play_count + 1 '
    'WHERE external_id = ?',
    <Object?>[externalId],
  );

  /// Los metadatos de pistas se acumulan: un fallo parcial no borra los
  /// elementos ya guardados en intentos anteriores.
  Future<void> upsertTrack({
    required String referenceId,
    required String externalId,
    required String source,
    required String sourceId,
    required String title,
    required String artist,
    String album = '',
    int durationMs = 0,
    required int position,
  }) => into(onlineReferenceTracks).insertOnConflictUpdate(
    OnlineReferenceTracksCompanion.insert(
      referenceId: referenceId,
      externalId: externalId,
      source: source,
      sourceId: sourceId,
      title: title,
      artist: artist,
      album: Value(album),
      durationMs: Value(durationMs),
      position: Value(position),
    ),
  );
}
