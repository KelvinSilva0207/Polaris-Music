import 'package:flutter/foundation.dart';

import 'music_source.dart';
import 'online_catalog_items.dart';
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

  /// Unión deduplicada de colecciones del tipo solicitado.
  List<OnlineCollectionRef> collections(OnlineSearchType type) {
    final List<OnlineCollectionRef> merged = <OnlineCollectionRef>[];
    final Set<String> seen = <String>{};
    for (final SourceResult result in sources) {
      for (final OnlineCollectionRef item in result.collections(type)) {
        if (seen.add(item.externalId)) merged.add(item);
      }
    }
    return List<OnlineCollectionRef>.unmodifiable(merged);
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

  /// Búsqueda tipada (canciones / álbumes / artistas / playlists).
  ///
  /// Reutiliza [_query] con una consulta distinta para que el manejo de
  /// errores por fuente sea idéntico al de la búsqueda de canciones.
  Future<CatalogResult> searchType(
    String query, {
    required OnlineSearchType type,
    Set<MusicSourceId>? only,
    int limit = 25,
  }) => _query(
    query: query.trim(),
    isTrending: false,
    only: only,
    limit: limit,
    type: type,
  );

  /// Carga las pistas de una colección pública usando su proveedor de origen.
  Future<List<OnlineTrack>> collectionTracks(
    OnlineCollectionRef collection, {
    int limit = 50,
  }) async {
    final MusicSourceProvider? provider = providerFor(collection.source);
    if (provider == null) return const <OnlineTrack>[];
    try {
      return await provider.collectionTracks(collection, limit: limit);
    } on Object {
      return const <OnlineTrack>[];
    }
  }

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
    OnlineSearchType type = OnlineSearchType.songs,
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
          if (isTrending) return await provider.trending(limit: limit);
          if (type == OnlineSearchType.songs) {
            return await provider.search(query, limit: limit);
          }
          final List<OnlineCollectionRef> collections = await provider
              .searchCollections(query, type: type, limit: limit);
          return SourceResult(
            source: provider.id,
            status: provider.status,
            albums: type == OnlineSearchType.albums
                ? collections
                : const <OnlineCollectionRef>[],
            artists: type == OnlineSearchType.artists
                ? collections
                : const <OnlineCollectionRef>[],
            playlists: type == OnlineSearchType.playlists
                ? collections
                : const <OnlineCollectionRef>[],
          );
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
