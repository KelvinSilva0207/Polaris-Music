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
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? borderRadius;
  final double? blur;
  final Color? glowColor;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final double radius = borderRadius ?? tokens.panelRadius;
    final double sigma = blur ?? tokens.glassBlur;

    // Mate: sin BackdropFilter. Es el acabado recomendado en listas largas.
    if (tokens.finish == SurfaceFinish.matte) {
      return Container(
        padding: padding,
        decoration: tokens.panelDecoration(radius: radius, glow: glowColor),
        child: child,
      );
    }

    // Líquido: blur acotado y gradiente orgánico, sin filtros apilados.
    final double effectiveSigma = tokens.finish == SurfaceFinish.liquid
        ? math.min(sigma, 16)
        : sigma;
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
          decoration: tokens.panelDecoration(radius: radius, glow: glowColor),
          child: child,
        ),
      ),
    );
  }
}
