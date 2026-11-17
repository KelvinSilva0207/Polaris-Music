import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/track_artwork.dart';
import '../domain/player_controller.dart';
import 'player_providers.dart';

/// Mini reproductor de bandeja (estilo MusicBee).
///
/// Es la misma ventana en [WindowMode.mini]: compacta, siempre encima, sin
/// entrada en la barra de tareas y con lo esencial para controlar la música.
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
    final PolarisTokens tokens = context.tokens;
    final Color accent = tokens.accent;

    if (track == null) {
      return _Shell(
        tokens: tokens,
        accent: accent,
        onOpen: onOpen,
        onHide: onHide,
        child: const Center(
          child: Text(
            'Sin reproducción',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ),
      );
    }

    return _Shell(
      tokens: tokens,
      accent: accent,
      onOpen: onOpen,
      onHide: onHide,
      progress: progress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                TrackArtwork(path: track.artworkPath, size: 52, radius: 12),
                const SizedBox(width: 10),
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
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.white60,
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
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                              ),
                              child: buffering
                                  ? const SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
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
                  color: Colors.white54,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
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
                  style: const TextStyle(fontSize: 10, color: Colors.white38),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.tokens,
    required this.accent,
    required this.onOpen,
    required this.onHide,
    required this.child,
    this.progress = 0,
  });

  final PolarisTokens tokens;
  final Color accent;
  final VoidCallback onOpen;
  final VoidCallback onHide;
  final Widget child;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.background,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color.lerp(tokens.background, accent, 0.20) ?? tokens.background,
              tokens.background,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.panelBorder),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.22),
              blurRadius: 22,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 2.5,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              child,
            ],
          ),
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
          child: Icon(icon, size: 17, color: Colors.white70),
        ),
      ),
    );
  }
}
