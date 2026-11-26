import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/models/track.dart';
import '../../../core/services/settings_service.dart';
import '../data/library_repository.dart';
import '../data/library_scanner.dart';
import '../data/metadata_editor_service.dart';
import '../data/playlist_service.dart';
import '../domain/folder_tree.dart';
import '../domain/library_folder.dart';
import '../domain/library_sort.dart';
import '../domain/library_view.dart';

final Provider<LibraryRepository> libraryRepositoryProvider =
    Provider<LibraryRepository>((Ref ref) => sl<LibraryRepository>());

final Provider<MetadataEditorService> metadataEditorServiceProvider =
    Provider<MetadataEditorService>((Ref ref) => sl<MetadataEditorService>());

final Provider<PlaylistService> playlistServiceProvider =
    Provider<PlaylistService>((Ref ref) => sl<PlaylistService>());

final StreamProvider<List<PlaylistRow>> playlistsProvider =
    StreamProvider<List<PlaylistRow>>((Ref ref) {
      return ref.watch(playlistServiceProvider).watchAll();
    });

final StateProvider<String> libraryQueryProvider = StateProvider<String>(
  (Ref ref) => '',
);

final StateProvider<LibrarySort> librarySortProvider =
    StateProvider<LibrarySort>((Ref ref) => LibrarySort.artist);

final StateProvider<bool> libraryAscendingProvider = StateProvider<bool>(
  (Ref ref) => true,
);

/// Selector principal de la Biblioteca: Todas / Álbumes / Artistas / Carpetas.
final StateProvider<LibraryView> libraryViewProvider =
    StateProvider<LibraryView>((Ref ref) => LibraryView.all);

/// Escala de carátulas y densidad de rejilla. Se persiste en preferencias, pero
/// el proveedor responde al instante para que el pellizco no tenga latencia.
final StateProvider<double> libraryArtworkScaleProvider = StateProvider<double>(
  (Ref ref) => sl<SettingsService>().libraryArtworkScale,
);

/// Todas las pistas indexadas, sin filtrar por búsqueda. Alimenta las vistas
/// agrupadas y el árbol de carpetas; `libraryTracksProvider` se conserva intacto
/// para la búsqueda global y las pantallas que lo reutilizan.
final StreamProvider<List<Track>> libraryAllTracksProvider =
    StreamProvider<List<Track>>((Ref ref) {
      final LibraryRepository repository = ref.watch(libraryRepositoryProvider);
      final LibrarySort sort = ref.watch(librarySortProvider);
      final bool ascending = ref.watch(libraryAscendingProvider);
      return repository.watch(sort: sort, ascending: ascending);
    });

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

/// Jerarquía real derivada de las rutas indexadas. No hace E/S, así que sigue
/// funcionando con una SD desmontada.
final Provider<FolderLibrary> folderLibraryProvider = Provider<FolderLibrary>((
  Ref ref,
) {
  final List<Track> tracks =
      ref.watch(libraryAllTracksProvider).valueOrNull ?? const <Track>[];
  final List<LibraryFolder> folders =
      ref.watch(libraryFoldersProvider).valueOrNull ?? const <LibraryFolder>[];
  return buildFolderTree(tracks, folders);
});

/// Agrupación reutilizable para Álbumes y Artistas.
@immutable
class LibraryGroup {
  const LibraryGroup({
    required this.key,
    required this.tracks,
    required this.icon,
  });

  final String key;
  final List<Track> tracks;
  final IconData icon;

  String? get artworkPath {
    for (final Track track in tracks) {
      if (track.artworkPath != null && track.artworkPath!.isNotEmpty) {
        return track.artworkPath;
      }
    }
    return null;
  }
}

List<LibraryGroup> _groupTracks(
  Iterable<Track> tracks,
  String Function(Track track) keyOf,
  IconData icon,
) {
  final Map<String, List<Track>> groups = <String, List<Track>>{};
  for (final Track track in tracks) {
    final String key = keyOf(track).trim();
    if (key.isEmpty) continue;
    groups.putIfAbsent(key, () => <Track>[]).add(track);
  }
  final List<LibraryGroup> result = <LibraryGroup>[
    for (final MapEntry<String, List<Track>> entry in groups.entries)
      LibraryGroup(
        key: entry.key,
        tracks: List<Track>.unmodifiable(entry.value),
        icon: icon,
      ),
  ];
  result.sort(
    (LibraryGroup a, LibraryGroup b) =>
        a.key.toLowerCase().compareTo(b.key.toLowerCase()),
  );
  return List<LibraryGroup>.unmodifiable(result);
}

final Provider<List<LibraryGroup>> albumGroupsProvider =
    Provider<List<LibraryGroup>>((Ref ref) {
      final List<Track> tracks =
          ref.watch(libraryAllTracksProvider).valueOrNull ?? const <Track>[];
      final String query = ref.watch(libraryQueryProvider).trim().toLowerCase();
      return _groupTracks(
        tracks.where(
          (Track track) =>
              query.isEmpty ||
              track.album.toLowerCase().contains(query) ||
              track.title.toLowerCase().contains(query) ||
              track.artist.toLowerCase().contains(query),
        ),
        (Track track) => track.album.toLowerCase() == 'desconocido'
            ? track.albumArtist
            : track.album,
        Icons.album_rounded,
      );
    });

final Provider<List<LibraryGroup>> artistGroupsProvider =
    Provider<List<LibraryGroup>>((Ref ref) {
      final List<Track> tracks =
          ref.watch(libraryAllTracksProvider).valueOrNull ?? const <Track>[];
      final String query = ref.watch(libraryQueryProvider).trim().toLowerCase();
      return _groupTracks(
        tracks.where(
          (Track track) =>
              query.isEmpty ||
              track.artist.toLowerCase().contains(query) ||
              track.title.toLowerCase().contains(query) ||
              track.album.toLowerCase().contains(query),
        ),
        (Track track) => track.artist,
        Icons.person_rounded,
      );
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

  Future<void> scan() => _run(_repository.scan);

  Future<void> importMetrolist(String? folder) =>
      _run(() => _repository.importMetrolist(folder));

  Future<void> _run(Future<ScanSummary> Function() action) async {
    if (state.running) return;
    state = ScanUiState(running: true, summary: state.summary);
    _subscription = _repository.scanProgress.listen((ScanProgress progress) {
      if (mounted) {
        state = state.copyWith(progress: progress);
      }
    });

    try {
      final ScanSummary summary = await action();
      state = ScanUiState(summary: summary);
    } catch (error) {
      state = ScanUiState(error: 'No se pudo completar la operación: $error');
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
