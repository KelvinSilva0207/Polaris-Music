import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/track.dart';
import '../../core/utils/formatters.dart';
import '../../features/library/data/library_repository.dart';
import '../../features/library/presentation/library_providers.dart';
import '../../features/player/domain/player_controller.dart';
import '../../features/player/presentation/player_providers.dart';
import 'track_artwork.dart';

/// Fila de pista usada por biblioteca, cola, historial y recomendaciones.
class TrackTile extends ConsumerWidget {
  const TrackTile({
    super.key,
    required this.track,
    this.queue,
    this.index,
    this.showIndex = false,
    this.trailing,
    this.onTap,
  });

  final Track track;
  final List<Track>? queue;
  final int? index;
  final bool showIndex;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayerUiState ui = ref.watch(playerControllerProvider);
    final bool current = ui.track?.id == track.id;
    final ThemeData theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: current
          ? theme.colorScheme.primary.withValues(alpha: 0.12)
          : null,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showIndex)
            SizedBox(
              width: 28,
              child: Center(
                child: Text(
                  '${(index ?? 0) + 1}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: current ? theme.colorScheme.primary : Colors.white38,
                  ),
                ),
              ),
            ),
          TrackArtwork(path: track.artworkPath, size: 46, radius: 10),
        ],
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: current ? FontWeight.w700 : FontWeight.w500,
          color: current ? theme.colorScheme.primary : null,
        ),
      ),
      subtitle: Text(
        track.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ?trailing,
          Text(
            Formatters.duration(track.duration),
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: track.isFavorite
                ? 'Quitar de favoritos'
                : 'Añadir a favoritos',
            icon: Icon(
              track.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: track.isFavorite
                  ? theme.colorScheme.primary
                  : Colors.white38,
              size: 20,
            ),
            onPressed: () => ref
                .read(libraryRepositoryProvider)
                .setFavorite(track.id, !track.isFavorite),
          ),
          PopupMenuButton<String>(
            tooltip: 'Más acciones',
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.white38,
              size: 20,
            ),
            onSelected: (String action) => _handleAction(context, ref, action),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'play',
                child: Text('Reproducir ahora'),
              ),
              const PopupMenuItem<String>(
                value: 'queue',
                child: Text('Añadir a la cola'),
              ),
              const PopupMenuItem<String>(
                value: 'edit',
                child: Text('Editar metadatos'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Quitar de la biblioteca'),
              ),
            ],
          ),
        ],
      ),
      onTap:
          onTap ??
          () => ref
              .read(playerControllerProvider.notifier)
              .playTrack(track, queue: queue),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    switch (action) {
      case 'play':
        await ref
            .read(playerControllerProvider.notifier)
            .playTrack(track, queue: queue);
      case 'queue':
        await ref.read(playerControllerProvider.notifier).addToQueue(track);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('“${track.title}” añadida a la cola')),
          );
        }
      case 'edit':
        await showMetadataEditor(context, ref, track);
      case 'delete':
        await _confirmDelete(context, ref);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Quitar de la biblioteca'),
        content: Text(
          '“${track.title}” dejará de aparecer en Polaris Music. '
          'El archivo de audio no se elimina del disco.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(libraryRepositoryProvider).deleteTracks(<int>[track.id]);
  }
}

/// Editor de metadatos de Fase 1.
///
/// Solo actualiza la base de datos local; la escritura de tags en el archivo
/// original se hará en Fase 2 (documentado en README).
Future<void> showMetadataEditor(
  BuildContext context,
  WidgetRef ref,
  Track track,
) async {
  final TextEditingController title = TextEditingController(text: track.title);
  final TextEditingController artist = TextEditingController(
    text: track.artist,
  );
  final TextEditingController album = TextEditingController(text: track.album);
  final TextEditingController albumArtist = TextEditingController(
    text: track.albumArtist,
  );
  final TextEditingController genre = TextEditingController(text: track.genre);
  final TextEditingController year = TextEditingController(
    text: track.year?.toString() ?? '',
  );
  final TextEditingController trackNumber = TextEditingController(
    text: track.trackNumber?.toString() ?? '',
  );
  final TextEditingController discNumber = TextEditingController(
    text: track.discNumber?.toString() ?? '',
  );

  final bool? save = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Editar metadatos'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: artist,
                decoration: const InputDecoration(labelText: 'Artista'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: album,
                decoration: const InputDecoration(labelText: 'Álbum'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: albumArtist,
                decoration: const InputDecoration(
                  labelText: 'Artista del álbum',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: genre,
                      decoration: const InputDecoration(labelText: 'Género'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: year,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Año'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: trackNumber,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Pista'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: discNumber,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Disco'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Fase 1: los cambios se guardan en la base de datos de Polaris. '
                'La escritura de etiquetas en el archivo llegará en la Fase 2.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );

  if (save == true) {
    final LibraryRepository repository = ref.read(libraryRepositoryProvider);
    await repository.updateMetadata(
      track,
      title: title.text.trim(),
      artist: artist.text.trim(),
      album: album.text.trim(),
      albumArtist: albumArtist.text.trim(),
      genre: genre.text.trim(),
      year: int.tryParse(year.text.trim()),
      trackNumber: int.tryParse(trackNumber.text.trim()),
      discNumber: int.tryParse(discNumber.text.trim()),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Metadatos guardados')));
    }
  }

  title.dispose();
  artist.dispose();
  album.dispose();
  albumArtist.dispose();
  genre.dispose();
  year.dispose();
  trackNumber.dispose();
  discNumber.dispose();
}
