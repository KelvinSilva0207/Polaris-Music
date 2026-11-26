import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/track.dart';
import '../../core/theme/theme_tokens.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/formatters.dart';
import '../../features/library/data/metadata_editor_service.dart';
import '../../features/library/presentation/library_providers.dart';
import '../../features/player/domain/player_controller.dart';
import '../../features/player/presentation/player_providers.dart';
import 'playing_indicator.dart';
import 'track_artwork.dart';
import 'track_properties_modal.dart';

/// Acciones compartidas por el menú “más acciones” y el clic derecho.
/// Se mantiene una sola definición para que ambos accesos no puedan divergir.
const List<PopupMenuEntry<String>> _trackMenuItems = <PopupMenuEntry<String>>[
  PopupMenuItem<String>(value: 'play', child: Text('Reproducir ahora')),
  PopupMenuItem<String>(value: 'queue', child: Text('Añadir a la cola')),
  PopupMenuItem<String>(
    value: 'play-next',
    child: Text('Reproducir a continuación'),
  ),
  PopupMenuItem<String>(value: 'properties', child: Text('Propiedades')),
  PopupMenuItem<String>(value: 'edit', child: Text('Editar metadatos')),
  PopupMenuDivider(),
  PopupMenuItem<String>(
    value: 'delete',
    child: Text('Quitar de la biblioteca'),
  ),
];

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
    this.artworkSize = 46,
  });

  final Track track;
  final List<Track>? queue;
  final int? index;
  final bool showIndex;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Tamaño de la carátula. La biblioteca lo escala con el gesto de pellizco;
  /// el resto de pantallas conserva el valor por defecto.
  final double artworkSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Selectores escalares: el estado del reproductor cambia con cada tick de
    // posición (~5 Hz). Observarlo aquí reconstruiría todas las filas visibles
    // de la biblioteca aunque ni la pista ni el estado de play cambiaran.
    final int? currentId = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.track?.id),
    );
    final bool playing = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playing),
    );
    final bool current = currentId == track.id;
    final ThemeData theme = Theme.of(context);
    final Color accent = context.accent;

    return GestureDetector(
      onSecondaryTapDown: (TapDownDetails details) =>
          _showContextMenu(context, ref, details.globalPosition),
      child: ListTile(
        key: ValueKey<int>(track.id),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: current ? accent.withValues(alpha: 0.12) : null,
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
                      color: current ? accent : context.inkAlpha(0.38),
                    ),
                  ),
                ),
              ),
            Stack(
              alignment: Alignment.bottomRight,
              clipBehavior: Clip.none,
              children: <Widget>[
                TrackArtwork(
                  key: ValueKey<int>(track.id),
                  path: track.artworkPath,
                  size: artworkSize,
                  radius: 10,
                ),
                if (current)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: PlayingIndicator(
                      active: current,
                      playing: playing,
                      color: accent,
                    ),
                  ),
              ],
            ),
          ],
        ),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            color: current ? accent : null,
          ),
        ),
        subtitle: Row(
          children: <Widget>[
            if (track.isDownloaded)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.cloud_done_rounded,
                  size: 12,
                  color: accent.withValues(alpha: 0.85),
                ),
              ),
            Flexible(
              child: Text(
                track.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.inkAlpha(0.54),
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ?trailing,
            Text(
              Formatters.duration(track.duration),
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.inkAlpha(0.38),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: !track.isPersisted
                  ? 'Descarga la pista para guardarla'
                  : track.isFavorite
                  ? 'Quitar de favoritos'
                  : 'Añadir a favoritos',
              icon: Icon(
                track.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: track.isFavorite ? accent : context.inkAlpha(0.38),
                size: 20,
              ),
              onPressed: track.isPersisted
                  ? () => ref
                        .read(libraryRepositoryProvider)
                        .setFavorite(track.id, !track.isFavorite)
                  : null,
            ),
            PopupMenuButton<String>(
              tooltip: 'Más acciones',
              icon: Icon(
                Icons.more_vert_rounded,
                color: context.inkAlpha(0.38),
                size: 20,
              ),
              onSelected: (String action) =>
                  _handleAction(context, ref, action),
              itemBuilder: (BuildContext context) => _trackMenuItems,
            ),
          ],
        ),
        // En Android el menú de opciones cubre "Propiedades"; una pulsación
        // larga la abre directamente.
        onLongPress: () => TrackPropertiesModal.show(
          context: context,
          track: track,
          accent: context.accent,
        ),
        onTap:
            onTap ??
            () => ref
                .read(playerControllerProvider.notifier)
                .playTrack(track, queue: queue),
      ),
    );
  }

  /// Menú contextual del clic derecho (escritorio).
  Future<void> _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
  ) async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final String? action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: _trackMenuItems,
    );
    if (action != null && context.mounted) {
      await _handleAction(context, ref, action);
    }
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
      case 'play-next':
        await ref
            .read(playerControllerProvider.notifier)
            .addAfterCurrent(track);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('“${track.title}” se reproducirá a continuación'),
            ),
          );
        }
      case 'properties':
        await TrackPropertiesModal.show(
          context: context,
          track: track,
          accent: context.accent,
        );
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
        title: Text('Quitar de la biblioteca'),
        content: Text(
          '“${track.title}” dejará de aparecer en Polaris Music. '
          'El archivo de audio no se elimina del disco.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(libraryRepositoryProvider).deleteTracks(<int>[track.id]);
  }
}

