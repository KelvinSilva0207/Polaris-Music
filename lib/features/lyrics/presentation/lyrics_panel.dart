import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/lrc_parser.dart';
import '../../player/domain/player_controller.dart';
import '../../player/presentation/player_providers.dart';
import '../data/lyrics_service.dart';
import 'lyrics_providers.dart';

/// Panel de letras con resaltado tipo karaoke de la línea activa.
///
/// La sincronía se apoya en el LRC (local, caché o LRCLIB) y en la posición del
/// motor de reproducción. En [immersive] se usa tipografía protagonista y se
/// muestran las herramientas de descarga, importación y edición.
class LyricsPanel extends ConsumerStatefulWidget {
  const LyricsPanel({
    super.key,
    required this.track,
    this.immersive = false,
    this.showTools = false,
    this.onDownload,
    this.onImport,
    this.onEdit,
  });

  final Track track;
  final bool immersive;
  final bool showTools;
  final VoidCallback? onDownload;
  final VoidCallback? onImport;
  final VoidCallback? onEdit;

  @override
  ConsumerState<LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends ConsumerState<LyricsPanel> {
  final ScrollController _scroll = ScrollController();
  int? _lastActive;
  bool _karaoke = true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToActive(int index, int total) {
    if (index == _lastActive || !_scroll.hasClients) return;
    _lastActive = index;
    final double fraction = total <= 1 ? 0 : index / (total - 1);
    final double target = _scroll.position.maxScrollExtent * fraction;
    _scroll.animateTo(
      target.clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<LyricsResult?> lyrics = ref.watch(
      lyricsForTrackProvider(widget.track),
    );
    final int positionMs = ref.watch(
      playerControllerProvider.select(
        (PlayerUiState s) => s.playback.position.inMilliseconds,
      ),
    );

    return lyrics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No se pudieron cargar las letras.\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
      ),
      data: (LyricsResult? result) {
        if (result == null || result.isEmpty) {
          return _LyricsEmpty(
            showTools: widget.showTools,
            onRetry: () => ref.invalidate(lyricsForTrackProvider(widget.track)),
            onDownload: widget.onDownload,
            onImport: widget.onImport,
            onEdit: widget.onEdit,
          );
        }

        final LrcDocument document = result.document;
        if (!document.synced) {
          return _PlainLyrics(
            text: document.plainText,
            source: result.source,
            immersive: widget.immersive,
          );
        }

        final int? active = _karaoke
            ? document.activeIndexAt(Duration(milliseconds: positionMs))
            : null;
        if (active != null) {
          WidgetsBinding.instance.addPostFrameCallback((Duration _) {
            if (mounted) _scrollToActive(active, document.lines.length);
          });
        }

        final PolarisTokens tokens = context.tokens;
        final double activeSize = widget.immersive ? 36 : 22;
        final double normalSize = widget.immersive ? 25 : 17;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (widget.showTools || !widget.immersive)
              _LyricsToolbar(
                source: result.source,
                synced: document.synced,
                karaoke: _karaoke,
                showTools: widget.showTools,
                onDownload: widget.onDownload,
                onImport: widget.onImport,
                onEdit: widget.onEdit,
                onKaraokeChanged: (bool value) =>
                    setState(() => _karaoke = value),
              ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: widget.immersive
                    ? const EdgeInsets.fromLTRB(24, 28, 24, 96)
                    : const EdgeInsets.fromLTRB(20, 18, 20, 40),
                itemCount: document.lines.length,
                itemBuilder: (BuildContext context, int index) {
                  final LyricLine line = document.lines[index];
                  final bool isActive = index == active;
                  final bool isPast = active != null && index < active;
                  // Cada línea entra con una pequeña onda escalonada: el
                  // conjunto se funde con la carátula como un solo morfeo.
                  return TweenAnimationBuilder<double>(
                    key: ValueKey<int>(index),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 280 + (index % 6) * 26),
                    curve: Curves.easeOutCubic,
                    builder:
                        (BuildContext context, double value, Widget? child) =>
                            Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, (1 - value) * 12),
                                child: child,
                              ),
                            ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: widget.immersive ? 12 : 6,
                      ),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: TextStyle(
                          fontSize: isActive ? activeSize : normalSize,
                          height: 1.32,
                          fontWeight: isActive
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isActive
                              ? tokens.karaokeColor
                              : isPast
                              ? Colors.white.withValues(alpha: 0.38)
                              : Colors.white.withValues(alpha: 0.80),
                          shadows: isActive
                              ? <Shadow>[
                                  Shadow(
                                    color: tokens.karaokeColor.withValues(
                                      alpha: 0.45,
                                    ),
                                    blurRadius: widget.immersive ? 26 : 12,
                                  ),
                                ]
                              : null,
                        ),
                        textAlign: TextAlign.center,
                        child: Text(line.text.isEmpty ? '♪' : line.text),
                      ),
                    ),
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

class _LyricsToolbar extends StatelessWidget {
  const _LyricsToolbar({
    required this.source,
    required this.synced,
    required this.karaoke,
    required this.onKaraokeChanged,
    this.showTools = false,
    this.onDownload,
    this.onImport,
    this.onEdit,
  });

