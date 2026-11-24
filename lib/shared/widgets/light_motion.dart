import 'package:flutter/material.dart';

import '../../core/theme/motion_config.dart';
import 'motion_scope.dart';

/// Puente de presentación para animaciones ligeras.
///
/// Animaciones un solo valor `double` con `Transform`/`Opacity` (compositor),
/// sin tocar el layout ni la lógica de negocio. Cuando el perfil desactiva la
/// categoría —o el modo puro está activo— se aplica el valor final **sin crear
/// controladores de animación**, así que no quedan ticks ocultos.
class MotionValue extends StatefulWidget {
  const MotionValue({
    required this.value,
    required this.builder,
    super.key,
    this.category = MotionCategory.gestures,
    this.duration = const Duration(milliseconds: 180),
    this.curve = Curves.easeOutCubic,
  });

  final double value;
  final Widget Function(BuildContext context, double value) builder;
  final MotionCategory category;
  final Duration duration;
  final Curve curve;

  @override
  State<MotionValue> createState() => _MotionValueState();
}

class _MotionValueState extends State<MotionValue> {
  /// Valor anterior como punto de partida: evita el salto de `0 -> destino`
  /// cada vez que cambia el objetivo mientras la animación aún corre.
  late double _from = widget.value;

  @override
  void didUpdateWidget(covariant MotionValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _from = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    final Duration resolved = context.motion.duration(
      widget.duration,
      category: widget.category,
    );
    if (resolved == Duration.zero || !context.motionAllowed(widget.category)) {
      return widget.builder(context, widget.value);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _from, end: widget.value),
      duration: resolved,
      curve: widget.curve,
      builder: (BuildContext context, double value, Widget? child) =>
          widget.builder(context, value),
    );
  }
}

/// Escala animada sin reconstruir el hijo ni modificar el layout.
class MotionScale extends StatelessWidget {
  const MotionScale({
    required this.scale,
    required this.child,
    super.key,
    this.category = MotionCategory.gestures,
    this.duration = const Duration(milliseconds: 180),
    this.curve = Curves.easeOutCubic,
    this.alignment = Alignment.center,
  });

  final double scale;
  final Widget child;
  final MotionCategory category;
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return MotionValue(
      value: scale,
      category: category,
      duration: duration,
      curve: curve,
      builder: (BuildContext context, double value) =>
          Transform.scale(scale: value, alignment: alignment, child: child),
    );
  }
}

/// Opacidad animada, siempre limitada al rango válido `0..1`.
class MotionFade extends StatelessWidget {
  const MotionFade({
    required this.opacity,
    required this.child,
    super.key,
    this.category = MotionCategory.gestures,
    this.duration = const Duration(milliseconds: 180),
    this.curve = Curves.easeOutCubic,
  });

  final double opacity;
  final Widget child;
  final MotionCategory category;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return MotionValue(
      value: opacity.clamp(0.0, 1.0),
      category: category,
      duration: duration,
      curve: curve,
      builder: (BuildContext context, double value) =>
          Opacity(opacity: value.clamp(0.0, 1.0), child: child),
    );
  }
}

/// Aísla un `CustomPainter` en su propia capa de repintado.
///
/// El painter sigue siendo el responsible de declarar `shouldRepaint`; este
/// envoltorio solo garantiza que sus frames no invaliden al resto del árbol.
class MotionPaint extends StatelessWidget {
  const MotionPaint({
    required this.painter,
    super.key,
    this.foregroundPainter,
    this.size = Size.zero,
    this.child,
  });

  final CustomPainter? painter;
  final CustomPainter? foregroundPainter;
  final Size size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: painter,
        foregroundPainter: foregroundPainter,
        size: size,
        child: child,
      ),
    );
  }
}
