import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/providers/compact_style_provider.dart';
import '../../../core/theme/compact_style_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/compact_surface.dart';
import '../../../shared/widgets/track_artwork.dart';
import '../domain/player_controller.dart';
import 'player_providers.dart';

/// Progreso aislado: es el único hijo de la mini barra que cambia con el tick
/// de posición, así que su reconstrucción no arrastra el `BackdropFilter`.
class _MiniProgress extends ConsumerWidget {
  const _MiniProgress({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double progress = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.progress),
    );
    return LinearProgressIndicator(
      value: progress.clamp(0.0, 1.0),
      minHeight: 2,
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      valueColor: AlwaysStoppedAnimation<Color>(accent),
    );
  }
}

/// Barra compacta de reproducción mostrada sobre el contenido.
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Track? track = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.track),
    );
    final bool playing = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playing),
    );
    final PlayerController controller = ref.read(
      playerControllerProvider.notifier,
    );
    final CompactStyleConfig style = ref.watch(
      compactStyleProvider(CompactSurface.mini),
    );
    final ResolvedCompactStyle resolved = style.resolve(context.tokens);

    if (track == null) {
      return Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: CompactPanel(
            style: resolved,
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.music_off_rounded,
                  size: 20,
                  color: Colors.white54,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Sin reproducción activa',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
                TextButton(onPressed: onOpen, child: const Text('Abrir')),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: RepaintBoundary(
          child: CompactPanel(
            style: resolved,
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _MiniProgress(accent: resolved.progressColor),
                InkWell(
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                    child: Row(
                      children: <Widget>[
                        TrackArtwork(
                          key: ValueKey<int>(track.id),
                          path: track.artworkPath,
                          size: 44,
                          radius: resolved.artworkRadius(
                            resolved.radius * 0.55,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            key: ValueKey<int>(track.id),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: playing ? 'Pausar' : 'Reproducir',
                          onPressed: controller.togglePlay,
                          icon: Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: resolved.accent,
                            size: 28,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Siguiente',
                          onPressed: controller.next,
                          icon: const Icon(Icons.skip_next_rounded, size: 24),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
