import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme_config.dart';
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

    final bool matte = style.tokens.finish == SurfaceFinish.matte;
    final DesignLanguage language = style.tokens.designLanguage;
    final Border? outline = language.borderWidth == 0
        ? null
        : Border.all(
            color: style.accent.withValues(
              alpha: language.glowEdge ? 0.30 : 0.18,
            ),
            width: language.borderWidth,
          );
    final BoxDecoration surface = switch (style.tokens.finish) {
      SurfaceFinish.matte => BoxDecoration(
        color: fill.withValues(alpha: alpha),
        borderRadius: radius,
        border: outline,
      ),
      SurfaceFinish.liquid => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(fill, style.accent, 0.16) ?? fill,
            Color.lerp(fill, style.tokens.secondary, 0.18) ?? fill,
          ],
        ),
        borderRadius: radius,
        border: outline,
      ),
      SurfaceFinish.glass => BoxDecoration(
        color: fill.withValues(alpha: alpha),
        borderRadius: radius,
        border: outline,
      ),
    };

    // Sombra y recorte comparten el mismo radio, pero la sombra se pinta en un
    // DecoratedBox exterior: si el ClipRRect envolviera al DecoratedBox con
    // boxShadow, recortaría el resplandor y dejaría solo el marco flotante.
    final List<BoxShadow>? shadows = language.raisedTile
        ? <BoxShadow>[
            BoxShadow(
              color: style.tokens.neumorphicLight.withValues(alpha: 0.85),
              blurRadius: 12,
              offset: const Offset(-3, -3),
            ),
            BoxShadow(
              color: style.tokens.neumorphicDark.withValues(alpha: 0.75),
              blurRadius: 16,
              offset: const Offset(4, 5),
            ),
          ]
        : switch (style.tokens.finish) {
            SurfaceFinish.matte => null,
            SurfaceFinish.liquid =>
              style.glow
                  ? <BoxShadow>[
                      BoxShadow(
                        color: style.accent.withValues(alpha: 0.16),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            SurfaceFinish.glass =>
              style.glow
                  ? <BoxShadow>[
                      BoxShadow(
                        color: style.accent.withValues(alpha: 0.22),
                        blurRadius: 26,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: style.tokens.shadowColor.withValues(alpha: 0.36),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
          };

    Widget inner = DecoratedBox(
      decoration: surface,
      child: Padding(padding: padding, child: child),
    );
    if (!matte && style.blur > 0) {
      // El acabado líquido limita el desenfoque para no multiplicar el coste GPU.
      final double sigma = style.tokens.finish == SurfaceFinish.liquid
          ? math.min(style.blur, 16)
          : style.blur;
      inner = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: inner,
      );
    }

    final Widget clipped = ClipRRect(borderRadius: radius, child: inner);
    if (shadows == null) return clipped;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: shadows),
      child: clipped,
    );
  }
}
