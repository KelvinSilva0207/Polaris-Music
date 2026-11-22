import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/motion_config.dart';
import '../../core/theme/theme_tokens.dart';
import 'motion_scope.dart';

/// Botón de transporte con respuesta táctil breve y legible.
///
/// Al pulsarse se comprime y vuelve con un rebote suave; un anillo de eco
/// confirma la acción. El [IconButton] se entrega como `child` del
/// [AnimatedBuilder], así que no se reconstruye en cada frame y el único coste
/// por frame es un `Transform.scale` y un trazo de círculo.
class TactileIconButton extends StatefulWidget {
  const TactileIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.iconSize = 24,
    this.echoColor,
    this.enabled = true,
    this.haptic = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? color;
  final double iconSize;
  final Color? echoColor;
  final bool enabled;

  /// Vibración mínima en controles de transporte; desactivada en ajustes.
  final bool haptic;

  @override
  State<TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<TactileIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _scale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 0.84,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 32,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.84,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 68,
      ),
    ]).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Duration duration = context.motion.duration(
      const Duration(milliseconds: 260),
      category: MotionCategory.gestures,
    );
    _controller.duration = duration == Duration.zero
        ? const Duration(microseconds: 1)
        : duration;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePressed() {
    if (!widget.enabled) return;
    if (context.motionAllowed(MotionCategory.gestures)) {
      _controller.forward(from: 0);
    }
    if (widget.haptic) unawaited(HapticFeedback.lightImpact());
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.echoColor ?? context.accent;
    final double intensity = context.motion.intensity;
    final Widget button = Semantics(
      label: widget.tooltip,
      button: true,
      enabled: widget.enabled,
      child: IconButton(
        tooltip: widget.tooltip,
        iconSize: widget.iconSize,
        onPressed: widget.enabled ? _handlePressed : null,
        icon: Icon(
          widget.icon,
          color:
              widget.color ?? (widget.enabled ? null : context.inkAlpha(0.24)),
        ),
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
                  painter: _EchoPainter(
                    progress: progress,
                    color: accent,
                    intensity: intensity,
                  ),
                  child: const SizedBox(width: 48, height: 48),
                ),
              ),
            Transform.scale(scale: _scale.value, child: child),
          ],
        );
      },
    );
  }
}

/// Eco circular que se expande y se desvanece en el instante de la pulsación.
class _EchoPainter extends CustomPainter {
  const _EchoPainter({
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
    final double alpha = (1 - eased).clamp(0.0, 1.0).toDouble();
    final Offset center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      10 + (8 + 12 * intensity) * eased,
      Paint()
        ..color = color.withValues(alpha: alpha * (0.16 + 0.36 * intensity))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _EchoPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.intensity != intensity;
}
