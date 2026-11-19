import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/utils/lrc_parser.dart';
import '../../../shared/widgets/polaris_surface.dart';
import '../data/lyrics_service.dart';
import 'lyrics_editor_dialog.dart';
import 'lyrics_panel.dart';
import 'lyrics_providers.dart';

/// Letras sincronizadas que ocupan exactamente el hueco de la carátula.
///
/// No es una ventana ni una pantalla independiente: vive dentro del mismo
/// contenedor cuadrado del reproductor. El `AnimatedSwitcher` de la carátula se
/// encarga de fundir este widget con la imagen cuando se activa/desactiva.
class InArtworkLyrics extends ConsumerStatefulWidget {
  const InArtworkLyrics({
    super.key,
    required this.track,
    required this.size,
    required this.accent,
    required this.onClose,
  });

  final Track track;
  final double size;
  final Color accent;
  final VoidCallback onClose;

  @override
  ConsumerState<InArtworkLyrics> createState() => _InArtworkLyricsState();
}

class _InArtworkLyricsState extends ConsumerState<InArtworkLyrics> {
  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _invalidate() => ref.invalidate(lyricsForTrackProvider(widget.track));

  Future<void> _download() async {
    final LyricsResult? result = await ref
        .read(lyricsServiceProvider)
        .download(widget.track);
    _invalidate();
    _toast(
      result == null
          ? 'No se encontró letra sincronizada para esta canción'
          : 'Letra descargada desde ${result.source}',
    );
  }

  Future<void> _import() async {
    final List<PlatformFile> picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['lrc'],
      dialogTitle: 'Importar archivo .lrc',
    );
    final String? path = picked.isEmpty ? null : picked.first.path;
    if (path == null) return;
    try {
      await ref.read(lyricsServiceProvider).importLrc(widget.track, path);
      _invalidate();
      _toast('Letra importada correctamente');
    } catch (error) {
      _toast('No se pudo importar la letra: $error');
    }
  }

  Future<void> _edit() async {
    final LyricsResult? current = ref
        .read(lyricsForTrackProvider(widget.track))
        .valueOrNull;
    final LrcDocument initial = current?.document ?? LrcDocument.empty();
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

  @override
  Widget build(BuildContext context) {
    final double radius = (widget.size * 0.10).clamp(16.0, 26.0);

    return PolarisSurface(
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 4),
      borderRadius: radius,
      glowColor: widget.accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.lyrics_rounded, size: 16, color: widget.accent),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Letras',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones de letra',
                icon: const Icon(Icons.more_vert_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: _onMenuSelected,
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'download',
                        child: Text('Descargar de LRCLIB'),
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
                icon: const Icon(Icons.close_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Expanded(
            child: LyricsPanel(
              track: widget.track,
              // Tipografía compacta: la letra debe caber en el hueco de la
              // carátula sin convertirse en una pantalla flotante.
              immersive: false,
              showTools: false,
              onDownload: _download,
              onImport: _import,
              onEdit: _edit,
            ),
          ),
        ],
      ),
    );
  }
}
