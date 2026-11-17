import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../library/data/library_repository.dart';
import '../data/download_manager.dart';
import '../data/online_music_service.dart';
import '../domain/download_task.dart';
import '../domain/download_track_use_case.dart';
import '../domain/online_track.dart';
import '../domain/search_online_tracks_use_case.dart';
import '../domain/stream_track_use_case.dart';

final Provider<OnlineMusicService> onlineMusicServiceProvider =
    Provider<OnlineMusicService>((Ref ref) => sl<OnlineMusicService>());

final Provider<SearchOnlineTracksUseCase> searchOnlineTracksUseCaseProvider =
    Provider<SearchOnlineTracksUseCase>(
      (Ref ref) =>
          SearchOnlineTracksUseCase(ref.watch(onlineMusicServiceProvider)),
    );

final Provider<StreamTrackUseCase> streamTrackUseCaseProvider =
    Provider<StreamTrackUseCase>(
      (Ref ref) => StreamTrackUseCase(ref.watch(onlineMusicServiceProvider)),
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

@immutable
class OnlineSearchState {
  const OnlineSearchState({
    this.query = '',
    this.tracks = const <OnlineTrack>[],
    this.loading = false,
    this.isTrending = true,
    this.error,
  });

  final String query;
  final List<OnlineTrack> tracks;
  final bool loading;

  /// `true` cuando la lista visible son tendencias y no una búsqueda.
  final bool isTrending;
  final String? error;

  bool get isEmpty => !loading && tracks.isEmpty;
}

/// Búsqueda con debounce y tendencias iniciales.
class OnlineSearchController extends StateNotifier<OnlineSearchState> {
  OnlineSearchController(this._search)
    : super(const OnlineSearchState(loading: true)) {
    unawaited(loadTrending());
  }

  final SearchOnlineTracksUseCase _search;

  Timer? _debounce;
  int _generation = 0;

  Future<void> loadTrending() async {
    final int generation = ++_generation;
    state = OnlineSearchState(
      tracks: state.tracks,
      loading: true,
      isTrending: true,
    );
    try {
      final List<OnlineTrack> tracks = await _search.trending();
      if (!mounted || generation != _generation) return;
      state = OnlineSearchState(tracks: tracks, isTrending: true);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = OnlineSearchState(
        loading: false,
        isTrending: true,
        error: '$error',
      );
    }
  }

  void onQueryChanged(String raw) {
    _debounce?.cancel();
    final String query = raw.trim();
    if (query.isEmpty) {
      unawaited(loadTrending());
      return;
    }
    state = OnlineSearchState(
      query: raw,
      tracks: state.tracks,
      loading: true,
      isTrending: false,
    );
    _debounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_run(query));
    });
  }

  Future<void> _run(String query) async {
    final int generation = ++_generation;
    state = OnlineSearchState(
      query: query,
      tracks: state.tracks,
      loading: true,
      isTrending: false,
    );
    try {
      final List<OnlineTrack> tracks = await _search.search(query);
      if (!mounted || generation != _generation) return;
      state = OnlineSearchState(
        query: query,
        tracks: tracks,
        isTrending: false,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = OnlineSearchState(
        query: query,
        loading: false,
        isTrending: false,
        error: '$error',
      );
    }
  }

  Future<void> retryCurrent() async {
    if (state.isTrending) return loadTrending();
    return _run(state.query.trim());
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
        ref.watch(searchOnlineTracksUseCaseProvider),
      );
    });
