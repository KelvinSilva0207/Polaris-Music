import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/track_artwork.dart';
import '../domain/player_controller.dart';
import 'player_providers.dart';

/// Barra compacta de reproducción mostrada sobre el contenido.
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayerUiState ui = ref.watch(playerControllerProvider);
    final Track? track = ui.track;
    if (track == null) return const SizedBox.shrink();

    final PlayerController controller = ref.read(
      playerControllerProvider.notifier,
    );
    final PolarisTokens tokens = context.tokens;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1428),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            LinearProgressIndicator(
              value: ui.playback.duration.inMilliseconds == 0
                  ? 0
                  : ui.playback.progress,
              minHeight: 2,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
            ),
            InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                child: Row(
                  children: <Widget>[
                    TrackArtwork(path: track.artworkPath, size: 44, radius: 10),
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
                      tooltip: ui.playing ? 'Pausar' : 'Reproducir',
                      onPressed: controller.togglePlay,
                      icon: Icon(
                        ui.playing
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
    );
  }
}
