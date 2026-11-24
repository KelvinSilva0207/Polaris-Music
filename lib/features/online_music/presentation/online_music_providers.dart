import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/debug/memory_probe.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/settings_service.dart';
import '../../library/data/library_repository.dart';
import '../data/dio_request_cancellation.dart';
import '../data/download_manager.dart';
import '../data/online_diagnostics.dart';
import '../data/online_music_service.dart';
import '../data/online_sync_repository.dart';
import '../domain/download_task.dart';
import '../domain/download_track_use_case.dart';
import '../domain/music_source.dart';
import '../domain/online_catalog_items.dart';
import '../domain/music_source_catalog.dart';
import '../domain/online_music_repository.dart';
import '../domain/online_source_settings.dart';
import '../domain/online_track.dart';
import '../domain/request_cancellation.dart';
import '../domain/search_online_tracks_use_case.dart';
import '../domain/stream_track_use_case.dart';

final Provider<OnlineMusicService> onlineMusicServiceProvider =
    Provider<OnlineMusicService>((Ref ref) => sl<OnlineMusicService>());

/// Repositorio unificado usado por streaming y descargas.
final Provider<OnlineMusicRepository> onlineCatalogRepositoryProvider =
    Provider<OnlineMusicRepository>((Ref ref) => sl<OnlineMusicRepository>());

final Provider<MusicSourceCatalog> musicSourceCatalogProvider =
    Provider<MusicSourceCatalog>((Ref ref) => sl<MusicSourceCatalog>());

final Provider<SearchOnlineTracksUseCase> searchOnlineTracksUseCaseProvider =
    Provider<SearchOnlineTracksUseCase>(
      (Ref ref) =>
          SearchOnlineTracksUseCase(ref.watch(onlineCatalogRepositoryProvider)),
    );

final Provider<StreamTrackUseCase> streamTrackUseCaseProvider =
    Provider<StreamTrackUseCase>(
      (Ref ref) =>
          StreamTrackUseCase(ref.watch(onlineCatalogRepositoryProvider)),
    );

final Provider<DownloadManager> downloadManagerProvider =
    Provider<DownloadManager>((Ref ref) => sl<DownloadManager>());

/// Repositorio de referencias offline-first. Se construye aquí para no tocar el
/// registro global de dependencias (pendiente en otra tarea).
final Provider<OnlineSyncRepository> onlineSyncRepositoryProvider =
    Provider<OnlineSyncRepository>(
      (Ref ref) => OnlineSyncRepository(sl<AppDatabase>()),
    );

final Provider<DownloadTrackUseCase> downloadTrackUseCaseProvider =
    Provider<DownloadTrackUseCase>(
      (Ref ref) => DownloadTrackUseCase(ref.watch(downloadManagerProvider)),
    );

/// Ids externos que ya viven en la biblioteca local.
final StreamProvider<Set<String>> downloadedIdsProvider =
    StreamProvider<Set<String>>(
      (Ref ref) => sl<LibraryRepository>().watchDownloadedExternalIds(),
    );

/// Estado de la cola de descargas.
final StreamProvider<List<DownloadTask>> downloadTasksProvider =
    StreamProvider<List<DownloadTask>>(
      (Ref ref) => ref.watch(downloadManagerProvider).changes,
    );

