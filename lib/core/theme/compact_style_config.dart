import 'package:flutter/material.dart';

import 'app_theme_config.dart';
import 'font_catalog.dart';
import 'theme_tokens.dart';
import 'typography_config.dart';

export 'app_theme_config.dart' show ArtworkShape, CardStyle;

/// Superficies compactas que pueden personalizarse de forma independiente.
enum CompactSurface { island, mini, phone, player }

extension CompactSurfaceX on CompactSurface {
  String get label => switch (this) {
    CompactSurface.island => 'Isla Dinámica',
    CompactSurface.mini => 'Mini-reproductor',
    CompactSurface.phone => 'Modo Teléfono',
    CompactSurface.player => 'Reproductor Principal',
  };

  String get description => switch (this) {
    CompactSurface.island => 'Cápsula flotante de Windows',
    CompactSurface.mini => 'Barra compacta y ventana de bandeja',
    CompactSurface.phone => 'Panel vertical acoplado al lateral',
    CompactSurface.player => 'Pantalla de reproducción completa',
  };

  IconData get icon => switch (this) {
    CompactSurface.island => Icons.airplay_rounded,
    CompactSurface.mini => Icons.view_agenda_outlined,
    CompactSurface.phone => Icons.phone_android_rounded,
    CompactSurface.player => Icons.play_circle_outline_rounded,
  };
}

/// Diseño persistido por separado para cada superficie compacta.
///
/// Los colores nulos significan «heredar del tema global», de modo que el
/// usuario puede personalizar solo el acento de la isla sin alterar el
/// reproductor principal, por ejemplo.
@immutable
class CompactStyleConfig {
  const CompactStyleConfig({
    this.accent,
    this.background,
    this.progressColor,
    this.volumeColor,
    this.artworkShape,
    this.cardStyle = CardStyle.glassmorphic,
    this.cornerRadius = 20,
    this.opacity = 0.92,
    this.blur = 18,
    this.glow = true,
    this.fontFamilyId,
    this.fontScale,
    this.autoHide = false,
    this.autoHideSeconds = 8,
  });

  static const CompactStyleConfig island = CompactStyleConfig(
    accent: null,
    background: null,
    cardStyle: CardStyle.glassmorphic,
    cornerRadius: 38,
    opacity: 0.94,
    blur: 16,
    glow: true,
    autoHide: true,
    autoHideSeconds: 8,
  );

  static const CompactStyleConfig mini = CompactStyleConfig(
    accent: null,
    background: null,
    cardStyle: CardStyle.glassmorphic,
    cornerRadius: 18,
    opacity: 0.92,
    blur: 14,
    glow: true,
  );

  static const CompactStyleConfig phone = CompactStyleConfig(
    accent: null,
    background: null,
    cardStyle: CardStyle.glassmorphic,
    cornerRadius: 26,
    opacity: 0.92,
    blur: 16,
    glow: true,
  );

  static const CompactStyleConfig player = CompactStyleConfig(
    accent: null,
    background: null,
    cardStyle: CardStyle.glassmorphic,
    cornerRadius: 30,
    opacity: 0.94,
    blur: 20,
    glow: true,
  );

  final Color? accent;
  final Color? background;

  /// Colores propios de la barra de progreso y del volumen de esta superficie.
  /// `null` = heredar el acento del modo.
  final Color? progressColor;
  final Color? volumeColor;

  /// Forma de carátula propia de esta superficie. `null` = heredar la global.
  final ArtworkShape? artworkShape;

  final CardStyle cardStyle;
  final double cornerRadius;
  final double opacity;
  final double blur;
  final bool glow;

  /// `null` hereda la tipografía global. Si se indica una fuente incluida o
  /// importada, esta superficie usa solo esa familia.
  final String? fontFamilyId;

  /// `null` hereda la escala global; permite agrandar letras en la isla o en
  /// el reproductor sin alterar biblioteca ni letras.
  final double? fontScale;

