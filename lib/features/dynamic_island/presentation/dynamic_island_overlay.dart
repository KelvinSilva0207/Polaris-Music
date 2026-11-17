import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/polaris_logo.dart';
import '../../../shared/widgets/track_artwork.dart';
import '../../player/presentation/player_providers.dart';
import '../domain/dynamic_island_controller.dart';
import 'island_providers.dart';

/// Isla flotante con la pista actual.
///
/// Compacta por defecto —carátula, título y estado— y se convierte en una
/// barra flotante cuando la ventana se estrecha. Al tocarla se expande con el
/// progreso y controles rápidos.
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

    final double windowWidth = MediaQuery.sizeOf(context).width;
    if (windowWidth < 360) return const SizedBox.shrink();

    // Barra compacta en ventanas estrechas; tarjeta en ventanas amplias.
    final bool narrow = windowWidth < 640;
    final double width = math.min(
      island.expanded ? 420 : (narrow ? 300 : 330),
      math.max(windowWidth - 24, 220),
    );
    final bool showProgress = island.expanded && track != null;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: narrow ? 8 : 12),
        child: GestureDetector(
          onTap: controller.toggleExpanded,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: width,
            padding: EdgeInsets.fromLTRB(
              narrow ? 10 : 12,
              narrow ? 8 : 10,
              narrow ? 8 : 12,
              narrow ? 8 : 10,
            ),
            decoration: tokens
                .panelDecoration(
                  radius: narrow ? 22 : tokens.islandRadius,
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
                        size: narrow ? 28 : 34,
                        radius: narrow ? 8 : 10,
                      )
                    else
                      PolarisLogo(size: narrow ? 28 : 34, radius: 8),
                    SizedBox(width: narrow ? 8 : 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            island.message ?? track?.title ?? 'Polaris Music',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: narrow ? 11 : 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (island.message == null && track != null)
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: narrow ? 9 : 10,
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
                          size: narrow ? 19 : 22,
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
                          icon: Icon(
                            Icons.skip_next_rounded,
                            size: narrow ? 17 : 20,
                          ),
                        ),
                    ],
                  ],
                ),
                if (showProgress) ...<Widget>[
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
