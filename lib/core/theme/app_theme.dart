import 'package:flutter/material.dart';

import 'app_theme_config.dart';
import 'theme_tokens.dart';

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
  static ThemeData fromConfig(AppThemeConfig config) {
    final Color accent = config.accent;
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ).copyWith(
          surface: config.surface,
          primary: accent,
          secondary: accent.withValues(alpha: 0.75),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
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
        ),
      ],
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(height: 1.35),
        labelSmall: TextStyle(letterSpacing: 0.4),
      ),
      cardTheme: CardThemeData(
        color: config.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(config.panelRadius),
          side: BorderSide(color: config.borderColor),
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
        elevation: 0,
        height: 64,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
        overlayColor: accent.withValues(alpha: 0.16),
        trackHeight: 3,
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
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color.lerp(config.surface, Colors.white, 0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: Color.lerp(config.surface, Colors.white, 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Compatibilidad con llamadas de Fase 1 que solo pasaban el acento.
  static ThemeData dark({Color accent = defaultAccent}) =>
      fromConfig(AppThemeConfig.defaults.copyWith(accent: accent));
}
