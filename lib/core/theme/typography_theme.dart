import 'package:flutter/material.dart';

import 'typography_config.dart';

/// Aplica la familia, escala y pesos de Polaris a un [TextTheme] de Material.
///
/// Se usa tanto para el tema global como para las superficies compactas que
/// eligen una tipografía propia.
TextTheme buildPolarisTextTheme(
  TextTheme base,
  String? family,
  TypographyConfig config,
) {
  TextStyle? role(
    TextStyle? source, {
    required FontWeight weight,
    double? letterSpacing,
    double? height,
  }) {
    if (source == null) return null;
    return source.copyWith(
      fontFamily: family,
      fontSize: (source.fontSize ?? 14) * config.scale,
      fontWeight: weight,
      letterSpacing: letterSpacing ?? source.letterSpacing,
      height: height ?? source.height,
    );
  }

  final TextTheme themed = base.apply(
    fontFamily: family,
    fontSizeFactor: config.scale,
  );
  return themed.copyWith(
    headlineMedium: role(
      base.headlineMedium,
      weight: config.headline,
      letterSpacing: -0.5,
    ),
    titleLarge: role(
      base.titleLarge,
      weight: config.headline,
      letterSpacing: -0.2,
    ),
    titleMedium: role(base.titleMedium, weight: config.metadata),
    bodyMedium: role(base.bodyMedium, weight: config.metadata, height: 1.35),
    bodyLarge: role(base.bodyLarge, weight: config.lyrics),
    labelSmall: role(
      base.labelSmall,
      weight: config.metadata,
      letterSpacing: 0.4,
    ),
  );
}
