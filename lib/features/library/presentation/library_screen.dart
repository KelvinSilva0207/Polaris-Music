import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/track.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/track_tile.dart';
import '../data/library_scanner.dart';
import '../domain/library_folder.dart';
import '../domain/library_sort.dart';
import 'library_providers.dart';

/// Biblioteca local: búsqueda, orden, escaneo y gestión de carpetas.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Track>> tracks = ref.watch(libraryTracksProvider);
    final ScanUiState scan = ref.watch(scanControllerProvider);
    final LibrarySort sort = ref.watch(librarySortProvider);
    final bool ascending = ref.watch(libraryAscendingProvider);

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
                      onChanged: (String value) =>
                          ref.read(libraryQueryProvider.notifier).state = value,
                      decoration: InputDecoration(
                        hintText: 'Buscar por título, artista o álbum…',
                        prefixIcon: Icon(Icons.search_rounded),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpiar',
                                icon: Icon(Icons.close_rounded),
                                onPressed: () {
                                  _search.clear();
                                  ref
                                          .read(libraryQueryProvider.notifier)
                                          .state =
                                      '';
                                  setState(() {});
                                },
                              ),
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
                  OutlinedButton.icon(
                    onPressed: _manageFolders,
                    icon: Icon(Icons.folder_outlined, size: 18),
                    label: Text('Carpetas'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _showDuplicates,
                    icon: Icon(Icons.copy_all_rounded, size: 18),
                    label: Text('Duplicados'),
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
          child: tracks.when(
            loading: () => Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stack) => Center(
              child: Text(
                'No se pudo cargar la biblioteca: $error',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            data: (List<Track> list) {
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.queue_music_rounded,
                  title: 'No hay pistas que mostrar',
                  message:
                      'Añade una carpeta con música y pulsa “Escanear” para '
                      'indexar tus archivos.',
                  action: FilledButton.icon(
                    onPressed: _manageFolders,
                    icon: Icon(Icons.create_new_folder_outlined),
                    label: Text('Añadir carpeta'),
                  ),
                );
              }
              return Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: <Widget>[
                        Text(
                          '${Formatters.count(list.length)} pistas',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.inkAlpha(0.54)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      itemCount: list.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Track track = list[index];
                        return TrackTile(
                          track: track,
                          queue: list,
                          index: index,
                          showIndex: true,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
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
