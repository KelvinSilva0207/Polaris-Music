import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/lrc_parser.dart';
import '../../player/presentation/player_providers.dart';
import '../data/lyrics_service.dart';
import 'lyrics_editor_dialog.dart';
import 'lyrics_panel.dart';
import 'lyrics_providers.dart';

/// Letras a pantalla completa dentro del reproductor.
///
/// No vive en el hueco de la carátula: ocupa todo el área libre que le cede el
/// layout del reproductor. La línea de tiempo y los controles permanecen intactos
/// porque este widget es solo la rama de contenido, nunca un overlay.
class ExpandedLyricsView extends ConsumerStatefulWidget {
  const ExpandedLyricsView({
    super.key,
    required this.track,
    required this.accent,
    required this.onClose,
  });

  final Track track;
  final Color accent;
  final VoidCallback onClose;

  @override
  ConsumerState<ExpandedLyricsView> createState() => _ExpandedLyricsViewState();
}

class _ExpandedLyricsViewState extends ConsumerState<ExpandedLyricsView> {
  /// Aviso de una sola línea, sin SnackBar ni fondos de error.
  String? _notice;

  @override
  void didUpdateWidget(covariant ExpandedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track != widget.track) _notice = null;
  }

  void _invalidate() => ref.invalidate(lyricsForTrackProvider(widget.track));

  Future<void> _download() async {
    final LyricsResult? result = await ref
        .read(lyricsServiceProvider)
        .download(widget.track);
    if (!mounted) return;
    _invalidate();
    setState(() {
      _notice = result == null
          ? 'No hay letra disponible para esta canción'
          : null;
    });
  }

  Future<void> _import() async {
    final List<PlatformFile> picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['lrc'],
      dialogTitle: 'Importar archivo .lrc',
    );
    final String? path = picked.isEmpty ? null : picked.first.path;
    if (path == null || !mounted) return;
    try {
      await ref.read(lyricsServiceProvider).importLrc(widget.track, path);
      _invalidate();
      setState(() => _notice = null);
    } catch (_) {
      setState(() => _notice = 'No se pudo leer el archivo .lrc');
    }
  }

  Future<void> _edit() async {
    final LrcDocument initial =
        ref.read(lyricsForTrackProvider(widget.track)).valueOrNull?.document ??
        LrcDocument.empty();
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) =>
          LyricsEditorDialog(track: widget.track, initial: initial),
    );
    if (saved == true) _invalidate();
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'download':
        unawaited(_download());
      case 'import':
        unawaited(_import());
      case 'edit':
        unawaited(_edit());
    }
  }

  void _toggleKaraoke(bool enabled) {
    unawaited(ref.read(settingsServiceProvider).setKaraokeEnabled(!enabled));
  }

  @override
  Widget build(BuildContext context) {
    final Color ink = context.onPanel;
    final bool synced =
        ref
            .watch(lyricsForTrackProvider(widget.track))
            .valueOrNull
            ?.document
            .synced ??
        false;
    ref.watch(settingsValuesProvider);
    final bool karaoke = ref.read(settingsServiceProvider).karaokeEnabled;

    // Sin superficie propia: la letra usa el mismo lienzo que el reproductor.
    // Solo una fila de controles muy discreta la separa del resto del player.
    return Material(
      // Material transparente: da contexto a IconButton/InkWell sin dibujar
      // superficie, borde ni sombra. La letra comparte el lienzo del player.
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: <Widget>[
                const Spacer(),
                IconButton(
                  tooltip: karaoke
                      ? 'Desactivar karaoke'
                      : 'Karaoke: resalta cada palabra',
                  onPressed: synced ? () => _toggleKaraoke(karaoke) : null,
                  icon: Icon(
                    karaoke ? Icons.lyrics_rounded : Icons.lyrics_outlined,
                    size: 19,
                    color: karaoke
                        ? widget.accent
                        : ink.withValues(alpha: synced ? 0.6 : 0.25),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opciones de letra',
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 19,
                    color: ink.withValues(alpha: 0.6),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: _onMenuSelected,
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'download',
                          child: Text('Buscar letra en LRCLIB'),
                        ),
                        PopupMenuItem<String>(
                          value: 'import',
                          child: Text('Importar archivo .lrc'),
                        ),
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Crear o sincronizar letra'),
                        ),
                      ],
                ),
                IconButton(
                  tooltip: 'Volver a la carátula',
                  onPressed: widget.onClose,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 19,
                    color: ink.withValues(alpha: 0.6),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _notice!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: context.onPanel.withValues(alpha: 0.52),
                ),
              ),
            ),
          Expanded(
            child: LyricsPanel(
              track: widget.track,
              immersive: true,
              showTools: false,
              onDownload: _download,
              onImport: _import,
              onEdit: _edit,
              karaoke: karaoke,
              onSeek: (Duration position) => unawaited(
                ref.read(playerControllerProvider.notifier).seek(position),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
