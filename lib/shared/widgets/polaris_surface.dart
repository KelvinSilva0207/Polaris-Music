import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme_config.dart';
import '../../core/theme/theme_tokens.dart';

/// Contenedor adaptativo que respeta el [CardStyle] activo.
///
/// - `glassmorphic`: desenfoque real con [BackdropFilter] y borde translúcido.
/// - `neumorphic`: relieve 3D con sombras duales clara/oscura.
/// - `flatMinimal`: superficie limpia con borde fino.
class PolarisSurface extends StatelessWidget {
  const PolarisSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius,
    this.blur,
    this.glowColor,
    this.phase = 0,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? borderRadius;
  final double? blur;
  final Color? glowColor;

  /// Fase del gradiente orgánico del acabado Liquid (0..1).
  final double phase;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final double radius = borderRadius ?? tokens.panelRadius;
    final double sigma = blur ?? tokens.glassBlur;

    final Gradient? finishGradient = tokens.finishGradient(
      phase,
      base: tokens.panelColor,
    );

    // Mate: sin BackdropFilter ni gradientes. Superficie plana y nítida.
    if (tokens.isMatte) {
      return Container(
        padding: padding,
        decoration: tokens.panelDecoration(
          radius: radius,
          glow: glowColor,
          gradient: finishGradient,
        ),
        // El panel pinta un DecoratedBox con color. Sin un Material propio
        // debajo, los ListTile/SwitchListTile dibujan su tileColor y sus
        // splashes en un ancestro lejano y Flutter avisa de que quedan
        // ocultos. Transparency no pinta nada: solo da superficie de tinta.
        child: Material(type: MaterialType.transparency, child: child),
      );
    }

    // Líquido: blur acotado y gradiente orgánico, sin filtros apilados.
    final double effectiveSigma = tokens.isLiquid ? math.min(sigma, 16) : sigma;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: clipBehavior,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: effectiveSigma,
          sigmaY: effectiveSigma,
        ),
        child: Container(
          padding: padding,
          decoration: tokens.panelDecoration(
            radius: radius,
            glow: glowColor,
            gradient: finishGradient,
            phase: phase,
          ),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}