  final String source;
  final bool synced;
  final bool karaoke;
  final ValueChanged<bool> onKaraokeChanged;
  final bool showTools;
  final VoidCallback? onDownload;
  final VoidCallback? onImport;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final String label = switch (source) {
      'local' => 'Archivo .lrc local',
      'embedded' => 'Letra embebida',
      'lrclib' => 'LRCLIB',
      'backup' => 'Respaldo',
      'user' => 'Tu letra',
      _ => source,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              synced ? label : '$label · sin sincronía',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Colors.white54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showTools) ...<Widget>[
            IconButton(
              tooltip: 'Descargar de LRCLIB',
              onPressed: onDownload,
              icon: const Icon(Icons.cloud_download_outlined, size: 18),
            ),
            IconButton(
              tooltip: 'Importar archivo .lrc',
              onPressed: onImport,
              icon: const Icon(Icons.file_open_outlined, size: 18),
            ),
            IconButton(
              tooltip: 'Crear o sincronizar letra',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_note_rounded, size: 18),
            ),
          ],
          if (synced)
            FilterChip(
              label: const Text('Karaoke'),
              selected: karaoke,
              onSelected: onKaraokeChanged,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _PlainLyrics extends StatelessWidget {
  const _PlainLyrics({
    required this.text,
    required this.source,
    this.immersive = false,
  });

  final String text;
  final String source;
  final bool immersive;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: <Widget>[
        Text(
          'Letra sin sincronía · $source',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Colors.white38),
        ),
        const SizedBox(height: 16),
        SelectableText(
          text,
          textAlign: immersive ? TextAlign.center : TextAlign.start,
          style: TextStyle(fontSize: immersive ? 24 : 18, height: 1.5),
        ),
      ],
    );
  }
}

class _LyricsEmpty extends StatelessWidget {
  const _LyricsEmpty({
    required this.onRetry,
    this.showTools = false,
    this.onDownload,
    this.onImport,
    this.onEdit,
  });

  final VoidCallback onRetry;
  final bool showTools;
  final VoidCallback? onDownload;
  final VoidCallback? onImport;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.lyrics_outlined, size: 46, color: Colors.white24),
            const SizedBox(height: 14),
            const Text(
              'Sin letra para esta canción',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Polaris busca primero un archivo .lrc junto al audio, luego la '
              'caché local y finalmente LRCLIB.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Buscar de nuevo'),
                ),
                if (showTools) ...<Widget>[
                  OutlinedButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.cloud_download_outlined, size: 18),
                    label: const Text('Descargar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onImport,
                    icon: const Icon(Icons.file_open_outlined, size: 18),
                    label: const Text('Importar .lrc'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Crear letra'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
