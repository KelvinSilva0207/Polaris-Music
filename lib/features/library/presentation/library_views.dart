import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/track_artwork.dart';
import '../../../shared/widgets/track_tile.dart';
import '../../player/presentation/player_providers.dart';
import '../domain/folder_tree.dart';
import '../domain/library_folder.dart';
import '../domain/library_sort.dart';
import '../domain/library_view.dart';
import 'library_providers.dart';

/// Lista de pistas compartida por Todas, álbumes, artistas y carpetas.
class TrackResults extends StatelessWidget {
  const TrackResults({
    super.key,
    required this.tracks,
    this.onManageFolders,
    this.artworkScale = 1,
    this.emptyTitle = 'No hay pistas que mostrar',
    this.emptyMessage = 'Añade una carpeta con música y pulsa “Escanear” para indexar tus archivos.',
  });

  final AsyncValue<List<Track>> tracks;
  final VoidCallback? onManageFolders;
  final double artworkScale;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return tracks.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stack) => Center(
        child: Text(
          'No se pudo cargar la biblioteca: $error',
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
      data: (List<Track> list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.queue_music_rounded,
            title: emptyTitle,
            message: emptyMessage,
            action: onManageFolders == null
                ? null
                : FilledButton.icon(
                    onPressed: onManageFolders,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('Añadir carpeta'),
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
                key: const PageStorageKey<String>('library-track-results'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                itemCount: list.length,
                itemBuilder: (BuildContext context, int index) {
                  final Track track = list[index];
                  return TrackTile(
                    track: track,
                    queue: list,
                    index: index,
                    showIndex: true,
                    artworkSize: 46 * artworkScale,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Rejilla de álbumes o artistas con búsqueda instantánea (provider filtrado).
class LibraryGroupsView extends ConsumerWidget {
  const LibraryGroupsView({super.key, required this.view, this.scale = 1});

  final LibraryView view;
  final double scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<LibraryGroup> groups = ref.watch(
      view == LibraryView.albums ? albumGroupsProvider : artistGroupsProvider,
    );
    if (groups.isEmpty) {
      return const EmptyState(
        icon: Icons.album_rounded,
        title: 'Nada por aquí',
        message: 'Prueba con otra búsqueda o escanea tu biblioteca.',
      );
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: <Widget>[
              Text(
                '${Formatters.count(groups.length)} ${view == LibraryView.albums ? 'álbumes' : 'artistas'}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.inkAlpha(0.54)),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            key: PageStorageKey<String>('library-groups-${view.name}'),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: (190 * scale).clamp(120.0, 340.0).toDouble(),
              mainAxisSpacing: 14 * scale,
              crossAxisSpacing: 14 * scale,
              childAspectRatio: 0.82,
            ),
            itemCount: groups.length,
            itemBuilder: (BuildContext context, int index) {
              final LibraryGroup group = groups[index];
              return _GroupCard(group: group, view: view, scale: scale);
            },
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.view, this.scale = 1});

  final LibraryGroup group;
  final LibraryView view;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (BuildContext context) =>
                LibraryGroupPage(group: group, view: view, scale: scale),
          ),
        ),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: context.tokens.panelDecoration(radius: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Center(
                  // FittedBox evita que una carátula grande recorte la tarjeta
                  // cuando la rejilla se reduce con el pellizco.
                  child: FittedBox(
                    child: TrackArtwork(
                      path: group.artworkPath,
                      size: 120 * scale,
                      radius: view == LibraryView.albums ? 12 : 60 * scale,
                      icon: group.icon,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                group.key,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                '${Formatters.count(group.tracks.length)} pistas',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.inkAlpha(0.54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detalle de un álbum o artista.
class LibraryGroupPage extends ConsumerWidget {
  const LibraryGroupPage({
    super.key,
    required this.group,
    required this.view,
    this.scale = 1,
  });

  final LibraryGroup group;
  final LibraryView view;
  final double scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(group.key)),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Reproducir todo',
        onPressed: () =>
            ref.read(playerControllerProvider.notifier).playQueue(group.tracks),
        child: const Icon(Icons.play_arrow_rounded),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: <Widget>[
                TrackArtwork(
                  path: group.artworkPath,
                  size: 72 * scale,
                  radius: view == LibraryView.albums ? 12 : 36 * scale,
                  icon: group.icon,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '${Formatters.count(group.tracks.length)} pistas · '
                    '${view == LibraryView.albums ? 'Álbum' : 'Artista'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              key: PageStorageKey<String>('group-${view.name}-${group.key}'),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              itemCount: group.tracks.length,
              itemBuilder: (BuildContext context, int index) => TrackTile(
                track: group.tracks[index],
                queue: group.tracks,
                index: index,
                showIndex: true,
                artworkSize: 46 * scale,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Raíces reales de almacenamiento/SD descubiertas durante el escaneo.
class FoldersView extends ConsumerWidget {
  const FoldersView({super.key, this.scale = 1});

  final double scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Track>> tracks = ref.watch(libraryAllTracksProvider);
    final AsyncValue<List<LibraryFolder>> folders = ref.watch(
      libraryFoldersProvider,
    );
    // Sin este estado, la primera carga mostraba un fondo gris con el mensaje
    // de "sin carpetas" durante unos instantes.
    if ((tracks.isLoading && tracks.valueOrNull == null) ||
        (folders.isLoading && folders.valueOrNull == null)) {
      return const Center(child: CircularProgressIndicator());
    }
    if ((tracks.hasError && tracks.valueOrNull == null) ||
        (folders.hasError && folders.valueOrNull == null)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No se pudo cargar el árbol de carpetas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    final FolderLibrary library = ref.watch(folderLibraryProvider);
    final List<FolderNode> nodes = <FolderNode>[
      ...library.roots,
      if (library.unclassified != null) library.unclassified!,
    ];
    if (nodes.isEmpty) {
      return const EmptyState(
        icon: Icons.folder_off_outlined,
        title: 'Todavía no hay carpetas indexadas',
        message: 'Añade una carpeta de música y pulsa “Escanear”.',
      );
    }
    return ListView.builder(
      key: const PageStorageKey<String>('library-folder-roots'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: nodes.length,
      itemBuilder: (BuildContext context, int index) {
        final FolderNode node = nodes[index];
        return Card(
          child: ListTile(
            leading: Icon(Icons.folder_rounded, size: 24 * scale),
            title: Text(
              node.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              node.path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              Formatters.count(node.count),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    FolderBrowserPage(root: node, scale: scale),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Explorador de una carpeta: subcarpetas + pistas directas y, en una segunda
/// pestaña, Vista General con todas las pistas descendientes y búsqueda local.
class FolderBrowserPage extends ConsumerStatefulWidget {
  const FolderBrowserPage({super.key, required this.root, this.scale = 1});

  final FolderNode root;
  final double scale;

  @override
  ConsumerState<FolderBrowserPage> createState() => _FolderBrowserPageState();
}

class _FolderBrowserPageState extends ConsumerState<FolderBrowserPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      if (!mounted) return;
      setState(() => _query = _search.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _open(FolderNode node) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            FolderBrowserPage(root: node, scale: widget.scale),
      ),
    );
  }

  Future<void> _playAll(List<Track> tracks) async {
    if (tracks.isEmpty) return;
    await ref.read(playerControllerProvider.notifier).playQueue(tracks);
  }

  @override
  Widget build(BuildContext context) {
    final FolderNode folder = widget.root;
    final LibrarySort sort = ref.watch(librarySortProvider);
    final bool ascending = ref.watch(libraryAscendingProvider);

    final List<Track> filtered = _query.isEmpty
        ? folder.descendantTracks
        : folder.descendantTracks
              .where(
                (Track track) =>
                    track.title.toLowerCase().contains(_query) ||
                    track.artist.toLowerCase().contains(_query) ||
                    track.album.toLowerCase().contains(_query) ||
                    track.path.toLowerCase().contains(_query),
              )
              .toList(growable: false);
    final List<Track> descendant = sortTracks(
      filtered,
      sort: sort,
      ascending: ascending,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          folder.breadcrumb,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const <Widget>[
            Tab(text: 'Contenido'),
            Tab(text: 'Vista General'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Reproducir todo',
        onPressed: () => _playAll(descendant),
        child: const Icon(Icons.play_arrow_rounded),
      ),
      body: TabBarView(
        controller: _tabs,
        children: <Widget>[
          if (folder.children.isEmpty && folder.directTracks.isEmpty)
            const EmptyState(
              icon: Icons.folder_open_rounded,
              title: 'Carpeta vacía',
              message: 'No hay pistas directas ni subcarpetas indexadas aquí.',
            )
          else
            ListView.builder(
              key: PageStorageKey<String>('folder-content-${folder.path}'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              itemCount: folder.children.length + folder.directTracks.length,
              itemBuilder: (BuildContext context, int index) {
                if (index < folder.children.length) {
                  final FolderNode child = folder.children[index];
                  return ListTile(
                    leading: Icon(
                      Icons.folder_rounded,
                      size: 24 * widget.scale,
                    ),
                    title: Text(
                      child.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(Formatters.count(child.count)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _open(child),
                  );
                }
                final int trackIndex = index - folder.children.length;
                return TrackTile(
                  track: folder.directTracks[trackIndex],
                  queue: folder.directTracks,
                  index: trackIndex,
                  showIndex: true,
                  artworkSize: 46 * widget.scale,
                );
              },
            ),
          Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Buscar en esta carpeta y subcarpetas…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => _search.clear(),
                          ),
                  ),
                ),
              ),
              Expanded(
                child: descendant.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Sin coincidencias',
                        message: 'Prueba con otro título, artista o álbum.',
                      )
                    : ListView.builder(
                        key: PageStorageKey<String>(
                          'folder-overview-${folder.path}',
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        itemCount: descendant.length,
                        itemBuilder: (BuildContext context, int index) =>
                            TrackTile(
                              track: descendant[index],
                              queue: descendant,
                              index: index,
                              showIndex: true,
                              artworkSize: 46 * widget.scale,
                            ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
