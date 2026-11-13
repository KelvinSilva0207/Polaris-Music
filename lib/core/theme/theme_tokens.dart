import 'package:flutter/material.dart';

import 'app_theme_config.dart';

/// Tokens visuales de Polaris.
///
/// La UI consume estos tokens en lugar de codificar colores o radios. La
/// `AppThemeConfig` activa los escribe en [AppTheme] y así toda la app cambia
/// en vivo sin reiniciar.
@immutable
class PolarisTokens extends ThemeExtension<PolarisTokens> {
  const PolarisTokens({
    required this.accent,
    this.panelRadius = 18,
    this.glassOpacity = 0.10,
    this.glassBlur = 24,
    this.islandRadius = 28,
    this.glassEnabled = false,
    this.cardStyle = CardStyle.glassmorphic,
    this.artworkShape = ArtworkShape.circleVinyl,
    this.progressBarType = ProgressBarType.linearClassic,
    this.paletteMode = ColorPaletteMode.fixedPreset,
    this.background = const Color(0xFF0B0710),
    this.surface = const Color(0xFF151020),
    this.backdrop = const <Color>[
      Color(0xFF180E2E),
      Color(0xFF0B0710),
      Color(0xFF2A1450),
    ],
  });

  final Color accent;
  final double panelRadius;
  final double glassOpacity;
  final double glassBlur;
  final double islandRadius;
  final bool glassEnabled;
  final CardStyle cardStyle;
  final ArtworkShape artworkShape;
  final ProgressBarType progressBarType;
  final ColorPaletteMode paletteMode;
  final Color background;
  final Color surface;
  final List<Color> backdrop;

  bool get isGlass => cardStyle == CardStyle.glassmorphic;
  bool get isNeumorphic => cardStyle == CardStyle.neumorphic;
  bool get isFlat => cardStyle == CardStyle.flatMinimal;

  /// Color de relieve claro para neumorphism.
  Color get neumorphicLight =>
      Color.lerp(surface, Colors.white, 0.10) ?? surface;

  /// Color de relieve oscuro para neumorphism.
  Color get neumorphicDark =>
      Color.lerp(surface, Colors.black, 0.55) ?? surface;

  /// Color base de un panel según el [cardStyle] activo.
  ///
  /// Las pantallas que no pueden usar el contenedor compartido (por ejemplo,
  /// porque necesitan animar su decoración) consumen estos getters para que el
  /// preset de tema también las afecte.
  Color get panelColor => switch (cardStyle) {
    CardStyle.glassmorphic => Colors.white.withValues(alpha: glassOpacity),
    CardStyle.neumorphic => surface,
    CardStyle.flatMinimal => surface.withValues(alpha: 0.94),
  };

  /// Color opaco para paneles flotantes que no pueden desenfocar el fondo
  /// (por ejemplo, la isla dinámica animada). Mantiene la legibilidad.
  Color get panelOverlay => switch (cardStyle) {
    CardStyle.glassmorphic =>
      Color.lerp(surface, Colors.white, 0.10) ?? surface,
    CardStyle.neumorphic => surface,
    CardStyle.flatMinimal => surface,
  };

  /// Borde de un panel según el [cardStyle] activo.
  Color get panelBorder => switch (cardStyle) {
    CardStyle.glassmorphic => Colors.white.withValues(alpha: 0.16),
    CardStyle.neumorphic => Colors.white.withValues(alpha: 0.035),
    CardStyle.flatMinimal => Colors.white.withValues(alpha: 0.07),
  };

  /// Sombras de un panel, opcionalmente con un resplandor del acento.
  List<BoxShadow> panelShadows({Color? glow, double radius = 24}) {
    switch (cardStyle) {
      case CardStyle.glassmorphic:
        return <BoxShadow>[
          if (glow != null)
            BoxShadow(
              color: glow.withValues(alpha: 0.18),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: radius,
            offset: const Offset(0, 14),
          ),
        ];
      case CardStyle.neumorphic:
        return <BoxShadow>[
          BoxShadow(
            color: neumorphicLight.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(-5, -5),
          ),
          BoxShadow(
            color: neumorphicDark.withValues(alpha: 0.85),
            blurRadius: 20,
            offset: const Offset(7, 8),
          ),
        ];
      case CardStyle.flatMinimal:
        return const <BoxShadow>[];
    }
  }

  /// Decoración completa de un panel adaptada al estilo activo.
  ///
  /// [elevated] desactiva las sombras en paneles pequeños que viven dentro de
  /// una lista o tarjeta y no deben flotar sobre el fondo.
  BoxDecoration panelDecoration({
    double? radius,
    Color? glow,
    Color? color,
    Color? borderColor,
    Gradient? gradient,
    bool elevated = true,
  }) {
    return BoxDecoration(
      color: gradient == null ? (color ?? panelColor) : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius ?? panelRadius),
      border: Border.all(color: borderColor ?? panelBorder),
      boxShadow: elevated ? panelShadows(glow: glow) : null,
    );
  }

  static const PolarisTokens fallback = PolarisTokens(
    accent: Color(0xFF8B5CF6),
  );

  @override
  PolarisTokens copyWith({
    Color? accent,
    double? panelRadius,
    double? glassOpacity,
    double? glassBlur,
    double? islandRadius,
    bool? glassEnabled,
    CardStyle? cardStyle,
    ArtworkShape? artworkShape,
    ProgressBarType? progressBarType,
    ColorPaletteMode? paletteMode,
    Color? background,
    Color? surface,
    List<Color>? backdrop,
  }) => PolarisTokens(
    accent: accent ?? this.accent,
    panelRadius: panelRadius ?? this.panelRadius,
    glassOpacity: glassOpacity ?? this.glassOpacity,
    glassBlur: glassBlur ?? this.glassBlur,
    islandRadius: islandRadius ?? this.islandRadius,
    glassEnabled: glassEnabled ?? this.glassEnabled,
    cardStyle: cardStyle ?? this.cardStyle,
    artworkShape: artworkShape ?? this.artworkShape,
    progressBarType: progressBarType ?? this.progressBarType,
    paletteMode: paletteMode ?? this.paletteMode,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    backdrop: backdrop ?? this.backdrop,
  );

  @override
  PolarisTokens lerp(covariant PolarisTokens? other, double t) {
    if (other == null) return this;
    return PolarisTokens(
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      panelRadius: lerpDouble(panelRadius, other.panelRadius, t),
      glassOpacity: lerpDouble(glassOpacity, other.glassOpacity, t),
      glassBlur: lerpDouble(glassBlur, other.glassBlur, t),
      islandRadius: lerpDouble(islandRadius, other.islandRadius, t),
      glassEnabled: t < 0.5 ? glassEnabled : other.glassEnabled,
      cardStyle: t < 0.5 ? cardStyle : other.cardStyle,
      artworkShape: t < 0.5 ? artworkShape : other.artworkShape,
      progressBarType: t < 0.5 ? progressBarType : other.progressBarType,
      paletteMode: t < 0.5 ? paletteMode : other.paletteMode,
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      backdrop: other.backdrop,
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

extension PolarisThemeX on BuildContext {
  PolarisTokens get tokens =>
      Theme.of(this).extension<PolarisTokens>() ?? PolarisTokens.fallback;

  Color get accent => tokens.accent;
}