/// Estado de la búsqueda unificada.
@immutable
class OnlineSearchState {
  const OnlineSearchState({
    this.query = '',
    this.tracks = const <OnlineTrack>[],
    this.loading = false,
    this.isTrending = true,
    this.error,
    this.sourceFilter,
    this.results = const <SourceResult>[],
    this.sourceStatuses = const <MusicSourceId, MusicSourceStatus>{},
    this.resultType = OnlineSearchType.songs,
    this.collections = const <OnlineCollectionRef>[],
    this.openedCollection,
    this.collectionLoading = false,
    this.collectionError,
    this.collectionContinuation,
    this.collectionHasMore = false,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final String query;
  final List<OnlineTrack> tracks;
  final bool loading;
  final bool isTrending;
  final String? error;

  /// `null` muestra todas las fuentes; si no, solo los resultados de esa fuente.
  final MusicSourceId? sourceFilter;

  /// Resultado parcial de cada fuente consultada.
  final List<SourceResult> results;

  /// Último estado conocido de disponibilidad por fuente.
  final Map<MusicSourceId, MusicSourceStatus> sourceStatuses;

  /// Tipo de resultado visible en la pestaña activa.
  final OnlineSearchType resultType;

  /// Colecciones devueltas por la búsqueda tipada (o por la vista [all]).
  final List<OnlineCollectionRef> collections;

  /// Colección abierta actualmente; cuando no es `null`, [tracks] contiene sus
  /// pistas en lugar de los resultados de búsqueda.
  final OnlineCollectionRef? openedCollection;
  final bool collectionLoading;
  final String? collectionError;

  /// Token de la siguiente página y banderas de carga incremental.
  final String? collectionContinuation;
  final bool collectionHasMore;
  final bool loadingMore;
  final String? loadMoreError;

  /// Las vistas que muestran colecciones (incluida la agrupada [all]).
  bool get showCollections =>
      openedCollection == null &&
      resultType != OnlineSearchType.songs &&
      (isTrending == false || collections.isNotEmpty);

  bool get isEmpty =>
      !loading &&
      !collectionLoading &&
      !loadingMore &&
      (openedCollection == null
          ? (showCollections
                ? collections.isEmpty && tracks.isEmpty
                : tracks.isEmpty)
          : tracks.isEmpty);

  List<SourceResult> get issues => results
      .where((SourceResult result) => !result.ok)
      .toList(growable: false);

  /// Colecciones agrupadas por sección para la vista `all`.
  List<OnlineCollectionRef> collectionsOf(OnlineSearchType kind) => collections
      .where((OnlineCollectionRef item) => item.kind == kind)
      .toList(growable: false);

  SourceResult? resultFor(MusicSourceId source) {
    for (final SourceResult result in results) {
      if (result.source == source) return result;
    }
    return null;
  }

  OnlineSearchState copyWith({
    String? query,
    List<OnlineTrack>? tracks,
    bool? loading,
    bool? isTrending,
    String? error,
    bool clearError = false,
    MusicSourceId? sourceFilter,
    bool clearSourceFilter = false,
    List<SourceResult>? results,
    Map<MusicSourceId, MusicSourceStatus>? sourceStatuses,
    OnlineSearchType? resultType,
    List<OnlineCollectionRef>? collections,
    OnlineCollectionRef? openedCollection,
    bool clearOpenedCollection = false,
    bool? collectionLoading,
    String? collectionError,
    bool clearCollectionError = false,
    String? collectionContinuation,
    bool clearCollectionContinuation = false,
    bool? collectionHasMore,
    bool? loadingMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
  }) => OnlineSearchState(
    query: query ?? this.query,
    tracks: tracks ?? this.tracks,
    loading: loading ?? this.loading,
    isTrending: isTrending ?? this.isTrending,
    error: clearError ? null : (error ?? this.error),
    sourceFilter: clearSourceFilter
        ? null
        : (sourceFilter ?? this.sourceFilter),
    results: results ?? this.results,
    sourceStatuses: sourceStatuses ?? this.sourceStatuses,
    resultType: resultType ?? this.resultType,
    collections: collections ?? this.collections,
    openedCollection: clearOpenedCollection
        ? null
        : (openedCollection ?? this.openedCollection),
    collectionLoading: collectionLoading ?? this.collectionLoading,
    collectionError: clearCollectionError
        ? null
        : (collectionError ?? this.collectionError),
    collectionContinuation: clearCollectionContinuation
        ? null
        : (collectionContinuation ?? this.collectionContinuation),
    collectionHasMore: collectionHasMore ?? this.collectionHasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: clearLoadMoreError
        ? null
        : (loadMoreError ?? this.loadMoreError),
  );
}

/// Búsqueda con debounce, tendencias, cancelación real y paginación.
///
/// Los errores de una fuente no impiden mostrar el resto: se guardan en
/// [OnlineSearchState.results] y la interfaz decide cómo comunicarlos. La
/// cancelación intencional (el usuario escribe o cambia de filtro) no se
/// muestra como error de red: se descarta en cuanto llega.
class OnlineSearchController extends StateNotifier<OnlineSearchState> {
  OnlineSearchController(
    this._catalog,
    this._settings, {
    OnlineRequestCancellation? cancellation,
  }) : _cancellation = cancellation ?? const DioRequestCancellation(),
       super(
         OnlineSearchState(loading: true, sourceStatuses: _catalog.statuses),
       ) {
    unawaited(loadTrending());
  }

  final MusicSourceCatalog _catalog;
  final SettingsService _settings;
  final OnlineRequestCancellation _cancellation;

  Timer? _debounce;
  int _generation = 0;
  int _collectionGeneration = 0;
  OnlineRequestToken? _activeToken;
  OnlineRequestToken? _collectionToken;

  Future<void> loadTrending() => _load(isTrending: true);

  /// Cancela la consulta anterior en cuanto el usuario cambia de intención.
  void _cancelActive() {
    _activeToken?.cancel();
    _activeToken = null;
  }

  void _cancelCollection() {
    _collectionToken?.cancel();
    _collectionToken = null;
  }

  /// Cambia entre Todos / Canciones / Álbumes / Artistas / Playlists y recarga.
  Future<void> setResultType(OnlineSearchType type) async {
    if (type == state.resultType && state.openedCollection == null) return;
    _debounce?.cancel();
    _cancelActive();
    _cancelCollection();
    _generation++;
    state = state.copyWith(
      resultType: type,
      tracks: const <OnlineTrack>[],
      collections: const <OnlineCollectionRef>[],
      clearOpenedCollection: true,
      clearCollectionError: true,
      clearCollectionContinuation: true,
      loading: true,
    );
    await _load(isTrending: false, query: state.query);
  }

  /// Abre una colección pública y muestra su primera página de pistas.
  Future<void> openCollection(OnlineCollectionRef collection) async {
    _debounce?.cancel();
    _cancelActive();
    _cancelCollection();
    _generation++;
    final int generation = ++_collectionGeneration;
    final OnlineRequestToken token = _cancellation.issue();
    _collectionToken = token;
    state = state.copyWith(
      openedCollection: collection,
      collectionLoading: true,
      tracks: const <OnlineTrack>[],
      loading: false,
      clearCollectionError: true,
      clearCollectionContinuation: true,
      collectionHasMore: false,
      clearLoadMoreError: true,
    );
    try {
      final CollectionPage page = await _catalog.loadCollectionPage(
        collection,
        token: token,
      );
      if (!mounted || generation != _collectionGeneration) return;
      _collectionToken = null;
      state = state.copyWith(
        tracks: page.tracks,
        collectionLoading: false,
        loading: false,
        collectionContinuation: page.continuation,
        collectionHasMore: page.hasMore,
      );
    } on RequestCanceledException {
      // El usuario abrió otra colección o cambió de vista: no es un fallo.
      return;
    } on Object catch (error, stack) {
      OnlineDiagnostics.report(
        'OnlineSearch',
        'No se pudo abrir la colección ${collection.externalId}',
        error: error,
        stack: stack,
      );
      if (!mounted || generation != _collectionGeneration) return;
      _collectionToken = null;
      state = state.copyWith(
        collectionLoading: false,
        collectionError:
            'No se pudo abrir esta colección. '
            'Prueba de nuevo en unos segundos.',
      );
    }
  }

  /// Concatena la siguiente página sin perder la posición de reproducción.
  ///
  /// Las pistas nuevas se añaden al final y se descartan las que ya están por
  /// `externalId`, de modo que los índices de la cola siguen siendo válidos.
  Future<void> loadMoreCollection() async {
    final OnlineCollectionRef? collection = state.openedCollection;
    if (collection == null ||
        state.loadingMore ||
        !state.collectionHasMore ||
        _collectionToken != null) {
      return;
    }
    final int generation = _collectionGeneration;
    final OnlineRequestToken token = _cancellation.issue();
    _collectionToken = token;
    state = state.copyWith(loadingMore: true, clearLoadMoreError: true);
    try {
      final CollectionPage page = await _catalog.loadCollectionPage(
        collection,
        continuation: state.collectionContinuation,
        token: token,
      );
      if (!mounted || generation != _collectionGeneration) return;
      _collectionToken = null;
      final Set<String> seen = <String>{
        for (final OnlineTrack item in state.tracks) item.externalId,
      };
      final List<OnlineTrack> appended = <OnlineTrack>[];
      for (final OnlineTrack item in page.tracks) {
        if (seen.add(item.externalId)) appended.add(item);
      }
      state = state.copyWith(
        tracks: <OnlineTrack>[...state.tracks, ...appended],
        loadingMore: false,
        collectionContinuation: page.continuation,
        collectionHasMore: page.hasMore && page.tracks.isNotEmpty,
      );
    } on RequestCanceledException {
      return;
    } on Object catch (error, stack) {
      OnlineDiagnostics.report(
        'OnlineSearch',
        'No se pudo cargar más pistas de ${collection.externalId}',
        error: error,
        stack: stack,
      );
      if (!mounted || generation != _collectionGeneration) return;
      _collectionToken = null;
      state = state.copyWith(
        loadingMore: false,
        loadMoreError: 'No se pudieron cargar más pistas.',
      );
    }
  }

  Future<void> closeCollection() async {
    _cancelCollection();
    _collectionGeneration++;
    state = state.copyWith(
      clearOpenedCollection: true,
      clearCollectionError: true,
      clearCollectionContinuation: true,
      collectionHasMore: false,
      clearLoadMoreError: true,
    );
    await retryCurrent();
  }

  Future<void> _load({required bool isTrending, String? query}) async {
    _cancelActive();
    final int generation = ++_generation;
    final OnlineRequestToken token = _cancellation.issue();
    _activeToken = token;
    MemoryProbe.mark(isTrending ? 'online:trending' : 'online:search');
    final String term = (query ?? state.query).trim();
    state = state.copyWith(
      query: term,
      loading: true,
      isTrending: isTrending,
      clearError: true,
    );
    try {
      final OnlineSearchType type = state.resultType;
      final CatalogResult result = isTrending
          ? await _catalog.trending(only: _onlySelected, token: token)
          : type == OnlineSearchType.all
          ? await _catalog.searchAll(term, only: _onlySelected, token: token)
          : type == OnlineSearchType.songs
          ? await _catalog.search(term, only: _onlySelected, token: token)
          : await _catalog.searchType(
              term,
              type: type,
              only: _onlySelected,
              token: token,
            );
      if (!mounted || generation != _generation) return;
      _activeToken = null;
      for (final SourceResult source in result.sources) {
        if (source.ok || source.status.issue == MusicSourceIssue.canceled) {
          continue;
        }
        OnlineDiagnostics.report(
          'OnlineSearch',
          '${source.source.label}: ${source.status.detail}',
        );
      }
      state = state.copyWith(
        loading: false,
        tracks: result.tracks,
        collections: result.collections(type),
        results: result.sources,
        clearOpenedCollection: true,
        clearCollectionError: true,
        clearCollectionContinuation: true,
        collectionHasMore: false,
        clearLoadMoreError: true,
        sourceStatuses: <MusicSourceId, MusicSourceStatus>{
          ...state.sourceStatuses,
          for (final SourceResult source in result.sources)
            source.source: source.status,
        },
      );
    } on RequestCanceledException {
      // Cancelación intencional: se descarta sin tocar el estado visible.
      return;
    } on Object catch (error, stack) {
      OnlineDiagnostics.report(
        'OnlineSearch',
        'Fallo inesperado en la búsqueda online',
        error: error,
        stack: stack,
      );
      if (!mounted || generation != _generation) return;
      _activeToken = null;
      state = state.copyWith(
        loading: false,
        error: 'No se pudo completar la búsqueda. Inténtalo de nuevo.',
      );
    }
  }

  Set<MusicSourceId>? get _onlySelected =>
      state.sourceFilter == null ? null : <MusicSourceId>{state.sourceFilter!};

  void onQueryChanged(String raw) {
    _debounce?.cancel();
    _cancelActive();
    _cancelCollection();
    final String query = raw.trim();
    if (query.isEmpty) {
      // Al borrar la búsqueda se vuelve a la vista de tendencias de canciones;
      // si se mantuviera la pestaña de colecciones, no habría término que
      // buscar y la pantalla parecería vacía sin motivo.
      state = state.copyWith(
        query: '',
        resultType: OnlineSearchType.songs,
        collections: const <OnlineCollectionRef>[],
      );
      unawaited(loadTrending());
      return;
    }
    state = state.copyWith(
      query: raw,
      loading: true,
      isTrending: false,
      clearOpenedCollection: true,
      clearCollectionContinuation: true,
      collectionHasMore: false,
    );
    _debounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_load(isTrending: false, query: query));
    });
  }

  Future<void> setSourceFilter(MusicSourceId? source) async {
    if (source == state.sourceFilter) return;
    _debounce?.cancel();
    _cancelActive();
    _cancelCollection();
    state = source == null
        ? state.copyWith(clearSourceFilter: true, clearOpenedCollection: true)
        : state.copyWith(sourceFilter: source, clearOpenedCollection: true);
    if (state.isTrending) {
      await loadTrending();
    } else {
      await _load(isTrending: false);
    }
  }

  Future<void> retryCurrent() async {
    if (state.isTrending) {
      await loadTrending();
    } else {
      await _load(isTrending: false, query: state.query);
    }
  }

  /// Fuerza una comprobación de credenciales/disponibilidad de todas las
  /// fuentes sin lanzar errores a la interfaz.
  Future<void> checkSources() async {
    final Map<MusicSourceId, MusicSourceStatus> checked = await _catalog
        .checkAll();
    if (!mounted) return;
    state = state.copyWith(
      sourceStatuses: <MusicSourceId, MusicSourceStatus>{
        ...state.sourceStatuses,
        ...checked,
      },
    );
  }

  /// Guarda (o borra) el token de una fuente y recarga la vista actual.
  Future<void> configureSource(
    MusicSourceId source,
    String rawToken, {
    String? market,
  }) async {
    final String token = rawToken.trim();
    switch (source) {
      case MusicSourceId.audius:
        return;
      case MusicSourceId.soundcloud:
        await _writeToken(OnlineSourceSettings.soundCloudToken, token);
      case MusicSourceId.spotify:
        await _writeToken(OnlineSourceSettings.spotifyToken, token);
        if (market != null && market.trim().isNotEmpty) {
          await _settings.setString(
            OnlineSourceSettings.spotifyMarket,
            market.trim().toUpperCase(),
          );
        }
      case MusicSourceId.tidal:
        await _writeToken(OnlineSourceSettings.tidalToken, token);
      case MusicSourceId.youtube:
        return;
    }
    await checkSources();
    await retryCurrent();
  }

  Future<void> _writeToken(String key, String token) async {
    if (token.isEmpty) {
      await _settings.remove(key);
    } else {
      await _settings.setString(key, token);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancelActive();
    _cancelCollection();
    super.dispose();
  }
}

final StateNotifierProvider<OnlineSearchController, OnlineSearchState>
onlineSearchProvider =
    StateNotifierProvider<OnlineSearchController, OnlineSearchState>((Ref ref) {
      return OnlineSearchController(
        ref.watch(musicSourceCatalogProvider),
        ref.watch(settingsServiceProvider),
        cancellation: const DioRequestCancellation(),
      );
    });
