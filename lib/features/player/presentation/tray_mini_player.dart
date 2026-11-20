import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/providers/compact_style_provider.dart';
import '../../../core/theme/color_math.dart';
import '../../../core/theme/compact_style_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/compact_surface.dart';
import '../../../shared/widgets/track_artwork.dart';
import '../domain/player_controller.dart';
import 'player_providers.dart';

/// Mini reproductor de bandeja.
///
/// Es la misma ventana en `WindowMode.mini`: compacta, siempre encima, sin
/// entrada en la barra de tareas y con el diseño guardado para esta superficie.
class TrayMiniPlayer extends ConsumerWidget {
  const TrayMiniPlayer({super.key, required this.onOpen, required this.onHide});

  final VoidCallback onOpen;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Track? track = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.track),
    );
    final bool playing = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playing),
    );
    final bool buffering = ref.watch(
      playerControllerProvider.select(
        (PlayerUiState s) => s.playback.buffering,
      ),
    );
    final double volume = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.volume),
    );
    final double progress = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.progress),
    );
    final PlayerController controller = ref.read(
      playerControllerProvider.notifier,
    );
    final CompactStyleConfig style = ref.watch(
      compactStyleProvider(CompactSurface.mini),
    );
    final ResolvedCompactStyle resolved = style.resolve(context.tokens);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: CompactPanel(
          style: resolved,
          padding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (progress > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 2.5,
                    backgroundColor: resolved.progressColor.withValues(
                      alpha: 0.12,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      resolved.progressColor,
                    ),
                  ),
                ),
              if (track == null)
                _EmptyState(
                  accent: resolved.accent,
                  onOpen: onOpen,
                  onHide: onHide,
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          TrackArtwork(
                            key: ValueKey<int>(track.id),
                            path: track.artworkPath,
                            size: 52,
                            radius: resolved.artworkRadius(
                              resolved.radius * 0.55,
                            ),
                          ),
                          const SizedBox(width: 10),
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
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: context.inkAlpha(0.60),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    _MiniButton(
                                      icon: Icons.skip_previous_rounded,
                                      tooltip: 'Anterior',
                                      onTap: controller.previous,
                                    ),
                                    SizedBox(
                                      width: 38,
                                      height: 38,
                                      child: FilledButton(
                                        onPressed: controller.togglePlay,
                                        style: FilledButton.styleFrom(
                                          shape: const CircleBorder(),
                                          padding: EdgeInsets.zero,
                                          backgroundColor: resolved.accent,
                                          foregroundColor: ColorMath.onColor(
                                            resolved.accent,
                                          ),
                                        ),
                                        child: buffering
                                            ? SizedBox(
                                                width: 15,
                                                height: 15,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: ColorMath.onColor(
                                                        resolved.accent,
                                                      ),
                                                    ),
                                              )
                                            : Icon(
                                                playing
                                                    ? Icons.pause_rounded
                                                    : Icons.play_arrow_rounded,
                                                size: 23,
                                              ),
                                      ),
                                    ),
                                    _MiniButton(
                                      icon: Icons.skip_next_rounded,
                                      tooltip: 'Siguiente',
                                      onTap: controller.next,
                                    ),
                                    const SizedBox(width: 4),
                                    _MiniButton(
                                      icon: Icons.open_in_full_rounded,
                                      tooltip: 'Abrir ventana principal',
                                      onTap: onOpen,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _MiniButton(
                            icon: Icons.close_rounded,
                            tooltip: 'Ocultar en la bandeja',
                            onTap: onHide,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          Icon(
                            volume <= 0
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            size: 15,
                            color: context.inkAlpha(0.54),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.5,
                                activeTrackColor: resolved.volumeColor,
                                thumbColor: resolved.volumeColor,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12,
                                ),
                              ),
                              child: Slider(
                                value: volume.clamp(0.0, 100.0).toDouble(),
                                max: 100,
                                onChanged: controller.setVolume,
                              ),
                            ),
                          ),
                          Text(
                            '${volume.round()}%',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.inkAlpha(0.38),
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
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.accent,
    required this.onOpen,
    required this.onHide,
  });

  final Color accent;
  final VoidCallback onOpen;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 10, 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.14),
                border: Border.all(color: accent.withValues(alpha: 0.45)),
              ),
              child: Icon(Icons.music_note_rounded, color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Polaris en espera',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Elige una canción desde la biblioteca',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: context.inkAlpha(0.60),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onOpen, child: Text('Abrir')),
            _MiniButton(
              icon: Icons.close_rounded,
              tooltip: 'Ocultar en la bandeja',
              onTap: onHide,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 17, color: context.inkAlpha(0.70)),
        ),
      ),
    );
  }
}
