import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug/memory_probe.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/settings_service.dart';
import '../../library/data/library_repository.dart';
import '../data/download_manager.dart';
import '../data/online_music_service.dart';
import '../domain/download_task.dart';
import '../domain/download_track_use_case.dart';
import '../domain/music_source.dart';
import '../domain/online_catalog_items.dart';
import '../domain/music_source_catalog.dart';
import '../domain/online_music_repository.dart';
import '../domain/online_source_settings.dart';
import '../domain/online_track.dart';
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

  /// Colecciones devueltas por la búsqueda tipada.
  final List<OnlineCollectionRef> collections;

  /// Colección abierta actualmente; cuando no es `null`, [tracks] contiene sus
  /// pistas en lugar de los resultados de búsqueda.
  final OnlineCollectionRef? openedCollection;
  final bool collectionLoading;
  final String? collectionError;

  bool get isEmpty =>
      !loading &&
      !collectionLoading &&
      (openedCollection == null
          ? (resultType == OnlineSearchType.songs
              ? tracks.isEmpty
              : collections.isEmpty)
          : tracks.isEmpty);

  List<SourceResult> get issues => results
      .where((SourceResult result) => !result.ok)
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
  );
}

/// Búsqueda con debounce, tendencias y agregación de fuentes.
///
/// Los errores de una fuente no impiden mostrar el resto: se guardan en
/// [OnlineSearchState.results] y la interfaz decide cómo comunicarlos.
class OnlineSearchController extends StateNotifier<OnlineSearchState> {
  OnlineSearchController(this._catalog, this._settings)
    : super(
        OnlineSearchState(loading: true, sourceStatuses: _catalog.statuses),
      ) {
    unawaited(loadTrending());
  }

  final MusicSourceCatalog _catalog;
  final SettingsService _settings;

  Timer? _debounce;
  int _generation = 0;
  int _collectionGeneration = 0;

  Future<void> loadTrending() => _load(isTrending: true);

  /// Cambia entre Canciones / Álbumes / Artistas / Playlists y recarga.
  Future<void> setResultType(OnlineSearchType type) async {
    if (type == state.resultType && state.openedCollection == null) return;
    _debounce?.cancel();
    _generation++;
    state = state.copyWith(
      resultType: type,
      tracks: const <OnlineTrack>[],
      collections: const <OnlineCollectionRef>[],
      clearOpenedCollection: true,
      clearCollectionError: true,
      loading: true,
    );
    await _load(isTrending: false, query: state.query);
  }

  /// Abre una colección pública y muestra sus pistas reproducibles.
  Future<void> openCollection(OnlineCollectionRef collection) async {
    _debounce?.cancel();
    _generation++;
    final int generation = ++_collectionGeneration;
    state = state.copyWith(
      openedCollection: collection,
      collectionLoading: true,
      tracks: const <OnlineTrack>[],
      loading: false,
      clearCollectionError: true,
    );
    try {
      final List<OnlineTrack> tracks = await _catalog.collectionTracks(
        collection,
      );
      if (!mounted || generation != _collectionGeneration) return;
      state = state.copyWith(
        tracks: tracks,
        collectionLoading: false,
        loading: false,
      );
    } catch (error) {
      if (!mounted || generation != _collectionGeneration) return;
      state = state.copyWith(
        collectionLoading: false,
        collectionError: 'No se pudo abrir esta colección: $error',
      );
    }
  }

  Future<void> closeCollection() async {
    _collectionGeneration++;
    state = state.copyWith(
      clearOpenedCollection: true,
      clearCollectionError: true,
    );
    await retryCurrent();
  }

  Future<void> _load({required bool isTrending, String? query}) async {
    final int generation = ++_generation;
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
          ? await _catalog.trending(only: _onlySelected)
          : type == OnlineSearchType.songs
          ? await _catalog.search(term, only: _onlySelected)
          : await _catalog.searchType(
            term,
            type: type,
            only: _onlySelected,
          );
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        loading: false,
        tracks: result.tracks,
        collections: result.collections(type),
        results: result.sources,
        clearOpenedCollection: true,
        clearCollectionError: true,
        sourceStatuses: <MusicSourceId, MusicSourceStatus>{
          ...state.sourceStatuses,
          for (final SourceResult source in result.sources)
            source.source: source.status,
        },
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  Set<MusicSourceId>? get _onlySelected =>
      state.sourceFilter == null ? null : <MusicSourceId>{state.sourceFilter!};

  void onQueryChanged(String raw) {
    _debounce?.cancel();
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
    );
    _debounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_load(isTrending: false, query: query));
    });
  }

  Future<void> setSourceFilter(MusicSourceId? source) async {
    if (source == state.sourceFilter) return;
    _debounce?.cancel();
    state = source == null
        ? state.copyWith(
          clearSourceFilter: true,
          clearOpenedCollection: true,
        )
        : state.copyWith(
          sourceFilter: source,
          clearOpenedCollection: true,
        );
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
    super.dispose();
  }
}

final StateNotifierProvider<OnlineSearchController, OnlineSearchState>
onlineSearchProvider =
    StateNotifierProvider<OnlineSearchController, OnlineSearchState>((Ref ref) {
      return OnlineSearchController(
        ref.watch(musicSourceCatalogProvider),
        ref.watch(settingsServiceProvider),
      );
    });
