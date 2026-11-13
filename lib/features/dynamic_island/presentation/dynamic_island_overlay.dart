import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/track_artwork.dart';
import '../../player/presentation/player_providers.dart';
import '../domain/dynamic_island_controller.dart';
import 'island_providers.dart';

/// Isla flotante con la pista actual.
///
/// Compacta por defecto: carátula, título y estado. Al tocarla se expande con
/// el progreso y controles rápidos. En Fase 1 vive dentro de la ventana; más
/// adelante puede convertirse en una ventana/notificación independiente.
class DynamicIslandOverlay extends ConsumerWidget {
  const DynamicIslandOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DynamicIslandState island = ref.watch(
      dynamicIslandControllerProvider,
    );
    if (!island.visible) return const SizedBox.shrink();

    final DynamicIslandController controller = ref.read(
      dynamicIslandControllerProvider.notifier,
    );
    final Track? track = island.track;
    final PolarisTokens tokens = context.tokens;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: GestureDetector(
          onTap: controller.toggleExpanded,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: island.expanded ? 420 : 320,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: tokens
                .panelDecoration(
                  radius: tokens.islandRadius,
                  glow: tokens.accent,
                )
                .copyWith(color: tokens.panelOverlay.withValues(alpha: 0.96)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (track != null)
                      TrackArtwork(
                        path: track.artworkPath,
                        size: 34,
                        radius: 10,
                      )
                    else
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: tokens.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.public_rounded,
                          size: 18,
                          color: tokens.accent,
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            island.message ?? track?.title ?? 'Polaris Music',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (island.message == null && track != null)
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white54,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (island.message == null && track != null) ...<Widget>[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: island.playing ? 'Pausar' : 'Reproducir',
                        onPressed: () => ref
                            .read(playerControllerProvider.notifier)
                            .togglePlay(),
                        icon: Icon(
                          island.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 22,
                          color: tokens.accent,
                        ),
                      ),
                      if (island.expanded)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Siguiente',
                          onPressed: () => ref
                              .read(playerControllerProvider.notifier)
                              .next(),
                          icon: const Icon(Icons.skip_next_rounded, size: 20),
                        ),
                    ],
                  ],
                ),
                if (island.expanded && track != null) ...<Widget>[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: island.progress,
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        Formatters.duration(island.position),
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white54,
                        ),
                      ),
                      Text(
                        Formatters.duration(island.duration),
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
