import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/providers/motion_provider.dart';

/// Insignia discreta de «pista en reproducción».
///
/// Tres barras que solo se animan cuando la pista está activa **y** sonando:
/// al pausar el controlador se detiene y dibuja tres barras quietas, sin
/// dejar un ticker corriendo. El color viene del acento RGB/HSL activo.
class PlayingIndicator extends ConsumerStatefulWidget {
  const PlayingIndicator({
    super.key,
    required this.active,
    required this.playing,
    required this.color,
    this.size = 17,
  });

  final bool active;
  final bool playing;
  final Color color;
  final double size;

  @override
  ConsumerState<PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends ConsumerState<PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    ref.listen(windowStateProvider, (_, _) => _sync());
    ref.listen(motionConfigProvider, (_, _) => _sync());
    _sync();
  }

  @override
  void didUpdateWidget(covariant PlayingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    // Además de pausar/estar inactiva, se detiene cuando la ventana pasa a
    // segundo plano: la música sigue, pero no hay ticks de UI innecesarios.
    final bool backgrounded = ref.read(windowStateProvider).value.backgrounded;
    final bool ambient = ref.read(motionConfigProvider).ambient;
    if (widget.active && widget.playing && ambient && !backgrounded) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? _) => Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: widget.color.withValues(alpha: 0.45)),
          ),
          child: CustomPaint(
            painter: _PlayingBarsPainter(
              phase: _controller.value,
              color: widget.color,
              animate: _controller.isAnimating,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayingBarsPainter extends CustomPainter {
  const _PlayingBarsPainter({
    required this.phase,
    required this.color,
    required this.animate,
  });

  final double phase;
  final Color color;
  final bool animate;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 3; i++) {
      final double wave = animate
          ? 0.5 + 0.5 * math.sin((phase * 2 * math.pi) + i * 1.9)
          : 0.55;
      final double height = size.height * (0.24 + 0.42 * wave);
      final double x = size.width * (0.28 + i * 0.22);
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PlayingBarsPainter old) =>
      old.phase != phase || old.color != color || old.animate != animate;
}
