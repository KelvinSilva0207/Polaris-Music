import 'package:flutter/material.dart';

import 'app_theme_config.dart';
import 'color_math.dart';
import 'theme_tokens.dart';
import 'typography_config.dart';
import 'typography_theme.dart';

/// Construye el [ThemeData] de Polaris a partir de una [AppThemeConfig].
///
/// La Fase 1 solo usaba un acento; ahora el tema también aporta fondos,
/// superficies y tokens de tarjeta, carátula y progreso. Material 3 sigue
/// siendo la base para accesibilidad, estados y tipografía.
class AppTheme {
  AppTheme._();

  static const Color defaultAccent = Color(0xFF8B5CF6);
  static const Color background = Color(0xFF0B0710);
  static const Color surface = Color(0xFF151020);
  static ThemeData fromConfig(
    AppThemeConfig config, {
    ResolvedTypography? typography,
  }) {
    final ResolvedTypography type =
        typography ??
        const ResolvedTypography(TypographyConfig(), 'Polaris Sans');
    final Color accent = config.accent;
    final DesignLanguage language = config.designLanguage;
    final Brightness brightness = config.brightness;
    final Color ink = ColorMath.onColor(config.surface);
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          surface: config.surface,
          primary: accent,
          secondary: config.secondary,
          onSurface: ink,
          onPrimary: ColorMath.onColor(accent),
        );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: config.background,
      canvasColor: config.background,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[
        PolarisTokens(
          accent: accent,
          cardStyle: config.cardStyle,
          artworkShape: config.artworkShape,
          progressBarType: config.progressBarType,
          paletteMode: config.paletteMode,
          background: config.background,
          surface: config.surface,
          backdrop: config.backdrop,
          panelRadius: config.panelRadius,
          artworkRadius: config.artworkRadius,
          glassBlur: config.glassBlur,
          progressColor: config.progressColor,
          volumeColor: config.volumeColor,
          karaokeColor: config.karaokeColor,
          borderColor: config.borderColor,
          shadowColor: config.shadowColor,
          shadowOpacity: config.shadowOpacity,
          neumorphicLight: config.neumorphicLight,
          neumorphicDark: config.neumorphicDark,
          glassEnabled: config.isGlass,
          glassOpacity: config.glassOpacity,
          finish: config.finish,
          designLanguage: config.designLanguage,
          secondary: config.secondary,
          surfaceOpacity: config.surfaceOpacity,
          brightness: brightness,
          typography: type.config,
        ),
      ],
      cardTheme: CardThemeData(
        color: config.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(language.tileRadius),
          side: language.borderWidth == 0
              ? BorderSide.none
              : BorderSide(
                  color: config.borderColor,
                  width: language.borderWidth,
                ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.18),
        selectedIconTheme: IconThemeData(color: accent),
        selectedLabelTextStyle: TextStyle(
          color: accent,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: config.surface,
        indicatorColor: accent.withValues(alpha: 0.20),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(language.navRadius),
        ),
        elevation: 0,
        height: 64,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        inactiveTrackColor: ink.withValues(alpha: 0.16),
        overlayColor: accent.withValues(alpha: 0.16),
        trackHeight: language.progressThickness,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? accent : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? accent.withValues(alpha: 0.4)
              : null,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ink.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(language.tileRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(language.tileRadius),
          borderSide: BorderSide(color: ink.withValues(alpha: 0.12)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: ink.withValues(alpha: language.hairlineDividers ? 0.08 : 0.12),
        thickness: language.hairlineDividers ? 0.6 : 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color.lerp(config.surface, ink, 0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: Color.lerp(config.surface, ink, 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      fontFamily: type.family,
    );

    return base.copyWith(
      textTheme: buildPolarisTextTheme(
        base.textTheme,
        type.family,
        type.config,
      ).apply(bodyColor: ink, displayColor: ink),
      iconTheme: IconThemeData(color: ink),
    );
  }

  /// Compatibilidad con llamadas de Fase 1 que solo pasaban el acento.
  static ThemeData dark({Color accent = defaultAccent}) =>
      fromConfig(AppThemeConfig.defaults.copyWith(accent: accent));
}
