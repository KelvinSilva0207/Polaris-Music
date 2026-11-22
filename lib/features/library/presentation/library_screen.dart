import 'dart:async';
import 'dart:io' show Directory, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/models/track.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/storage_paths_service.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/directional_transitions.dart';
import '../../../shared/widgets/motion_scope.dart';
import '../data/library_scanner.dart';
import '../domain/library_folder.dart';
import '../domain/library_sort.dart';
import '../domain/library_view.dart';
import 'library_providers.dart';
import 'library_views.dart';
import 'playlists_dialog.dart';

/// Biblioteca local: búsqueda, orden, escaneo y gestión de carpetas.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _searchDebounce;
  bool _hasQuery = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _hasQuery = value.trim().isNotEmpty);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      final String clean = value.trim();
      ref.read(libraryQueryProvider.notifier).state = clean;
      if (clean.isNotEmpty) {
        unawaited(ref.read(settingsServiceProvider).rememberSearch(clean));
      }
    });
  }

  void _applySearch(String value) {
    _searchDebounce?.cancel();
    _search.text = value;
    setState(() => _hasQuery = value.isNotEmpty);
    ref.read(libraryQueryProvider.notifier).state = value;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Track>> tracks = ref.watch(libraryTracksProvider);
    final ScanUiState scan = ref.watch(scanControllerProvider);
    final LibrarySort sort = ref.watch(librarySortProvider);
    final bool ascending = ref.watch(libraryAscendingProvider);
    final LibraryView view = ref.watch(libraryViewProvider);
    // Reconstruye la fila de búsquedas recientes cuando se guarda un término.
    ref.watch(settingsValuesProvider);
    final List<String> recent = ref
        .read(settingsServiceProvider)
        .recentSearches;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Buscar por título, artista o álbum…',
                        prefixIcon: Icon(Icons.search_rounded),
                        suffixIcon: _hasQuery
                            ? IconButton(
                                tooltip: 'Limpiar búsqueda',
                                icon: Icon(Icons.close_rounded),
                                onPressed: () => _applySearch(''),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: scan.running ? null : _scan,
                    icon: scan.running
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.radar_rounded),
                    label: Text(scan.running ? 'Escaneando' : 'Escanear'),
                  ),
                ],
              ),
              if (!_hasQuery && recent.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      'Recientes:',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.inkAlpha(0.5),
                      ),
                    ),
                    for (final String term in recent.take(5))
                      ActionChip(
                        label: Text(term),
                        onPressed: () => _applySearch(term),
                      ),
                    TextButton(
                      onPressed: () => unawaited(
                        ref.read(settingsServiceProvider).clearRecentSearches(),
                      ),
                      child: Text('Limpiar'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (final LibraryView item in LibraryView.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(item.fullLabel),
                          tooltip: item.description,
                          selected: item == view,
                          onSelected: (_) =>
                              ref.read(libraryViewProvider.notifier).state =
                                  item,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  if (Platform.isAndroid)
                    OutlinedButton.icon(
                      onPressed: scan.running ? null : _importMetrolist,
                      icon: Icon(Icons.download_for_offline_outlined, size: 18),
                      label: Text('Metrolist'),
                    ),
                  if (Platform.isAndroid) const SizedBox(width: 8),
                  Tooltip(
                    message: 'Añadir o quitar carpetas de escaneo',
                    child: OutlinedButton.icon(
                      onPressed: _manageFolders,
                      icon: Icon(Icons.folder_outlined, size: 18),
                      label: Text('Gestionar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _showDuplicates,
                    icon: Icon(Icons.copy_all_rounded, size: 18),
                    label: Text('Duplicados'),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'Listas y M3U',
                    icon: Icon(Icons.playlist_play_rounded, size: 22),
                    onSelected: _onPlaylistAction,
                    itemBuilder: (BuildContext context) =>
                        const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'manage',
                            child: Text('Gestionar listas'),
                          ),
                          PopupMenuItem<String>(
                            value: 'import',
                            child: Text('Importar M3U…'),
                          ),
                          PopupMenuItem<String>(
                            value: 'export',
                            child: Text('Exportar M3U…'),
                          ),
                        ],
                  ),
                  const Spacer(),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<LibrarySort>(
                      value: sort,
                      borderRadius: BorderRadius.circular(12),
                      items: LibrarySort.values
                          .map(
                            (LibrarySort value) =>
                                DropdownMenuItem<LibrarySort>(
                                  value: value,
                                  child: Text(value.label),
                                ),
                          )
                          .toList(growable: false),
                      onChanged: (LibrarySort? value) {
                        if (value == null) return;
                        ref.read(librarySortProvider.notifier).state = value;
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: ascending ? 'Ascendente' : 'Descendente',
                    onPressed: () =>
                        ref.read(libraryAscendingProvider.notifier).state =
                            !ascending,
                    icon: Icon(
                      ascending
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                    ),
                  ),
                ],
              ),
              if (scan.running) ...<Widget>[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: scan.progress == null ? null : scan.fraction,
                  minHeight: 3,
                ),
                const SizedBox(height: 4),
                Text(
                  scan.progress == null
                      ? 'Preparando escaneo…'
                      : '${scan.progress!.processed} de ${scan.progress!.total} archivos',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.inkAlpha(0.54)),
                ),
              ],
              if (scan.summary != null && !scan.running) ...<Widget>[
                const SizedBox(height: 10),
                _ScanSummaryBar(summary: scan.summary!),
              ],
              if (scan.error != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(scan.error!, style: TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
        Expanded(
          child: DirectionalContentSwitcher(
            direction: view.index,
            duration: context.motion.duration(
              const Duration(milliseconds: 260),
            ),
            distance: 0.06,
            child: KeyedSubtree(
              key: ValueKey<String>('library-view-${view.name}'),
              child: switch (view) {
                LibraryView.all => TrackResults(
                  tracks: tracks,
                  onManageFolders: _manageFolders,
                ),
                LibraryView.albums ||
                LibraryView.artists => LibraryGroupsView(view: view),
                LibraryView.folders => const FoldersView(),
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _scan() async {
    final PermissionServiceProxy proxy = PermissionServiceProxy(ref);
    await proxy.requestLibraryAccess();
    if (!mounted) return;
    await ref.read(scanControllerProvider.notifier).scan();
  }

  Future<void> _importMetrolist() async {
    final String? folder = await FilePicker.getDirectoryPath(
      dialogTitle: 'Carpeta de descargas de Metrolist (opcional)',
    );
    if (!mounted) return;
    await ref.read(scanControllerProvider.notifier).importMetrolist(folder);
  }

  Future<void> _manageFolders() async {
    final PermissionServiceProxy permissions = PermissionServiceProxy(ref);
    if (!await permissions.requestLibraryAccess()) {
      if (!mounted) return;
      _snack('Se necesita permiso para leer archivos de audio.');
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => const _FoldersDialog(),
    );
  }

  Future<void> _showDuplicates() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => const _DuplicatesDialog(),
    );
  }

  Future<void> _onPlaylistAction(String action) async {
    switch (action) {
      case 'manage':
        await showDialog<void>(
          context: context,
          builder: (BuildContext context) => const PlaylistsDialog(),
        );
      case 'import':
        await _importM3u();
      case 'export':
        await _exportM3u(
          ref.read(libraryTracksProvider).valueOrNull ?? const <Track>[],
        );
    }
  }

  Future<void> _importM3u() async {
    final List<PlatformFile> picked = await FilePicker.pickFiles(
      dialogTitle: 'Importar lista M3U',
      type: FileType.custom,
      allowedExtensions: const <String>['m3u', 'm3u8'],
    );
    final String? path = picked.isEmpty ? null : picked.first.path;
    if (path == null || !mounted) return;
    try {
      final int count = await ref.read(playlistServiceProvider).importM3u(path);
      if (!mounted) return;
      _snack(
        count == 0
            ? 'No se encontraron pistas indexadas en ese M3U'
            : 'Importadas $count pistas',
      );
    } catch (error) {
      if (mounted) _snack('No se pudo importar: $error');
    }
  }

  Future<void> _exportM3u(List<Track> tracks) async {
    if (tracks.isEmpty) {
      _snack('No hay pistas para exportar');
      return;
    }
    final Directory documents = await sl<StoragePathsService>().documents();
    final String? folder = await FilePicker.getDirectoryPath(
      dialogTitle: 'Carpeta donde guardar el M3U',
      initialDirectory: documents.path,
    );
    if (folder == null || !mounted) return;
    final String out =
        '$folder${Platform.pathSeparator}Polaris Biblioteca.m3u8';
    try {
      await ref.read(playlistServiceProvider).exportM3u(out, tracks);
      if (mounted) _snack('Biblioteca exportada a M3U');
    } catch (error) {
      if (mounted) _snack('No se pudo exportar: $error');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Pequeño adaptador para no repetir el manejo de permisos en la pantalla.
class PermissionServiceProxy {
  PermissionServiceProxy(this.ref);

  final WidgetRef ref;

  Future<bool> requestLibraryAccess() async {
    final result = await ref
        .read(permissionServiceProvider)
        .requestLibraryAccess();
    return result.granted;
  }
}

class _ScanSummaryBar extends StatelessWidget {
  const _ScanSummaryBar({required this.summary});

  final ScanSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: context.tokens.panelDecoration(radius: 12, elevated: false),
      child: Row(
        children: <Widget>[
          Icon(Icons.check_circle_outline_rounded, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${summary.filesFound} archivos · ${summary.inserted} nuevos · '
              '${summary.updated} actualizados · ${summary.removed} eliminados · '
              '${summary.failed} con error · ${summary.duration.inSeconds}s',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: context.inkAlpha(0.70)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoldersDialog extends ConsumerWidget {
  const _FoldersDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<LibraryFolder>> folders = ref.watch(
      libraryFoldersProvider,
    );

    return AlertDialog(
      title: Text('Carpetas de música'),
      content: SizedBox(
        width: 520,
        child: folders.when(
          loading: () => Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stack) =>
              Text('No se pudieron cargar las carpetas: $error'),
          data: (List<LibraryFolder> list) => Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (list.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'Todavía no hay carpetas. Añade una para empezar.',
                    style: TextStyle(color: context.inkAlpha(0.54)),
                  ),
                )
              else
                ...list.map(
                  (LibraryFolder folder) => ListTile(
                    leading: Icon(Icons.folder_rounded),
                    title: Text(folder.name),
                    subtitle: Text(
                      folder.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: 'Quitar carpeta',
                      icon: Icon(Icons.delete_outline_rounded),
                      onPressed: () => ref
                          .read(libraryRepositoryProvider)
                          .removeFolder(folder.id),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _addFolder(context, ref),
                icon: Icon(Icons.add_rounded),
                label: Text('Añadir carpeta'),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cerrar'),
        ),
      ],
    );
  }

  Future<void> _addFolder(BuildContext context, WidgetRef ref) async {
    String? path;
    try {
      path = await FilePicker.getDirectoryPath(
        dialogTitle: 'Selecciona una carpeta de música',
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el selector: $error')),
        );
      }
      return;
    }
    if (path == null) return;

    try {
      await ref.read(libraryRepositoryProvider).addFolderFromPicker(path);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Carpeta añadida')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo añadir la carpeta: $error')),
        );
      }
    }
  }
}

class _DuplicatesDialog extends ConsumerWidget {
  const _DuplicatesDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DuplicateGroup>> groups = ref.watch(
      duplicateGroupsProvider,
    );

    return AlertDialog(
      title: Text('Posibles duplicados'),
      content: SizedBox(
        width: 560,
        height: 420,
        child: groups.when(
          loading: () => Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stack) =>
              Text('No se pudo buscar duplicados: $error'),
          data: (List<DuplicateGroup> list) {
            if (list.isEmpty) {
              return Center(
                child: Text(
                  'No se encontraron duplicados por título, artista y duración.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.inkAlpha(0.54)),
                ),
              );
            }
            return ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (BuildContext context, int index) {
                final DuplicateGroup group = list[index];
                return ListTile(
                  title: Text('${group.artist} · ${group.title}'),
                  subtitle: Text(
                    '${group.count} copias · '
                    '${Formatters.duration(Duration(milliseconds: group.durationMs))}',
                  ),
                  trailing: TextButton(
                    onPressed: () => _keepFirst(context, ref, group),
                    child: Text('Conservar 1'),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cerrar'),
        ),
      ],
    );
  }

  Future<void> _keepFirst(
    BuildContext context,
    WidgetRef ref,
    DuplicateGroup group,
  ) async {
    if (group.ids.length <= 1) return;
    final List<int> toDelete = group.ids.sublist(1);
    await ref.read(libraryRepositoryProvider).deleteTracks(toDelete);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${toDelete.length} copias eliminadas')),
      );
    }
  }
}