  /// Solo tiene efecto en [CompactSurface.island].
  final bool autoHide;
  final int autoHideSeconds;

  factory CompactStyleConfig.defaultsFor(CompactSurface surface) =>
      switch (surface) {
        CompactSurface.island => island,
        CompactSurface.mini => mini,
        CompactSurface.phone => phone,
        CompactSurface.player => player,
      };

  CompactStyleConfig copyWith({
    Object? accent = _unset,
    Object? background = _unset,
    Object? progressColor = _unset,
    Object? volumeColor = _unset,
    Object? artworkShape = _unset,
    CardStyle? cardStyle,
    double? cornerRadius,
    double? opacity,
    double? blur,
    bool? glow,
    Object? fontFamilyId = _unset,
    Object? fontScale = _unset,
    bool? autoHide,
    int? autoHideSeconds,
  }) => CompactStyleConfig(
    accent: identical(accent, _unset) ? this.accent : accent as Color?,
    background: identical(background, _unset)
        ? this.background
        : background as Color?,
    progressColor: identical(progressColor, _unset)
        ? this.progressColor
        : progressColor as Color?,
    volumeColor: identical(volumeColor, _unset)
        ? this.volumeColor
        : volumeColor as Color?,
    artworkShape: identical(artworkShape, _unset)
        ? this.artworkShape
        : artworkShape as ArtworkShape?,
    cardStyle: cardStyle ?? this.cardStyle,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    opacity: opacity ?? this.opacity,
    blur: blur ?? this.blur,
    glow: glow ?? this.glow,
    fontFamilyId: identical(fontFamilyId, _unset)
        ? this.fontFamilyId
        : fontFamilyId as String?,
    fontScale: identical(fontScale, _unset)
        ? this.fontScale
        : fontScale as double?,
    autoHide: autoHide ?? this.autoHide,
    autoHideSeconds: autoHideSeconds ?? this.autoHideSeconds,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'accent': accent?.toARGB32(),
    'background': background?.toARGB32(),
    'progressColor': progressColor?.toARGB32(),
    'volumeColor': volumeColor?.toARGB32(),
    'artworkShape': artworkShape?.name,
    'cardStyle': cardStyle.name,
    'cornerRadius': cornerRadius,
    'opacity': opacity,
    'blur': blur,
    'glow': glow,
    'fontFamilyId': fontFamilyId,
    'fontScale': fontScale,
    'autoHide': autoHide,
    'autoHideSeconds': autoHideSeconds,
  };

  factory CompactStyleConfig.fromJson(
    Map<String, Object?> json, {
    CompactSurface? surface,
  }) {
    // Los defaults dependen de la superficie: sin esto, un respaldo antiguo de
    // la isla recuperaría el radio del reproductor (20 en vez de 38).
    final CompactStyleConfig base = surface == null
        ? CompactStyleConfig()
        : CompactStyleConfig.defaultsFor(surface);
    return base.copyWith(
      accent: _color(json['accent']),
      background: _color(json['background']),
      progressColor: _color(json['progressColor']),
      volumeColor: _color(json['volumeColor']),
      artworkShape:
          _enumByName(ArtworkShape.values, json['artworkShape']) ??
          base.artworkShape,
      cardStyle:
          _enumByName(CardStyle.values, json['cardStyle']) ?? base.cardStyle,
      cornerRadius: _number(
        json['cornerRadius'],
        base.cornerRadius,
      ).clamp(8, 56),
      opacity: _number(json['opacity'], base.opacity).clamp(0.35, 1.0),
      blur: _number(json['blur'], base.blur).clamp(0, 32),
      glow: json['glow'] is bool ? json['glow']! as bool : base.glow,
      fontFamilyId: json['fontFamilyId'] is String
          ? json['fontFamilyId']! as String
          : null,
      fontScale:
          json['fontScale'] is num && (json['fontScale']! as num).isFinite
          ? (json['fontScale']! as num).toDouble().clamp(0.8, 1.4)
          : null,
      autoHide: json['autoHide'] is bool
          ? json['autoHide']! as bool
          : base.autoHide,
      autoHideSeconds: json['autoHideSeconds'] is int
          ? (json['autoHideSeconds']! as int).clamp(2, 60)
          : base.autoHideSeconds,
    );
  }