/// Editor de etiquetas de una pista.
///
/// Escribe los cambios en el archivo de audio (en un isolate), guarda la
/// carátula elegida en caché y sincroniza la base de datos y la cola activa.
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

  Uint8List? artworkBytes;
  String? artworkExtension;
  bool pickingArtwork = false;
  bool saving = false;

  Future<void> pickArtwork(StateSetter setState) async {
    if (pickingArtwork) return;
    pickingArtwork = true;
    setState(() {});
    try {
      final List<PlatformFile> pickedFiles = await FilePicker.pickFiles(
        dialogTitle: 'Elegir carátula',
        type: FileType.image,
      );
      if (pickedFiles.isEmpty) return;

      final PlatformFile picked = pickedFiles.first;
      Uint8List? bytes;
      try {
        bytes = await picked.readAsBytes();
      } catch (_) {
        final String? path = picked.path;
        if (path == null) rethrow;
        bytes = await File(path).readAsBytes();
      }

      final String fromName = FileUtils.extensionOf(picked.name);
      final String fromPath = FileUtils.extensionOf(picked.path ?? '');
      setState(() {
        artworkBytes = bytes;
        artworkExtension = fromName.isEmpty ? fromPath : fromName;
      });
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la imagen: $error')),
        );
      }
    } finally {
      pickingArtwork = false;
      if (context.mounted) setState(() {});
    }
  }

  final bool? save = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => AlertDialog(
        title: Text('Editar metadatos'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: pickingArtwork
                          ? null
                          : () => pickArtwork(setState),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: context.inkAlpha(0.06),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: artworkBytes == null
                              ? TrackArtwork(path: track.artworkPath, size: 64)
                              : Image.memory(
                                  artworkBytes!,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  cacheWidth:
                                      (64 *
                                              MediaQuery.devicePixelRatioOf(
                                                context,
                                              ))
                                          .round()
                                          .clamp(24, 160),
                                  cacheHeight:
                                      (64 *
                                              MediaQuery.devicePixelRatioOf(
                                                context,
                                              ))
                                          .round()
                                          .clamp(24, 160),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Carátula',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pickingArtwork
                                ? 'Abriendo imagen…'
                                : 'Toca la portada para elegir otra imagen',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: context.inkAlpha(0.54)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
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
                  'Los cambios se escriben en el archivo de audio cuando el '
                  'formato lo admite y se reflejan en la biblioteca.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.inkAlpha(0.54)),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    saving = true;
                    setState(() {});
                    Navigator.pop(context, true);
                  },
            child: Text('Guardar'),
          ),
        ],
      ),
    ),
  );

  if (save == true) {
    final MetadataEditValues values = MetadataEditValues(
      title: title.text.trim(),
      artist: artist.text.trim(),
      album: album.text.trim(),
      albumArtist: albumArtist.text.trim(),
      genre: genre.text.trim(),
      year: int.tryParse(year.text.trim()),
      trackNumber: int.tryParse(trackNumber.text.trim()),
      discNumber: int.tryParse(discNumber.text.trim()),
    );
    try {
      final String? cachedArtworkPath = await ref
          .read(metadataEditorServiceProvider)
          .save(
            track,
            values,
            artworkBytes: artworkBytes,
            artworkExtension: artworkExtension,
          );
      await ref
          .read(playerControllerProvider.notifier)
          .updateTrackMetadata(
            track.id,
            title: values.title,
            artist: values.artist,
            album: values.album,
            albumArtist: values.albumArtist,
            genre: values.genre,
            year: values.year,
            trackNumber: values.trackNumber,
            discNumber: values.discNumber,
            artworkPath: cachedArtworkPath,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Etiquetas guardadas')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudieron guardar las etiquetas: $error'),
          ),
        );
      }
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
