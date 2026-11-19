// La isla se mueve con el puente "legacy" de window_manager, igual que la
// barra de título. El aviso de deprecación es intencional.
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/legacy.dart';

import '../../../core/models/track.dart';
import '../../../core/providers/compact_style_provider.dart';
import '../../../core/theme/compact_style_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/compact_surface.dart';
import '../../../shared/widgets/polaris_logo.dart';
import '../../../shared/widgets/track_artwork.dart';
import '../domain/dynamic_island_controller.dart';
import '../../player/domain/player_controller.dart';
import '../../player/presentation/player_providers.dart';
import 'island_providers.dart';

/// Cápsula flotante siempre encima.
///
/// El fondo de la ventana es transparente y el [CompactPanel] dibuja una
/// cápsula completa, evitando el rectángulo gris/negro que aparecía cuando el
/// tema global pintaba el área de la ventana. En Windows se arrastra desde el
/// área del título; al pasar el ratón crecen la carátula y los controles.
class IslandWindow extends ConsumerStatefulWidget {
  const IslandWindow({
    super.key,
    required this.onRestore,
    required this.onHide,
  });

  final VoidCallback onRestore;
  final VoidCallback onHide;

  @override
  ConsumerState<IslandWindow> createState() => _IslandWindowState();
}

class _IslandWindowState extends ConsumerState<IslandWindow> {
  bool _hovering = false;
  bool _dismissing = false;
  Timer? _hideTimer;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _scheduleAutoHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _dismissTimer?.cancel();
    super.dispose();
  }

  /// Contrae la cápsula antes de cerrar la ventana para que el cierre se lea
  /// como una transición y no como una desaparición brusca.
  void _requestHide() {
    if (_dismissing || !mounted) return;
    _hideTimer?.cancel();
    setState(() => _dismissing = true);
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) widget.onHide();
    });
  }

  void _scheduleAutoHide() {
    _hideTimer?.cancel();
    if (!mounted || _hovering || _dismissing) return;
    final CompactStyleConfig style = ref.read(
      compactStyleProvider(CompactSurface.island),
    );
    if (!style.autoHide) return;
    final int seconds = style.autoHideSeconds.clamp(2, 60).toInt();
    _hideTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted || _hovering || _dismissing) return;
      _requestHide();
    });
  }

  void _setHovering(bool value) {
    if (_dismissing || _hovering == value) return;
    setState(() => _hovering = value);
    if (value) {
      _hideTimer?.cancel();
    } else {
      _scheduleAutoHide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final CompactStyleConfig style = ref.watch(
      compactStyleProvider(CompactSurface.island),
    );
    ref.listen<CompactStyleConfig>(
      compactStyleProvider(CompactSurface.island),
      (CompactStyleConfig? previous, CompactStyleConfig next) {
        if (previous?.autoHide != next.autoHide ||
            previous?.autoHideSeconds != next.autoHideSeconds) {
          _scheduleAutoHide();
        }
      },
    );

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
    final DynamicIslandState island = ref.watch(
      dynamicIslandControllerProvider,
    );
    final bool expanded =
        _hovering || island.expanded || island.message != null;
    final String? message = island.message;
    final PolarisTokens tokens = context.tokens;
    final ResolvedCompactStyle resolved = style.resolve(tokens);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.82, end: 1),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double scale, Widget? child) {
            return Opacity(
              opacity: scale.clamp(0.0, 1.0),
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: AnimatedScale(
            scale: _dismissing ? 0.68 : 1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInCubic,
            child: AnimatedOpacity(
              opacity: _dismissing ? 0 : 1,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInCubic,
              child: MouseRegion(
                onEnter: (_) => _setHovering(true),
                onExit: (_) => _setHovering(false),
                child: _Capsule(
                  track: track,
                  playing: playing,
                  buffering: buffering,
                  position: position,
                  duration: duration,
                  progress: progress,
                  hovering: expanded,
                  message: message,
                  style: resolved,
                  controller: controller,
                  onRestore: widget.onRestore,
                  onHide: _requestHide,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Capsule extends StatelessWidget {
  const _Capsule({
    required this.track,
    required this.playing,
    required this.buffering,
    required this.position,
    required this.duration,
    required this.progress,
    required this.hovering,
    required this.message,
    required this.style,
    required this.controller,
    required this.onRestore,
    required this.onHide,
  });

  final Track? track;
  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;
  final double progress;
  final bool hovering;
  final String? message;
  final ResolvedCompactStyle style;
  final PlayerController controller;
  final VoidCallback onRestore;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final double artworkSize = hovering ? 68 : 44;
    return CompactPanel(
      style: style,
      padding: EdgeInsets.zero,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        width: hovering ? 376 : 196,
        height: hovering ? 104 : 64,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(style.radius),
          child: Stack(
            fit: StackFit.expand,
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
                  valueColor: AlwaysStoppedAnimation<Color>(style.accent),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  hovering ? 12 : 8,
                  hovering ? 12 : 10,
                  hovering ? 10 : 8,
                  hovering ? 14 : 12,
                ),
                child: Row(
                  children: <Widget>[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      width: artworkSize,
                      height: artworkSize,
                      child: track == null
                          ? PolarisLogo(size: artworkSize)
                          : TrackArtwork(
                              path: track!.artworkPath,
                              size: artworkSize,
                              radius: style.radius * 0.42,
                            ),
                    ),
                    SizedBox(width: hovering ? 12 : 8),
                    Expanded(
                      child: _draggable(
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          child: hovering
                              ? _ExpandedInfo(
                                  key: const ValueKey<String>('expanded'),
                                  track: track,
                                  message: message,
                                  position: position,
                                  duration: duration,
                                  playing: playing,
                                )
                              : _CompactInfo(
                                  key: const ValueKey<String>('compact'),
                                  track: track,
                                ),
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      transitionBuilder: (
                        Widget child,
                        Animation<double> animation,
                      ) => FadeTransition(opacity: animation, child: child),
                      child: hovering
                          ? _Controls(
                              key: const ValueKey<String>('controls'),
                              playing: playing,
                              buffering: buffering,
                              accent: style.accent,
                              controller: controller,
                              onRestore: onRestore,
                              onHide: onHide,
                            )
                          : _Action(
                              key: const ValueKey<String>('hide'),
                              tooltip: 'Ocultar isla',
                              icon: Icons.visibility_off_rounded,
                              color: Colors.white54,
                              onTap: onHide,
                            ),
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

  Widget _draggable(Widget child) =>
      Platform.isWindows ? DragToMoveArea(child: child) : child;
}

class _CompactInfo extends StatelessWidget {
  const _CompactInfo({super.key, required this.track});

  final Track? track;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          track?.title ?? 'Polaris Music',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          track?.artist ?? 'Nada en reproducción',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: Colors.white60),
        ),
        if (track == null)
          Text(
            'Pasa el ratón para ver controles',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 8.5, color: Colors.white38),
          ),
      ],
    );
  }
}

class _ExpandedInfo extends StatelessWidget {
  const _ExpandedInfo({
    super.key,
    required this.track,
    required this.message,
    required this.position,
    required this.duration,
    required this.playing,
  });

  final Track? track;
  final String? message;
  final Duration position;
  final Duration duration;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final String title = message ?? track?.title ?? 'Polaris Music';
    final String subtitle = message != null
        ? 'Aviso de Polaris'
        : (track?.artist ?? 'Elige una canción para empezar');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Colors.white60),
        ),
        if (message == null) ...<Widget>[
          const SizedBox(height: 5),
          Text(
            '${Formatters.duration(position)} / ${Formatters.duration(duration)}'
            '${playing ? '  ·  En reproducción' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: Colors.white38),
          ),
        ],
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    super.key,
    required this.playing,
    required this.buffering,
    required this.accent,
    required this.controller,
    required this.onRestore,
    required this.onHide,
  });

  final bool playing;
  final bool buffering;
  final Color accent;
  final PlayerController controller;
  final VoidCallback onRestore;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
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
          color: accent,
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
        _Action(
          tooltip: 'Ocultar isla',
          icon: Icons.visibility_off_rounded,
          color: Colors.white54,
          onTap: onHide,
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    super.key,
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
