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
    this.blur = 26,
    this.glowColor,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? borderRadius;
  final double blur;
  final Color? glowColor;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final double radius = borderRadius ?? tokens.panelRadius;

    switch (tokens.cardStyle) {
      case CardStyle.glassmorphic:
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: clipBehavior,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              padding: padding,
              decoration: tokens.panelDecoration(
                radius: radius,
                glow: glowColor,
              ),
              child: child,
            ),
          ),
        );

      case CardStyle.neumorphic:
        return Container(
          padding: padding,
          decoration: tokens.panelDecoration(radius: radius, glow: glowColor),
          child: child,
        );

      case CardStyle.flatMinimal:
        return Container(
          padding: padding,
          decoration: tokens.panelDecoration(radius: radius, glow: glowColor),
          child: child,
        );
    }
  }
}
