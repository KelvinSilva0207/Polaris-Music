import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/color_math.dart';
import '../../core/theme/theme_tokens.dart';

/// Logotipo oficial de Polaris Music.
///
/// El asset ya incluye su propio fondo redondeado y esquinas transparentes,
/// así que no se recorta: solo se escala. El mismo `.ico` canónico se usa para
/// bandeja, barra de título, isla y ajustes, manteniendo una sola identidad.
/// Si el recurso faltara, cae a una nota musical con el acento del tema.
class PolarisLogo extends StatelessWidget {
  const PolarisLogo({super.key, this.size = 32, this.glow = false});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    // Radio intrínseco del logo (~6% del lado). Se usa solo para el halo.
    final BorderRadius borderRadius = BorderRadius.circular(size * 0.07);

    final Widget image = Image.asset(
      AppConstants.logoAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                tokens.accent.withValues(alpha: 0.92),
                tokens.accent.withValues(alpha: 0.35),
              ],
            ),
          ),
          child: Icon(
            Icons.music_note_rounded,
            size: size * 0.55,
            color: ColorMath.onColor(tokens.accent),
          ),
        );
      },
    );

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: glow
              ? <BoxShadow>[
                  BoxShadow(
                    color: tokens.accent.withValues(alpha: 0.42),
                    blurRadius: size * 0.55,
                    spreadRadius: size * 0.04,
                  ),
                ]
              : null,
        ),
        child: image,
      ),
    );
  }
}
