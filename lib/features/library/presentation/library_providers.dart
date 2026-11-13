import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/models/track.dart';
import '../data/library_repository.dart';
import '../data/library_scanner.dart';
import '../domain/library_folder.dart';
import '../domain/library_sort.dart';

final Provider<LibraryRepository> libraryRepositoryProvider =
    Provider<LibraryRepository>((Ref ref) => sl<LibraryRepository>());

final StateProvider<String> libraryQueryProvider = StateProvider<String>(
  (Ref ref) => '',
);

final StateProvider<LibrarySort> librarySortProvider =
    StateProvider<LibrarySort>((Ref ref) => LibrarySort.artist);

final StateProvider<bool> libraryAscendingProvider = StateProvider<bool>(
  (Ref ref) => true,
);

final StreamProvider<List<Track>> libraryTracksProvider =
    StreamProvider<List<Track>>((Ref ref) {
      final LibraryRepository repository = ref.watch(libraryRepositoryProvider);
      final String query = ref.watch(libraryQueryProvider);
      final LibrarySort sort = ref.watch(librarySortProvider);
      final bool ascending = ref.watch(libraryAscendingProvider);
      return repository.watch(query: query, sort: sort, ascending: ascending);
    });

final StreamProvider<List<Track>> favoriteTracksProvider =
    StreamProvider<List<Track>>((Ref ref) {
      final LibraryRepository repository = ref.watch(libraryRepositoryProvider);
      return repository.watchFavorites();
    });

final StreamProvider<List<LibraryFolder>> libraryFoldersProvider =
    StreamProvider<List<LibraryFolder>>((Ref ref) {
      return ref.watch(libraryRepositoryProvider).watchFolders();
    });

/// Estado del escaneo en curso.
class ScanUiState {
  const ScanUiState({
    this.running = false,
    this.progress,
    this.summary,
    this.error,
  });

  final bool running;
  final ScanProgress? progress;
  final ScanSummary? summary;
  final String? error;

  double get fraction => progress?.fraction ?? 0;

  ScanUiState copyWith({
    bool? running,
    ScanProgress? progress,
    ScanSummary? summary,
    String? error,
  }) => ScanUiState(
    running: running ?? this.running,
    progress: progress ?? this.progress,
    summary: summary ?? this.summary,
    error: error,
  );
}

/// Ejecuta el escaneo y expone progreso/resumen a la UI.
class ScanController extends StateNotifier<ScanUiState> {
  ScanController(this._repository) : super(const ScanUiState());

  final LibraryRepository _repository;
  StreamSubscription<ScanProgress>? _subscription;

  Future<void> scan() async {
    if (state.running) return;
    state = ScanUiState(running: true, summary: state.summary);
    _subscription = _repository.scanProgress.listen((ScanProgress progress) {
      if (mounted) {
        state = state.copyWith(progress: progress);
      }
    });

    try {
      final ScanSummary summary = await _repository.scan();
      state = ScanUiState(summary: summary);
    } catch (error) {
      state = ScanUiState(error: 'No se pudo escanear: $error');
    } finally {
      await _subscription?.cancel();
      _subscription = null;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<ScanController, ScanUiState>
scanControllerProvider = StateNotifierProvider<ScanController, ScanUiState>((
  Ref ref,
) {
  final ScanController controller = ScanController(
    ref.watch(libraryRepositoryProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

final AutoDisposeFutureProvider<List<DuplicateGroup>> duplicateGroupsProvider =
    FutureProvider.autoDispose<List<DuplicateGroup>>((Ref ref) {
      return ref.watch(libraryRepositoryProvider).duplicates();
    });
