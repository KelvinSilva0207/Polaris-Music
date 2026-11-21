import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/motion_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/motion_scope.dart';

/// Botón de favorito con un latido y una pequeña explosión de partículas.
///
/// Solo se dispara al **añadir** a favoritos, que es el momento en el que el
/// usuario necesita confirmación. El icono se mantiene como `child` de
/// [AnimatedBuilder], así que no se reconstruye en cada frame.
class AnimatedFavoriteButton extends StatefulWidget {
  const AnimatedFavoriteButton({
    super.key,
    required this.isFavorite,
    required this.enabled,
    required this.accent,
    required this.onPressed,
    required this.tooltip,
  });

  final bool isFavorite;
  final bool enabled;
  final Color accent;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  State<AnimatedFavoriteButton> createState() => _AnimatedFavoriteButtonState();
}

class _AnimatedFavoriteButtonState extends State<AnimatedFavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _scale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 1.34,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.34,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
    ]).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Duration duration = context.motion.duration(
      const Duration(milliseconds: 460),
      category: MotionCategory.gestures,
    );
    _controller.duration = duration == Duration.zero
        ? const Duration(microseconds: 1)
        : duration;
  }

  @override
  void didUpdateWidget(covariant AnimatedFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isFavorite &&
        widget.isFavorite &&
        context.motionAllowed(MotionCategory.gestures)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final IconButton button = IconButton(
      tooltip: widget.tooltip,
      iconSize: 26,
      onPressed: widget.enabled ? widget.onPressed : null,
      icon: Icon(
        widget.isFavorite
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        color: !widget.enabled
            ? context.inkAlpha(0.24)
            : widget.isFavorite
            ? widget.accent
            : context.inkAlpha(0.54),
      ),
    );

    return AnimatedBuilder(
      animation: _controller,
      child: button,
      builder: (BuildContext context, Widget? child) {
        final double progress = _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            if (progress > 0 && progress < 1)
              IgnorePointer(
                child: CustomPaint(
                  painter: _FavoriteBurstPainter(
                    progress: progress,
                    color: widget.accent,
                    intensity: context.motion.intensity,
                  ),
                  child: const SizedBox(width: 44, height: 44),
                ),
              ),
            Transform.scale(scale: _scale.value, child: child),
          ],
        );
      },
    );
  }
}

class _FavoriteBurstPainter extends CustomPainter {
  const _FavoriteBurstPainter({
    required this.progress,
    required this.color,
    required this.intensity,
  });

  final double progress;
  final Color color;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final double eased = Curves.easeOutCubic.transform(progress);
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double alpha = (1 - eased).clamp(0.0, 1.0).toDouble();

    canvas.drawCircle(
      center,
      12 + (6 + 20 * intensity) * eased,
      Paint()
        ..color = color.withValues(alpha: alpha * (0.20 + 0.45 * intensity))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    for (int i = 0; i < 6; i++) {
      final double angle = (i * math.pi / 3) + 0.35;
      final double radius = 12 + 18 * eased;
      final Offset point =
          center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(
        point,
        2.6 * alpha + 0.6,
        Paint()..color = color.withValues(alpha: alpha * 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FavoriteBurstPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.intensity != intensity;
}
