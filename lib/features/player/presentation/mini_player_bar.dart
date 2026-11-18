import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/polaris_surface.dart';
import '../../../shared/widgets/track_artwork.dart';
import '../domain/player_controller.dart';
import 'player_providers.dart';

/// Progreso aislado: es el único hijo de la mini barra que cambia con el tick
/// de posición, así que su reconstrucción no arrastra el `BackdropFilter`.
class _MiniProgress extends ConsumerWidget {
  const _MiniProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double progress = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.progress),
    );
    return LinearProgressIndicator(
      value: progress.clamp(0.0, 1.0),
      minHeight: 2,
      backgroundColor: Colors.white.withValues(alpha: 0.06),
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
    if (track == null) return const SizedBox.shrink();

    final bool playing = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playing),
    );
    final PlayerController controller = ref.read(
      playerControllerProvider.notifier,
    );
    final PolarisTokens tokens = context.tokens;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        // El blur del cristal se aísla: el progreso cambia 5 veces/s y no debe
        // obligar a repintar el BackdropFilter de toda la barra.
        child: RepaintBoundary(
          child: PolarisSurface(
            padding: EdgeInsets.zero,
            borderRadius: 16,
            blur: 20,
            glowColor: tokens.accent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _MiniProgress(),
                InkWell(
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                    child: Row(
                      children: <Widget>[
                        TrackArtwork(
                          path: track.artworkPath,
                          size: 44,
                          radius: 10,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
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
                            color: tokens.accent,
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
