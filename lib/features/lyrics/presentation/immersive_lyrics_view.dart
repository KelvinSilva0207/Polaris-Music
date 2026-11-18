import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/lrc_parser.dart';
import '../../player/domain/player_controller.dart';
import '../../player/presentation/player_providers.dart';
import '../data/lyrics_service.dart';
import 'lyrics_editor_dialog.dart';
import 'lyrics_panel.dart';
import 'lyrics_providers.dart';

/// Letras a pantalla completa sobre la carátula difuminada.
///
/// Sustituye al reproductor mientras está activa: la carátula y el vinilo se
/// ocultan con una transición suave y el karaoke pasa a ser protagonista.
class ImmersiveLyricsView extends ConsumerStatefulWidget {
  const ImmersiveLyricsView({
    super.key,
    required this.track,
    required this.onClose,
  });

  final Track track;
  final VoidCallback onClose;

  @override
  ConsumerState<ImmersiveLyricsView> createState() =>
      _ImmersiveLyricsViewState();
}

class _ImmersiveLyricsViewState extends ConsumerState<ImmersiveLyricsView> {
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

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final Duration position = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.position),
    );
    final Duration duration = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.duration),
    );
    final double progress = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.progress),
    );
    final String? artwork = widget.track.artworkPath;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // El fondo borroso no depende de la posición: se aísla en su propia
          // capa de repintado para que el tick de 5 Hz no lo vuelva a filtrar.
          RepaintBoundary(
            child: _BlurredArtwork(artwork: artwork, accent: tokens.accent),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0xB3000000)),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Volver al reproductor',
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Letras',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: tokens.accent,
                              ),
                            ),
                            Text(
                              widget.track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              widget.track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Volver al reproductor',
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LyricsPanel(
                    track: widget.track,
                    immersive: true,
                    showTools: true,
                    onDownload: _download,
                    onImport: _import,
                    onEdit: _edit,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 16),
                  child: Column(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: Colors.white.withValues(alpha: 0.10),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            tokens.progressColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            Formatters.duration(position),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white60,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _edit,
                            icon: const Icon(Icons.edit_note_rounded, size: 16),
                            label: const Text('Editar letra'),
                          ),
                          Text(
                            Formatters.duration(duration),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carátula difuminada a pantalla completa. Se construye una sola vez por
/// pista/tema; el karaoke se reconstruye encima sin tocar este filtro.
class _BlurredArtwork extends StatelessWidget {
  const _BlurredArtwork({required this.artwork, required this.accent});

  final String? artwork;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final String? path = artwork;
    if (path == null) return _FallbackBackdrop(accent: accent);
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _FallbackBackdrop(accent: accent),
      ),
    );
  }
}

class _FallbackBackdrop extends StatelessWidget {
  const _FallbackBackdrop({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color.lerp(const Color(0xFF08080C), accent, 0.34) ??
                const Color(0xFF08080C),
            const Color(0xFF08080C),
          ],
        ),
      ),
    );
  }
}