  static Color? _color(Object? raw) => raw is int ? Color(raw) : null;

  static double _number(Object? raw, double fallback) =>
      raw is num && raw.isFinite ? raw.toDouble() : fallback;

  static T? _enumByName<T extends Enum>(List<T> values, Object? raw) {
    if (raw is! String) return null;
    for (final T value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

const Object _unset = Object();

/// Estilo compacto ya resuelto contra los tokens activos del tema.
@immutable
class ResolvedCompactStyle {
  const ResolvedCompactStyle({
    required this.tokens,
    required this.accent,
    required this.background,
    required this.progressColor,
    required this.volumeColor,
    required this.radius,
    required this.opacity,
    required this.blur,
    required this.glow,
    required this.typography,
    required this.fontFamily,
    required this.autoHide,
    required this.autoHideSeconds,
  });

  final PolarisTokens tokens;
  final Color accent;
  final Color background;
  final Color progressColor;
  final Color volumeColor;
  final double radius;
  final double opacity;
  final double blur;
  final bool glow;

  /// Tipografía efectiva de la superficie (heredada o propia).
  final TypographyConfig typography;

  /// Familia resultante; `null` significa fuente del sistema.
  final String? fontFamily;

  final bool autoHide;
  final int autoHideSeconds;
}

/// Utilidades compartidas para aplicar la forma de carátula elegida en cada
/// superficie compacta sin duplicar switches en los widgets.
extension ResolvedCompactArtwork on ResolvedCompactStyle {
  bool get isVinyl => tokens.artworkShape == ArtworkShape.circleVinyl;

  double artworkRadius(double base) => switch (tokens.artworkShape) {
    ArtworkShape.circleVinyl => 100000,
    ArtworkShape.card3D => base * 1.6,
    ArtworkShape.squareRounded => base,
  };
}

extension CompactStyleResolver on CompactStyleConfig {
  ResolvedCompactStyle resolve(PolarisTokens tokens) {
    final Color accent = this.accent ?? tokens.accent;
    final Color background = this.background ?? tokens.background;
    final TypographyConfig global =
        tokens.typography ?? TypographyConfig.defaults;
    final String familyId = fontFamilyId ?? global.familyId;
    final TypographyConfig effective = global.copyWith(
      familyId: familyId,
      scale: fontScale ?? global.scale,
    );
    final String? family = resolveFontFamily(familyId);
    final SurfaceFinish finish = tokens.finish;
    final CardStyle effectiveCardStyle = finish == SurfaceFinish.matte
        ? CardStyle.flatMinimal
        : cardStyle;
    final PolarisTokens local = tokens.copyWith(
      accent: accent,
      background: background,
      surface: background,
      panelRadius: cornerRadius,
      glassOpacity: opacity,
      glassBlur: blur,
      cardStyle: effectiveCardStyle,
      finish: finish,
      secondary: tokens.secondary,
      surfaceOpacity: tokens.surfaceOpacity,
      brightness: tokens.brightness,
      borderColor: accent.withValues(alpha: 0.26),
      typography: effective,
      artworkShape: artworkShape,
    );
    return ResolvedCompactStyle(
      tokens: local,
      typography: effective,
      fontFamily: family,
      accent: accent,
      background: background,
      progressColor: progressColor ?? accent,
      volumeColor: volumeColor ?? accent,
      radius: cornerRadius,
      opacity: opacity,
      blur: blur,
      glow: glow,
      autoHide: autoHide,
      autoHideSeconds: autoHideSeconds,
    );
  }
}
