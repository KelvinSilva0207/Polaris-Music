// La isla se mueve con el puente "legacy" de window_manager, igual que la
// barra de título. El aviso de deprecación es intencional.
// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/legacy.dart';

import '../../../core/models/track.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/polaris_logo.dart';
import '../../../shared/widgets/track_artwork.dart';
import '../../player/domain/player_controller.dart';
import '../../player/presentation/player_providers.dart';

/// Interfaz de la ventana isla: la misma ventana de la app transformada en un
/// elemento flotante Always-on-Top al minimizar o al elegir el modo compacto.
///
/// Muestra carátula, título, tiempo y controles básicos. Se arrastra desde el
/// área del título y un botón devuelve la ventana a su tamaño normal.
class IslandWindow extends ConsumerWidget {
  const IslandWindow({super.key, required this.onRestore});

  final VoidCallback onRestore;

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
    final Duration position = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.position),
    );
    final Duration duration = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.duration),
    );
    final double progress = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.progress),
    );
    final PlayerController controller = ref.read(
      playerControllerProvider.notifier,
    );
    final PolarisTokens tokens = context.tokens;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.86, end: 1),
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double scale, Widget? child) {
            return Opacity(
              opacity: scale.clamp(0.0, 1.0),
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: _Card(
            track: track,
            playing: playing,
            buffering: buffering,
            position: position,
            duration: duration,
            progress: progress,
            tokens: tokens,
            controller: controller,
            onRestore: onRestore,
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.track,
    required this.playing,
    required this.buffering,
    required this.position,
    required this.duration,
    required this.progress,
    required this.tokens,
    required this.controller,
    required this.onRestore,
  });

  final Track? track;
  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;
  final double progress;
  final PolarisTokens tokens;
  final PlayerController controller;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 384,
      height: 116,
      decoration: tokens
          .panelDecoration(radius: 30, glow: tokens.accent)
          .copyWith(color: tokens.panelOverlay.withValues(alpha: 0.94)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
                valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 14),
              child: Row(
                children: <Widget>[
                  if (track != null)
                    TrackArtwork(path: track!.artworkPath, size: 66, radius: 14)
                  else
                    PolarisLogo(size: 66),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _draggable(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            track?.title ?? 'Polaris Music',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            track?.artist ?? 'Nada en reproducción',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${Formatters.duration(position)} / '
                            '${Formatters.duration(duration)}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _Action(
                    tooltip: 'Anterior',
                    icon: Icons.skip_previous_rounded,
                    color: Colors.white70,
                    onTap: controller.previous,
                  ),
                  _Action(
                    tooltip: playing ? 'Pausar' : 'Reproducir',
                    icon: buffering
                        ? Icons.hourglass_top_rounded
                        : playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: tokens.accent,
                    onTap: controller.togglePlay,
                  ),
                  _Action(
                    tooltip: 'Siguiente',
                    icon: Icons.skip_next_rounded,
                    color: Colors.white70,
                    onTap: controller.next,
                  ),
                  _Action(
                    tooltip: 'Abrir ventana principal',
                    icon: Icons.open_in_full_rounded,
                    color: Colors.white54,
                    onTap: onRestore,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _draggable(Widget child) =>
      Platform.isWindows ? DragToMoveArea(child: child) : child;
}

class _Action extends StatelessWidget {
  const _Action({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
