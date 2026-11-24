import 'dart:async';

import 'package:flutter/foundation.dart';

import 'music_source.dart';
import 'online_catalog_items.dart';
import 'online_track.dart';
import 'request_cancellation.dart';

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

  /// Tiempo máximo de una consulta por fuente: la interfaz puede seguir
  /// respondiendo (y cancelando) aunque una API no devuelva nada.
  static const Duration requestTimeout = Duration(seconds: 25);

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
    OnlineRequestToken? token,
  }) => _query(
    query: query.trim(),
    isTrending: false,
    only: only,
    limit: limit,
    token: token,
  );

  Future<CatalogResult> trending({
    Set<MusicSourceId>? only,
    int limit = 25,
    OnlineRequestToken? token,
  }) => _query(
    query: '',
    isTrending: true,
    only: only,
    limit: limit,
    token: token,
  );

  /// Búsqueda tipada (canciones / álbumes / artistas / playlists).
  ///
  /// Reutiliza [_query] con una consulta distinta para que el manejo de
  /// errores por fuente sea idéntico al de la búsqueda de canciones.
  Future<CatalogResult> searchType(
    String query, {
    required OnlineSearchType type,
    Set<MusicSourceId>? only,
    int limit = 25,
    OnlineRequestToken? token,
  }) => _query(
    query: query.trim(),
    isTrending: false,
    only: only,
    limit: limit,
    type: type,
    token: token,
  );

  /// Búsqueda agrupada: pistas y los tres tipos de colecciones a la vez.
  Future<CatalogResult> searchAll(
    String query, {
    Set<MusicSourceId>? only,
    int limit = 25,
    OnlineRequestToken? token,
  }) => _query(
    query: query.trim(),
    isTrending: false,
    only: only,
    limit: limit,
    type: OnlineSearchType.all,
    token: token,
  );

  /// Carga las pistas de una colección pública usando su proveedor de origen.
  Future<List<OnlineTrack>> collectionTracks(
    OnlineCollectionRef collection, {
    int limit = 50,
    OnlineRequestToken? token,
  }) async {
    final CollectionPage page = await loadCollectionPage(
      collection,
      limit: limit,
      token: token,
    );
    return page.tracks;
  }

  /// Página de una colección con su token de continuación.
  Future<CollectionPage> loadCollectionPage(
    OnlineCollectionRef collection, {
    String? continuation,
    int limit = 50,
    OnlineRequestToken? token,
  }) async {
    final MusicSourceProvider? provider = providerFor(collection.source);
    if (provider == null) return CollectionPage.empty;
    try {
      token?.throwIfCancelled();
      final CollectionPage page = provider is CancellableMusicSourceProvider
          ? await _withTimeout(
              (provider as CancellableMusicSourceProvider).collectionPage(
                collection,
                continuation: continuation ?? collection.continuation,
                limit: limit,
                token: token ?? const NoOpOnlineRequestToken(),
              ),
            )
          : CollectionPage.only(
              await _withTimeout(
                provider.collectionTracks(collection, limit: limit),
              ),
            );
      token?.throwIfCancelled();
      return page;
    } on RequestCanceledException {
      rethrow;
    } on Object {
      // Un fallo de paginación nunca borra las pistas ya visibles.
      // El controlador informa por OnlineDiagnostics y conserva la página previa.
      return CollectionPage.empty;
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

  Future<T> _withTimeout<T>(Future<T> future) => future.timeout(
    requestTimeout,
    onTimeout: () => throw TimeoutException('Tiempo de espera agotado'),
  );

  Future<CatalogResult> _query({
    required String query,
    required bool isTrending,
    required Set<MusicSourceId>? only,
    required int limit,
    OnlineSearchType type = OnlineSearchType.songs,
    OnlineRequestToken? token,
  }) async {
    final List<MusicSourceProvider> selected = _providers
        .where(
          (MusicSourceProvider provider) =>
              only == null || only.contains(provider.id),
        )
        .toList(growable: false);

    final List<SourceResult> results = await Future.wait(
      selected.map(
        (MusicSourceProvider provider) => _queryProvider(
          provider: provider,
          query: query,
          isTrending: isTrending,
          type: type,
          limit: limit,
          token: token,
        ),
      ),
    );

    return CatalogResult(
      query: query,
      isTrending: isTrending,
      sources: results,
      loadedAt: DateTime.now(),
    );
  }

  Future<SourceResult> _queryProvider({
    required MusicSourceProvider provider,
    required String query,
    required bool isTrending,
    required OnlineSearchType type,
    required int limit,
    OnlineRequestToken? token,
  }) async {
    try {
      token?.throwIfCancelled();
      final SourceResult result = type == OnlineSearchType.all
          ? await _queryAllTypes(
              provider: provider,
              query: query,
              limit: limit,
              token: token,
            )
          : isTrending
          ? await _withTimeout(
              provider is CancellableMusicSourceProvider
                  ? (provider as CancellableMusicSourceProvider)
                        .trendingCancellable(
                          limit: limit,
                          token: token ?? const NoOpOnlineRequestToken(),
                        )
                  : provider.trending(limit: limit),
            )
          : type == OnlineSearchType.songs
          ? await _withTimeout(
              provider is CancellableMusicSourceProvider
                  ? (provider as CancellableMusicSourceProvider)
                        .searchCancellable(
                          query,
                          limit: limit,
                          token: token ?? const NoOpOnlineRequestToken(),
                        )
                  : provider.search(query, limit: limit),
            )
          : await _searchCollections(
              provider: provider,
              query: query,
              type: type,
              limit: limit,
              token: token,
            );
      token?.throwIfCancelled();
      return result;
    } on RequestCanceledException {
      rethrow;
    } on Object {
      // Los errores por fuente son estado, no excepciones: la interfaz decide
      // si muestra un banner y el controlador los reporta una sola vez.
      return SourceResult(
        source: provider.id,
        status: provider.status.available
            ? provider.status.copyWith(
                available: false,
                issue: MusicSourceIssue.unavailable,
                detail: 'Error inesperado al consultar ${provider.id.label}.',
                checkedAt: DateTime.now(),
              )
            : provider.status,
      );
    }
  }

  Future<SourceResult> _searchCollections({
    required MusicSourceProvider provider,
    required String query,
    required OnlineSearchType type,
    required int limit,
    OnlineRequestToken? token,
  }) async {
    final List<OnlineCollectionRef> collections = await _withTimeout(
      provider is CancellableMusicSourceProvider
          ? (provider as CancellableMusicSourceProvider)
                .searchCollectionsCancellable(
                  query,
                  type: type,
                  limit: limit,
                  token: token ?? const NoOpOnlineRequestToken(),
                )
          : provider.searchCollections(query, type: type, limit: limit),
    );
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
  }

  Future<SourceResult> _queryAllTypes({
    required MusicSourceProvider provider,
    required String query,
    required int limit,
    OnlineRequestToken? token,
  }) async {
    final SourceResult songs = await _withTimeout(
      provider is CancellableMusicSourceProvider
          ? (provider as CancellableMusicSourceProvider).searchCancellable(
              query,
              limit: limit,
              token: token ?? const NoOpOnlineRequestToken(),
            )
          : provider.search(query, limit: limit),
    );
    final List<SourceResult> parts = await Future.wait(
      OnlineSearchType.collectionTypes.map(
        (OnlineSearchType type) => _searchCollections(
          provider: provider,
          query: query,
          type: type,
          limit: limit,
          token: token,
        ),
      ),
    );
    return SourceResult(
      source: provider.id,
      items: songs.items,
      status: songs.status,
      albums: parts.fold<List<OnlineCollectionRef>>(
        <OnlineCollectionRef>[],
        (List<OnlineCollectionRef> all, SourceResult part) =>
            <OnlineCollectionRef>[...all, ...part.albums],
      ),
      artists: parts.fold<List<OnlineCollectionRef>>(
        <OnlineCollectionRef>[],
        (List<OnlineCollectionRef> all, SourceResult part) =>
            <OnlineCollectionRef>[...all, ...part.artists],
      ),
      playlists: parts.fold<List<OnlineCollectionRef>>(
        <OnlineCollectionRef>[],
        (List<OnlineCollectionRef> all, SourceResult part) =>
            <OnlineCollectionRef>[...all, ...part.playlists],
      ),
    );
  }
}
