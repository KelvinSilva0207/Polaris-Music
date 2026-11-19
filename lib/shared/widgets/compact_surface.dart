import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/compact_style_config.dart';

/// Contenedor flotante que respeta el estilo guardado de una superficie
/// compacta, sin depender de los tokens globales.
///
/// Se usa en la isla, el mini-reproductor y el modo teléfono para que cada uno
/// pueda tener color, radio, desenfoque y sombras distintos.
class CompactPanel extends StatelessWidget {
  const CompactPanel({
    super.key,
    required this.style,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final ResolvedCompactStyle style;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final double alpha = style.opacity.clamp(0.35, 1.0);
    final Color fill =
        Color.lerp(style.background, style.accent, 0.08) ?? style.background;
    final BorderRadius radius = BorderRadius.circular(style.radius);

    final BoxDecoration decoration = switch (style.tokens.cardStyle) {
      CardStyle.glassmorphic => BoxDecoration(
        color: fill.withValues(alpha: alpha),
        borderRadius: radius,
        border: Border.all(color: style.accent.withValues(alpha: 0.28)),
        boxShadow: style.glow
            ? <BoxShadow>[
                BoxShadow(
                  color: style.accent.withValues(alpha: 0.22),
                  blurRadius: 26,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.36),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      CardStyle.neumorphic => BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(-5, -5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.48),
            blurRadius: 18,
            offset: const Offset(6, 7),
          ),
        ],
      ),
      CardStyle.flatMinimal => BoxDecoration(
        color: fill.withValues(alpha: alpha),
        borderRadius: radius,
        border: Border.all(color: style.accent.withValues(alpha: 0.16)),
        boxShadow: style.glow
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
    };

    final Widget decorated = DecoratedBox(
      decoration: decoration,
      child: Padding(padding: padding, child: child),
    );

    if (style.tokens.cardStyle != CardStyle.glassmorphic || style.blur <= 0) {
      return ClipRRect(borderRadius: radius, child: decorated);
    }

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: style.blur, sigmaY: style.blur),
        child: decorated,
      ),
    );
  }
}
