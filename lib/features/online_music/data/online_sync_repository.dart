import 'dart:io';

import '../../../core/database/app_database.dart';
import '../domain/music_source.dart';
import '../domain/online_catalog_items.dart';
import '../domain/online_track.dart';
import 'online_diagnostics.dart';

/// Resultado de una sincronización offline-first.
enum OnlineSyncOutcome {
  /// Guardado localmente; no había red, así que se conservan datos anteriores.
  savedOffline,

  /// La fuente respondió y los metadatos se actualizaron.
  synced,

  /// La fuente falló; las filas anteriores siguen intactas.
  failed,
}

/// Comprueba conectividad antes de consultar una fuente. Se inyecta en tests.
typedef OnlineNetworkProbe = Future<bool> Function();

typedef OnlinePageFetcher = Future<List<OnlineTrack>> Function(
  String? continuation,
);

/// Guarda referencias online en Drift sin inventar filas en `Tracks`.
///
/// Una referencia es solo un puntero: título, carátula ya cacheada en local,
/// enlace público y metadatos de paginación. Nunca se persisten URLs de audio
/// firmadas ni tokens. La sincronización es aditiva y conserva favoritos,
/// contadores y rutas locales ante ausencia de red o fallos parciales.
class OnlineSyncRepository {
  OnlineSyncRepository(this._db, {OnlineNetworkProbe? hasNetwork})
    : _hasNetwork = hasNetwork ?? _defaultNetworkProbe;

  final AppDatabase _db;
  final OnlineNetworkProbe _hasNetwork;

  static Future<bool> _defaultNetworkProbe() async {
    try {
      final List<InternetAddress> addresses = await InternetAddress.lookup(
        'api.audius.co',
      ).timeout(const Duration(seconds: 3));
      return addresses.isNotEmpty;
    } on Object {
      return false;
    }
  }

  Stream<List<OnlineReferenceRow>> watchReferences() =>
      _db.onlineSyncDao.watchReferences();

  Stream<List<OnlineReferenceTrackRow>> watchTracks(String referenceId) =>
      _db.onlineSyncDao.watchTracks(referenceId);

  /// Guarda/actualiza referencias con los datos que ya tiene la pantalla.
  /// No consulta la red: funciona aunque el dispositivo esté sin conexión.
  Future<void> saveReferences(
    Iterable<OnlineCollectionRef> references, {
    String? artworkPath,
  }) async {
    for (final OnlineCollectionRef ref in references) {
      await _db.onlineSyncDao.upsertReference(
        externalId: ref.externalId,
        source: ref.source.name,
        kind: ref.kind.name,
        nativeId: ref.id,
        title: ref.title,
        subtitle: ref.subtitle,
        artworkPath: artworkPath,
        permalink: OnlineDiagnostics.safeReferenceUrl(ref.permalink),
        trackCount: ref.trackCount,
        continuation: ref.continuation,
        hasMore: ref.hasMore,
      );
    }
  }

  /// Importa pistas ya visibles como metadatos, sin resolver audio.
  Future<void> rememberTracks(
    String referenceId,
    Iterable<OnlineTrack> tracks,
  ) async {
    int position = 0;
    for (final OnlineTrack track in tracks) {
      await _db.onlineSyncDao.upsertTrack(
        referenceId: referenceId,
        externalId: track.externalId,
        source:
            MusicSourceIdX.fromExternalId(track.externalId)?.name ?? 'unknown',
        sourceId: track.sourceId,
        title: track.title,
        artist: track.artist,
        album: track.album,
        durationMs: track.durationMs,
        position: position++,
      );
    }
  }

  /// Sincroniza una referencia. Sin red no se consulta [fetchPage] y se dejan
  /// intactos los metadatos, favoritos y contadores guardados.
  Future<OnlineSyncOutcome> syncReference(
    OnlineCollectionRef reference, {
    required OnlinePageFetcher fetchPage,
  }) async {
    // Primero se persiste lo que ya sabemos: offline-first.
    await saveReferences(<OnlineCollectionRef>[reference]);

    if (!await _hasNetwork()) {
      await _db.onlineSyncDao.recordSyncFailure(
        reference.externalId,
        'Sin conexión: se muestran los datos guardados.',
      );
      OnlineDiagnostics.report(
        'OnlineSync',
        'Sin red para ${reference.externalId}; se conservan los datos locales.',
      );
      return OnlineSyncOutcome.savedOffline;
    }

    try {
      final List<OnlineTrack> tracks = await fetchPage(reference.continuation);
      await rememberTracks(reference.externalId, tracks);
      await _db.onlineSyncDao.recordSyncSuccess(
        externalId: reference.externalId,
        trackCount: tracks.isEmpty ? null : tracks.length,
      );
      return OnlineSyncOutcome.synced;
    } on Object catch (error, stack) {
      // Solo se escribe lastError: upserts anteriores y campos locales quedan.
      await _db.onlineSyncDao.recordSyncFailure(
        reference.externalId,
        OnlineDiagnostics.sanitize(error),
      );
      OnlineDiagnostics.report(
        'OnlineSync',
        'Sincronización parcial de ${reference.externalId}',
        error: error,
        stack: stack,
      );
      return OnlineSyncOutcome.failed;
    }
  }

  Future<void> setFavorite(String externalId, bool value) =>
      _db.onlineSyncDao.setFavorite(externalId, value);

  Future<void> recordPlay(String externalId) =>
      _db.onlineSyncDao.recordPlay(externalId);
}
