import 'package:flutter/material.dart';

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
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? color;
  final double iconSize;
  final Color? echoColor;
  final bool enabled;

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
    if (context.motion.gestures) _controller.forward(from: 0);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.echoColor ?? context.accent;
    final Widget button = IconButton(
      tooltip: widget.tooltip,
      iconSize: widget.iconSize,
      onPressed: widget.enabled ? _handlePressed : null,
      icon: Icon(
        widget.icon,
        color: widget.color ?? (widget.enabled ? null : context.inkAlpha(0.24)),
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
                  painter: _EchoPainter(progress: progress, color: accent),
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
  const _EchoPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double eased = Curves.easeOutCubic.transform(progress);
    final double alpha = (1 - eased).clamp(0.0, 1.0).toDouble();
    final Offset center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      10 + 14 * eased,
      Paint()
        ..color = color.withValues(alpha: alpha * 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _EchoPainter old) =>
      old.progress != progress || old.color != color;
}
