import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/models/track.dart';
import '../../../core/services/storage_paths_service.dart';
import '../../player/presentation/player_providers.dart';
import '../data/playlist_service.dart';
import '../domain/smart_playlist.dart';
import 'library_providers.dart';

/// Gestión ligera de listas: crear, reproducir, exportar y borrar.
///
/// Las inteligentes se evalúan contra la biblioteca al abrirlas; las normales
/// guardan sus pistas en la base de datos.
class PlaylistsDialog extends ConsumerWidget {
  const PlaylistsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PlaylistRow>> playlists = ref.watch(
      playlistsProvider,
    );

    return AlertDialog(
      title: const Text('Listas de reproducción'),
      content: SizedBox(
        width: 520,
        child: playlists.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stack) =>
              Text('No se pudieron cargar las listas: $error'),
          data: (List<PlaylistRow> rows) => Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('Todavía no hay listas.'),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (BuildContext context, int i) =>
                        _PlaylistTile(playlist: rows[i]),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () => _create(context, ref, smart: false),
                    icon: const Icon(Icons.playlist_add_rounded, size: 18),
                    label: const Text('Nueva'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _create(context, ref, smart: true),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Inteligente'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Future<void> _create(
    BuildContext context,
    WidgetRef ref, {
    required bool smart,
  }) async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _NewPlaylistDialog(smart: smart),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    final PlaylistService service = ref.read(playlistServiceProvider);
    if (smart) {
      final SmartPlaylistRule? rule = await showDialog<SmartPlaylistRule>(
        context: context,
        builder: (BuildContext context) => const _RuleDialog(),
      );
      if (rule == null) return;
      await service.createSmart(name, rule);
    } else {
      await service.create(name);
    }
  }
}

class _PlaylistTile extends ConsumerWidget {
  const _PlaylistTile({required this.playlist});

  final PlaylistRow playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SmartPlaylistRule? rule = SmartPlaylistRule.fromName(
      playlist.description ?? '',
    );
    return ListTile(
      dense: true,
      leading: Icon(
        playlist.isSmart
            ? Icons.auto_awesome_rounded
            : Icons.queue_music_rounded,
        size: 20,
      ),
      title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        rule?.description ?? 'Lista personalizada',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Reproducir',
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            onPressed: () => _play(context, ref),
          ),
          IconButton(
            tooltip: 'Exportar M3U',
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            onPressed: () => _export(context, ref),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _play(BuildContext context, WidgetRef ref) async {
    final List<Track> tracks = await ref
        .read(playlistServiceProvider)
        .tracksOf(playlist);
    if (!context.mounted) return;
    if (tracks.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Esta lista está vacía')));
      return;
    }
    await ref.read(playerControllerProvider.notifier).playQueue(tracks);
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final List<Track> tracks = await ref
        .read(playlistServiceProvider)
        .tracksOf(playlist);
    if (!context.mounted || tracks.isEmpty) return;
    final Directory documents = await sl<StoragePathsService>().documents();
    final String? folder = await FilePicker.getDirectoryPath(
      dialogTitle: 'Carpeta donde guardar el M3U',
      initialDirectory: documents.path,
    );
    if (folder == null || !context.mounted) return;
    final String safeName = playlist.name.replaceAll(
      RegExp(r'[<>:"/\\|?*]'),
      '_',
    );
    final String out =
        '$folder${Platform.pathSeparator}Polaris - $safeName.m3u8';
    await ref.read(playlistServiceProvider).exportM3u(out, tracks);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lista exportada')));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool confirm =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Eliminar lista'),
            content: Text('¿Eliminar «${playlist.name}»?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirm) await ref.read(playlistServiceProvider).delete(playlist.id);
  }
}

class _NewPlaylistDialog extends StatefulWidget {
  const _NewPlaylistDialog({required this.smart});

  final bool smart;

  @override
  State<_NewPlaylistDialog> createState() => _NewPlaylistDialogState();
}

class _NewPlaylistDialogState extends State<_NewPlaylistDialog> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.smart ? 'Nueva lista inteligente' : 'Nueva lista'),
      content: TextField(
        controller: _name,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nombre'),
        onSubmitted: (String value) => Navigator.pop(context, value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _name.text),
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

class _RuleDialog extends StatelessWidget {
  const _RuleDialog();

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Regla de la lista'),
      children: <Widget>[
        for (final SmartPlaylistRule rule in SmartPlaylistRule.values)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, rule),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(rule.label),
                const SizedBox(height: 2),
                Text(
                  rule.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
