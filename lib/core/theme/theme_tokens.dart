import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme_config.dart';
import 'color_math.dart';
import 'typography_config.dart';

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
    this.artworkRadius = 24,
    this.glassOpacity = 0.10,
    this.glassBlur = 24,
    this.progressColor = const Color(0xFF8B5CF6),
    this.volumeColor = const Color(0xFF8B5CF6),
    this.karaokeColor = const Color(0xFF8B5CF6),
    this.islandRadius = 28,
    this.glassEnabled = false,
    this.finish = SurfaceFinish.glass,
    this.designLanguage = DesignLanguage.violetGlass,
    this.secondary = const Color(0xFF22D3EE),
    this.surfaceOpacity = 0.94,
    this.brightness = Brightness.dark,
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
    this.borderColor = const Color(0x1AFFFFFF),
    this.shadowColor = const Color(0xFF000000),
    this.shadowOpacity = 0.28,
    this.neumorphicLight = const Color(0xFF2A2A2A),
    this.neumorphicDark = const Color(0xFF000000),
    this.typography,
  });

  final Color accent;
  final double panelRadius;
  final double artworkRadius;
  final double glassOpacity;
  final double glassBlur;

  /// Color exclusivo del progreso musical.
  final Color progressColor;

  /// Color exclusivo del volumen.
  final Color volumeColor;

  /// Color de la línea activa del karaoke.
  final Color karaokeColor;

  final double islandRadius;
  final bool glassEnabled;

  /// Acabado de superficie (segunda capa del sistema de temas).
  final SurfaceFinish finish;

  /// Lenguaje visual completo del preset activo.
  final DesignLanguage designLanguage;

  /// Acento secundario para brillos y degradados orgánicos.
  final Color secondary;

  /// Opacidad de las superficies sólidas.
  final double surfaceOpacity;

  /// Brillo del tema; define tinta clara u oscura.
  final Brightness brightness;

  final CardStyle cardStyle;
  final ArtworkShape artworkShape;
  final ProgressBarType progressBarType;
  final ColorPaletteMode paletteMode;
  final Color background;
  final Color surface;
  final List<Color> backdrop;

  /// Borde de los paneles: Violet Glass lo define como blanco al 10 %.
  final Color borderColor;

  /// Color y opacidad de las sombras suaves del preset.
  final Color shadowColor;
  final double shadowOpacity;

  /// Luces y sombras del relieve neumórfico.
  final Color neumorphicLight;
  final Color neumorphicDark;

  /// Tipografía activa, expuesta a vistas que ajustan pesos por rol (letras).
  final TypographyConfig? typography;

  bool get isGlass => cardStyle == CardStyle.glassmorphic;
  bool get isNeumorphic => cardStyle == CardStyle.neumorphic;
  bool get isFlat => cardStyle == CardStyle.flatMinimal;
  bool get isLight => brightness == Brightness.light;
  bool get isLiquid => finish == SurfaceFinish.liquid;
  bool get isMatte => finish == SurfaceFinish.matte;

  /// Atajos del lenguaje visual para los widgets que no necesitan el enum.
  bool get segmentedProgress => designLanguage.segmentedProgress;
  double get progressThickness => designLanguage.progressThickness;
  bool get glowEdge => designLanguage.glowEdge;
  bool get hairlineDividers => designLanguage.hairlineDividers;
  double get tileRadius => designLanguage.tileRadius;
  double get navRadius => designLanguage.navRadius;

  /// Tinta principal legible sobre el panel activo.
  Color get foreground => ColorMath.onColor(panelOverlay);

  /// Tinta con opacidad para textos secundarios en cualquier tema.
  Color ink([double alpha = 1]) => foreground.withValues(alpha: alpha);

  /// Velo glassmorphic: superficie oscura teñida con el acento activo.
  ///
  /// `glassOpacity` mide la densidad del velo, NO su luminosidad. Usarlo como
  /// alfa de `Colors.white` produce paneles casi blancos en las superficies
  /// compactas (opacity 0.92-0.94) donde el texto claro deja de leerse.
  Color get glassPanelColor {
    final Color base = Color.lerp(surface, accent, 0.06) ?? surface;
    final double alpha = (0.12 + glassOpacity * 0.30).clamp(0.12, 0.46);
    return base.withValues(alpha: alpha);
  }

  /// Color base de un panel según el [cardStyle] activo.
  ///
  /// Las pantallas que no pueden usar el contenedor compartido (por ejemplo,
  /// porque necesitan animar su decoración) consumen estos getters para que el
  /// preset de tema también las afecte.
  Color get panelColor => switch (cardStyle) {
    CardStyle.glassmorphic => glassPanelColor,
    CardStyle.neumorphic => surface,
    CardStyle.flatMinimal => surface.withValues(alpha: surfaceOpacity),
  };

  /// Color opaco para paneles flotantes que no pueden desenfocar el fondo
  /// (por ejemplo, la isla dinámica animada). Mantiene la legibilidad.
  Color get panelOverlay => switch (cardStyle) {
    CardStyle.glassmorphic =>
      finish == SurfaceFinish.liquid
          ? (Color.lerp(surface, secondary, 0.10) ?? surface)
          : (Color.lerp(surface, Colors.white, 0.10) ?? surface),
    CardStyle.neumorphic => surface,
    CardStyle.flatMinimal => surface,
  };

  /// Borde de un panel según el [cardStyle] activo.
  ///
  /// `borderColor` viene del preset: Violet Glass usa blanco al 10 %.
  Color get panelBorder => borderColor;

  /// Borde con dirección especular según el acabado activo.
  ///
  /// Glass refuerza el canto superior e izquierdo, Liquid lo tiñe con el
  /// acento secundario y Mate usa un contorno nítido y legible en claro.
  BoxBorder get specularPanelBorder {
    final Color base = panelBorder;
    final Color light = foreground;
    switch (finish) {
      case SurfaceFinish.glass:
        return Border(
          top: BorderSide(
            color: Color.lerp(base, light, 0.30) ?? base,
            width: 1.2,
          ),
          left: BorderSide(
            color: Color.lerp(base, light, 0.18) ?? base,
            width: 1,
          ),
          right: BorderSide(color: base, width: 1),
          bottom: BorderSide(color: base, width: 1),
        );
      case SurfaceFinish.liquid:
        final Color tinted = Color.lerp(base, secondary, 0.42) ?? base;
        return Border(
          top: BorderSide(
            color: Color.lerp(tinted, light, 0.24) ?? tinted,
            width: 1.4,
          ),
          left: BorderSide(color: tinted, width: 1.1),
          right: BorderSide(color: tinted, width: 1),
          bottom: BorderSide(
            color: tinted.withValues(alpha: tinted.a * 0.55),
            width: 1,
          ),
        );
      case SurfaceFinish.matte:
        return Border.all(
          color: Color.lerp(base, light, isLight ? 0.55 : 0.26) ?? base,
          width: 1,
        );
    }
  }

  /// Gradiente orgánico del acabado Liquid. Devuelve `null` en Material
  /// opacos para que el panel conserve un color plano y alto contraste.
  Gradient? finishGradient(double phase, {Color? base}) {
    if (!isLiquid) return null;
    final double angle = phase * 2 * math.pi;
    final Alignment begin = Alignment(math.cos(angle), math.sin(angle));
    final Alignment end = Alignment(-begin.x, -begin.y);
    final Color panel = base ?? panelOverlay;
    return LinearGradient(
      begin: begin,
      end: end,
      colors: <Color>[
        Color.lerp(panel, accent, isLight ? 0.12 : 0.24) ?? panel,
        panel,
        Color.lerp(panel, secondary, isLight ? 0.14 : 0.28) ?? panel,
      ],
    );
  }

  /// Sombras de un panel, opcionalmente con un resplandor del acento.
  List<BoxShadow> panelShadows({Color? glow, double radius = 24}) {
    if (isMatte) {
      return <BoxShadow>[
        BoxShadow(
          color: shadowColor.withValues(alpha: shadowOpacity * 0.55),
          blurRadius: radius * 0.55,
          offset: const Offset(0, 5),
        ),
      ];
    }
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
            color: shadowColor.withValues(alpha: shadowOpacity),
            blurRadius: radius,
            offset: const Offset(0, 14),
          ),
        ];
      case CardStyle.neumorphic:
        return <BoxShadow>[
          BoxShadow(
            color: neumorphicLight.withValues(alpha: 0.90),
            blurRadius: 14,
            offset: const Offset(-5, -5),
          ),
          BoxShadow(
            color: neumorphicDark.withValues(alpha: shadowOpacity),
            blurRadius: 20,
            offset: const Offset(7, 8),
          ),
        ];
      case CardStyle.flatMinimal:
        // Monolith Minimal: sombras suaves, casi imperceptibles.
        return <BoxShadow>[
          BoxShadow(
            color: shadowColor.withValues(alpha: shadowOpacity),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: shadowColor.withValues(alpha: shadowOpacity * 0.55),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ];
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
    double phase = 0,
    bool elevated = true,
  }) {
    final Color baseColor = color ?? (isMatte ? panelOverlay : panelColor);
    final Gradient? effective =
        gradient ?? finishGradient(phase, base: baseColor);
    BoxBorder? border = borderColor != null
        ? Border.all(color: borderColor, width: designLanguage.borderWidth)
        : designLanguage.borderWidth == 0
        ? null
        : specularPanelBorder;
    // Flutter no permite esquinas redondeadas con lados de colores distintos.
    // El borde especular se conserva como color medio para que ningún panel
    // con radio (polaris_surface, paneles de lista, ecualizador...) reviente al
    // pintarse en modo debug.
    if (border is Border && !border.isUniform) {
      border = Border.all(
        color:
            Color.lerp(border.top.color, border.bottom.color, 0.5) ??
            panelBorder,
        width: (border.top.width + border.bottom.width) / 2,
      );
    }
    return BoxDecoration(
      color: effective == null ? baseColor : null,
      gradient: effective,
      borderRadius: BorderRadius.circular(radius ?? panelRadius),
      border: border,
      boxShadow: elevated ? panelShadows(glow: glowEdge ? glow : null) : null,
    );
  }

  static const PolarisTokens fallback = PolarisTokens(
    accent: Color(0xFF8B5CF6),
  );

  @override
  PolarisTokens copyWith({
    Color? accent,
    double? panelRadius,
    double? artworkRadius,
    double? glassOpacity,
    double? glassBlur,
    Color? progressColor,
    Color? volumeColor,
    Color? karaokeColor,
    double? islandRadius,
    bool? glassEnabled,
    SurfaceFinish? finish,
    DesignLanguage? designLanguage,
    Color? secondary,
    double? surfaceOpacity,
    Brightness? brightness,
    CardStyle? cardStyle,
    ArtworkShape? artworkShape,
    ProgressBarType? progressBarType,
    ColorPaletteMode? paletteMode,
    Color? background,
    Color? surface,
    List<Color>? backdrop,
    Color? borderColor,
    Color? shadowColor,
    double? shadowOpacity,
    Color? neumorphicLight,
    Color? neumorphicDark,
    TypographyConfig? typography,
  }) => PolarisTokens(
    accent: accent ?? this.accent,
    panelRadius: panelRadius ?? this.panelRadius,
    artworkRadius: artworkRadius ?? this.artworkRadius,
    glassOpacity: glassOpacity ?? this.glassOpacity,
    glassBlur: glassBlur ?? this.glassBlur,
    progressColor: progressColor ?? this.progressColor,
    volumeColor: volumeColor ?? this.volumeColor,
    karaokeColor: karaokeColor ?? this.karaokeColor,
    islandRadius: islandRadius ?? this.islandRadius,
    glassEnabled: glassEnabled ?? this.glassEnabled,
    finish: finish ?? this.finish,
    designLanguage: designLanguage ?? this.designLanguage,
    secondary: secondary ?? this.secondary,
    surfaceOpacity: surfaceOpacity ?? this.surfaceOpacity,
    brightness: brightness ?? this.brightness,
    cardStyle: cardStyle ?? this.cardStyle,
    artworkShape: artworkShape ?? this.artworkShape,
    progressBarType: progressBarType ?? this.progressBarType,
    paletteMode: paletteMode ?? this.paletteMode,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    backdrop: backdrop ?? this.backdrop,
    borderColor: borderColor ?? this.borderColor,
    shadowColor: shadowColor ?? this.shadowColor,
    shadowOpacity: shadowOpacity ?? this.shadowOpacity,
    neumorphicLight: neumorphicLight ?? this.neumorphicLight,
    neumorphicDark: neumorphicDark ?? this.neumorphicDark,
    typography: typography ?? this.typography,
  );

  @override
  PolarisTokens lerp(covariant PolarisTokens? other, double t) {
    if (other == null) return this;
    return PolarisTokens(
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      panelRadius: lerpDouble(panelRadius, other.panelRadius, t),
      artworkRadius: lerpDouble(artworkRadius, other.artworkRadius, t),
      glassOpacity: lerpDouble(glassOpacity, other.glassOpacity, t),
      glassBlur: lerpDouble(glassBlur, other.glassBlur, t),
      progressColor:
          Color.lerp(progressColor, other.progressColor, t) ?? progressColor,
      volumeColor: Color.lerp(volumeColor, other.volumeColor, t) ?? volumeColor,
      karaokeColor:
          Color.lerp(karaokeColor, other.karaokeColor, t) ?? karaokeColor,
      islandRadius: lerpDouble(islandRadius, other.islandRadius, t),
      glassEnabled: t < 0.5 ? glassEnabled : other.glassEnabled,
      finish: t < 0.5 ? finish : other.finish,
      designLanguage: t < 0.5 ? designLanguage : other.designLanguage,
      secondary: Color.lerp(secondary, other.secondary, t) ?? secondary,
      surfaceOpacity: lerpDouble(surfaceOpacity, other.surfaceOpacity, t),
      brightness: t < 0.5 ? brightness : other.brightness,
      cardStyle: t < 0.5 ? cardStyle : other.cardStyle,
      artworkShape: t < 0.5 ? artworkShape : other.artworkShape,
      progressBarType: t < 0.5 ? progressBarType : other.progressBarType,
      paletteMode: t < 0.5 ? paletteMode : other.paletteMode,
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      backdrop: other.backdrop,
      borderColor: Color.lerp(borderColor, other.borderColor, t) ?? borderColor,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t) ?? shadowColor,
      shadowOpacity: lerpDouble(shadowOpacity, other.shadowOpacity, t),
      neumorphicLight:
          Color.lerp(neumorphicLight, other.neumorphicLight, t) ??
          neumorphicLight,
      neumorphicDark:
          Color.lerp(neumorphicDark, other.neumorphicDark, t) ?? neumorphicDark,
      typography: t < 0.5 ? typography : other.typography,
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

extension PolarisThemeX on BuildContext {
  PolarisTokens get tokens =>
      Theme.of(this).extension<PolarisTokens>() ?? PolarisTokens.fallback;

  Color get accent => tokens.accent;

  /// Color de texto heredado del tema (`onSurface`). `null = heredar` sigue
  /// siendo el patrón por defecto; esto solo permite aplicar opacidades sin
  /// escribir literales `Colors.whiteXX`.
  Color get onSurface => Theme.of(this).colorScheme.onSurface;

  /// Color legible calculado sobre el panel activo (glass/neumo/flat).
  /// Usa `panelOverlay` (opaco), nunca `panelColor` (blanco con alfa).
  Color get onPanel => ColorMath.onColor(tokens.panelOverlay);

  /// Tinta principal del tema: blanca en temas oscuros, oscura en claros.
  Color get ink => tokens.foreground;

  /// Tinta secundaria con opacidad, legible en cualquier tema.
  Color inkAlpha(double alpha) => tokens.ink(alpha);
}
