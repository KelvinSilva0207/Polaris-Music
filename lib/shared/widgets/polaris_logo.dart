import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/theme_tokens.dart';

/// Logotipo oficial de Polaris Music.
///
/// Se usa el mismo `.ico` canónico convertido a PNG para que la bandeja, la
/// barra de título, la isla y los ajustes compartan identidad visual. Si el
/// recurso faltara, cae a una nota musical con el acento del tema.
class PolarisLogo extends StatelessWidget {
  const PolarisLogo({
    super.key,
    this.size = 32,
    this.radius,
    this.glow = false,
  });

  final double size;
  final double? radius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final BorderRadius borderRadius = BorderRadius.circular(
      radius ?? size * 0.28,
    );

    final Widget image = Image.asset(
      AppConstants.logoAsset,
      width: size,
      height: size,
      fit: BoxFit.cover,
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
            color: Colors.white,
          ),
        );
      },
    );

    return Container(
      width: size,
      height: size,
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
      child: ClipRRect(borderRadius: borderRadius, child: image),
    );
  }
}
