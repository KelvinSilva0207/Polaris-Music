import 'package:flutter/foundation.dart';

import 'music_source.dart';
import 'online_track.dart';

/// Resultado de una consulta a varias fuentes.
@immutable
class CatalogResult {
  const CatalogResult({
    required this.query,
    required this.isTrending,
    required this.sources,
    this.loadedAt,
  });

  final String query;
  final bool isTrending;
  final List<SourceResult> sources;

  /// Unión deduplicada de los resultados parciales, en orden de proveedor.
  List<OnlineTrack> get tracks {
    final List<OnlineTrack> merged = <OnlineTrack>[];
    final Set<String> seen = <String>{};
    for (final SourceResult result in sources) {
      for (final OnlineTrack track in result.items) {
        if (seen.add(track.externalId)) merged.add(track);
      }
    }
    return List<OnlineTrack>.unmodifiable(merged);
  }

  List<SourceResult> get failed => sources
      .where((SourceResult result) => !result.ok)
      .toList(growable: false);

  final DateTime? loadedAt;
}

/// Orquesta proveedores sin acoplar la UI a HTTP ni a credenciales.
///
/// Cada fuente se consulta de forma independiente y sus errores se convierten
/// en estados, de modo que una caída parcial nunca aborta la búsqueda global.
class MusicSourceCatalog {
  const MusicSourceCatalog(this._providers);

  final List<MusicSourceProvider> _providers;

  List<MusicSourceProvider> get providers =>
      List<MusicSourceProvider>.unmodifiable(_providers);

  Map<MusicSourceId, MusicSourceStatus> get statuses =>
      Map<MusicSourceId, MusicSourceStatus>.unmodifiable(
        <MusicSourceId, MusicSourceStatus>{
          for (final MusicSourceProvider provider in _providers)
            provider.id: provider.status,
        },
      );

  MusicSourceProvider? providerFor(MusicSourceId id) {
    for (final MusicSourceProvider provider in _providers) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  Future<CatalogResult> search(
    String query, {
    Set<MusicSourceId>? only,
    int limit = 25,
  }) =>
      _query(query: query.trim(), isTrending: false, only: only, limit: limit);

  Future<CatalogResult> trending({Set<MusicSourceId>? only, int limit = 25}) =>
      _query(query: '', isTrending: true, only: only, limit: limit);

  /// Comprueba todas las fuentes en paralelo y devuelve sus estados.
  Future<Map<MusicSourceId, MusicSourceStatus>> checkAll() async {
    final List<MusicSourceStatus> checked = await Future.wait(
      _providers.map(
        (MusicSourceProvider provider) => provider.checkAvailability(),
      ),
    );
    return Map<MusicSourceId, MusicSourceStatus>.unmodifiable(
      <MusicSourceId, MusicSourceStatus>{
        for (int i = 0; i < _providers.length; i++)
          _providers[i].id: checked[i],
      },
    );
  }

  Future<CatalogResult> _query({
    required String query,
    required bool isTrending,
    required Set<MusicSourceId>? only,
    required int limit,
  }) async {
    final List<MusicSourceProvider> selected = _providers
        .where(
          (MusicSourceProvider provider) =>
              only == null || only.contains(provider.id),
        )
        .toList(growable: false);

    final List<SourceResult> results = await Future.wait(
      selected.map((MusicSourceProvider provider) async {
        try {
          return isTrending
              ? await provider.trending(limit: limit)
              : await provider.search(query, limit: limit);
        } catch (error) {
          return SourceResult(
            source: provider.id,
            status: provider.status.available
                ? provider.status.copyWith(
                    available: false,
                    issue: MusicSourceIssue.unavailable,
                    detail:
                        'Error inesperado al consultar ${provider.id.label}.',
                    checkedAt: DateTime.now(),
                  )
                : provider.status,
          );
        }
      }),
    );

    return CatalogResult(
      query: query,
      isTrending: isTrending,
      sources: results,
      loadedAt: DateTime.now(),
    );
  }
}
