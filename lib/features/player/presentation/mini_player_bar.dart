import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/providers/compact_style_provider.dart';
import '../../../core/theme/compact_style_config.dart';
import '../../../core/theme/motion_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/compact_surface.dart';
import '../../../shared/widgets/motion_scope.dart';
import '../../../shared/widgets/track_artwork.dart';
import '../domain/player_controller.dart';
import 'player_providers.dart';

/// Progreso fluido con tiempos a los lados.
///
/// Se aísla del resto de la tarjeta: el tick de posición (~5 Hz) y la fase de
/// la onda solo reconstruyen este widget, sin arrastrar el `BackdropFilter`.
class _MiniProgress extends ConsumerStatefulWidget {
  const _MiniProgress({required this.accent, required this.playing});

  final Color accent;
  final bool playing;

  @override
  ConsumerState<_MiniProgress> createState() => _MiniProgressState();
}

class _MiniProgressState extends ConsumerState<_MiniProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool _ambientAllowed = true;

  @override
  void initState() {
    super.initState();
    _wave.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ambientAllowed = context.motionAllowed(MotionCategory.ambient);
    final Duration duration = context.motion.duration(
      const Duration(milliseconds: 1600),
      category: MotionCategory.ambient,
    );
    _wave.duration = duration == Duration.zero
        ? const Duration(milliseconds: 1)
        : duration;
    _sync();
  }

  @override
  void didUpdateWidget(covariant _MiniProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) _sync();
  }

  void _sync() {
    if (_ambientAllowed && widget.playing) {
      if (!_wave.isAnimating) _wave.repeat();
    } else {
      _wave.stop();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Duration position = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.position),
    );
    final Duration duration = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.duration),
    );
    final double progress = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.progress),
    );
    final TextStyle timeStyle = TextStyle(
      fontSize: 9.5,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      color: context.inkAlpha(0.52),
    );

    return Row(
      children: <Widget>[
        Text(Formatters.duration(position), style: timeStyle),
        const SizedBox(width: 7),
        Expanded(
          child: SizedBox(
            height: 10,
            child: CustomPaint(
              painter: _WaveProgressPainter(
                wave: _wave,
                phase: _wave.value,
                progress: progress.clamp(0.0, 1.0),
                fill: widget.accent,
                track: context.inkAlpha(0.08),
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(Formatters.duration(duration), style: timeStyle),
      ],
    );
  }
}

/// Indicador compacto de reproducción sobre la carátula.
class _PlayingBars extends StatefulWidget {
  const _PlayingBars({required this.active, required this.accent});

  final bool active;
  final Color accent;

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool _allowed = true;

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _allowed = context.motionAllowed(MotionCategory.ambient);
    final Duration duration = context.motion.duration(
      const Duration(milliseconds: 900),
      category: MotionCategory.ambient,
    );
    _controller.duration = duration == Duration.zero
        ? const Duration(milliseconds: 1)
        : duration;
    _sync();
  }

  @override
  void didUpdateWidget(covariant _PlayingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  void _sync() {
    if (_allowed && widget.active) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = widget.active ? 0.5 : 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.active ? widget.accent : context.inkAlpha(0.38);
    return AnimatedBuilder(
      animation: _controller,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(width: 2, height: 5, color: color),
            const SizedBox(width: 2),
            Container(width: 2, height: 9, color: color),
            const SizedBox(width: 2),
            Container(width: 2, height: 6, color: color),
          ],
        ),
      ),
      builder: (BuildContext context, Widget? child) {
        if (!widget.active) return child ?? const SizedBox.shrink();
        final double phase = _controller.value;
        return Transform.scale(
          scaleY: 0.85 + 0.25 * math.sin(phase * math.pi * 2),
          child: child,
        );
      },
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
    final bool buffering = ref.watch(
      playerControllerProvider.select(
        (PlayerUiState s) => s.playback.buffering,
      ),
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
                Icon(
                  Icons.music_off_rounded,
                  size: 20,
                  color: context.inkAlpha(0.54),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sin reproducción activa',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.inkAlpha(0.70),
                    ),
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
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool roomy = constraints.maxWidth >= 430;
              return CompactPanel(
                style: resolved,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _MiniProgress(
                      accent: resolved.progressColor,
                      playing: playing,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        InkWell(
                          onTap: onOpen,
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              TrackArtwork(
                                key: ValueKey<int>(track.id),
                                path: track.artworkPath,
                                size: 46,
                                radius: resolved.artworkRadius(11),
                              ),
                              Positioned(
                                right: -3,
                                bottom: -3,
                                child: _PlayingBars(
                                  active: playing && !buffering,
                                  accent: resolved.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: InkWell(
                            onTap: onOpen,
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
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.inkAlpha(0.54),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (roomy)
                              IconButton(
                                tooltip: 'Anterior',
                                onPressed: controller.previous,
                                icon: const Icon(
                                  Icons.skip_previous_rounded,
                                  size: 21,
                                ),
                              ),
                            _MiniPlayButton(
                              buffering: buffering,
                              playing: playing,
                              accent: resolved.accent,
                              onPressed: controller.togglePlay,
                            ),
                            IconButton(
                              tooltip: 'Siguiente',
                              onPressed: controller.next,
                              icon: const Icon(
                                Icons.skip_next_rounded,
                                size: 21,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MiniPlayButton extends StatelessWidget {
  const _MiniPlayButton({
    required this.buffering,
    required this.playing,
    required this.accent,
    required this.onPressed,
  });

  final bool buffering;
  final bool playing;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: buffering ? 'Cargando' : (playing ? 'Pausar' : 'Reproducir'),
      child: Material(
        color: accent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: buffering
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: accent,
                        backgroundColor: accent.withValues(alpha: 0.25),
                      ),
                    )
                  : Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: accent.computeLuminance() > 0.5
                          ? Colors.black87
                          : Colors.white,
                      size: 23,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Onda de progreso: la pista avanza con un frente ligeramente ondulado.
class _WaveProgressPainter extends CustomPainter {
  _WaveProgressPainter({
    required Listenable wave,
    required this.phase,
    required this.progress,
    required this.fill,
    required this.track,
  }) : super(repaint: wave);

  final double phase;
  final double progress;
  final Color fill;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(rect, Paint()..color = track);
    if (progress <= 0) return;

    final double width = size.width * progress;
    final double mid = size.height / 2;
    final double amplitude = math.min<double>(1.6, size.height * 0.16);
    final Path wave = Path()..moveTo(0, mid);
    for (double x = 0; x <= width; x += 2) {
      final double t = x / math.max<double>(width, 1);
      final double y =
          mid +
          math.sin(t * math.pi * 5 + phase * math.pi * 2) * amplitude * (1 - t);
      wave.lineTo(x, y);
    }
    wave
      ..lineTo(width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.save();
    canvas.clipRRect(rect);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, size.height),
      Paint()..color = fill.withValues(alpha: 0.24),
    );
    canvas.drawPath(wave, Paint()..color = fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WaveProgressPainter old) =>
      old.phase != phase ||
      old.progress != progress ||
      old.fill != fill ||
      old.track != track;
}
