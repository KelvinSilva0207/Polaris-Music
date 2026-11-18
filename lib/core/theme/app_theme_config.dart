import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Estilo de los contenedores (tarjetas, paneles y hojas).
enum CardStyle {
  glassmorphic('Glass', 'Vidrio translúcido con desenfoque y bordes suaves'),
  neumorphic('Neumorphism', 'Relieve 3D con sombras duales claras y oscuras'),
  flatMinimal('Flat', 'Tarjetas planas y limpias con bordes redondeados');

  const CardStyle(this.label, this.description);

  final String label;
  final String description;
}

/// Forma de la carátula en la pantalla de reproducción.
enum ArtworkShape {
  squareRounded('Cuadrada', 'Esquinas suaves, estilo tarjeta moderna'),
  circleVinyl('Vinilo', 'Círculo perfecto que gira mientras suena la música'),
  card3D('Tarjeta 3D', 'Perspectiva y profundidad con sombras dinámicas');

  const ArtworkShape(this.label, this.description);

  final String label;
  final String description;
}

/// Tipo de barra de progreso del reproductor.
enum ProgressBarType {
  linearClassic('Lineal', 'Barra clásica con tiempos a los lados'),
  waveform('Onda', 'Forma de onda de audio interactiva'),
  circularAroundArtwork(
    'Circular',
    'Anillo de progreso alrededor de la carátula',
  );

  const ProgressBarType(this.label, this.description);

  final String label;
  final String description;
}

/// Origen de los colores del fondo y del acento.
enum ColorPaletteMode {
  dynamicArtwork('Dinámico', 'Extrae la paleta de la carátula actual'),
  fixedPreset('Fijo', 'Usa los colores del preset o perfil activo');

  const ColorPaletteMode(this.label, this.description);

  final String label;
  final String description;
}

/// Elemento editable por el motor de color RGB/HSV/HEX.
///
/// Cada objetivo se edita de forma independiente en Personalización. Los
/// degradados tienen tres paradas editables (la tercera solo aparece en los
/// presets que la usan).
enum ThemeColorTarget {
  background('Fondo principal', 'Color base de la aplicación'),
  backdropStart('Degradado · inicio', 'Primera parada del fondo dinámico'),
  backdropMiddle('Degradado · centro', 'Segunda parada del fondo dinámico'),
  backdropEnd('Degradado · final', 'Última parada del fondo dinámico'),
  accent('Acento primario', 'Botones, indicadores e iconos activos'),
  surface('Contenedores y tarjetas', 'Color base de las superficies'),
  progress('Barra de progreso', 'Progreso de la canción'),
  volume('Barra de volumen', 'Nivel de volumen y altavoz'),
  karaoke('Letra activa', 'Resaltado de la línea de karaoke'),
  border('Bordes', 'Borde de paneles y tarjetas'),
  shadow('Sombras', 'Sombras proyectadas por los paneles'),
  neumorphicLight('Relieve claro', 'Luz del estilo neumórfico'),
  neumorphicDark('Relieve oscuro', 'Sombra del estilo neumórfico');

  const ThemeColorTarget(this.label, this.description);

  final String label;
  final String description;
}

/// Perfiles visuales incluidos con Polaris.
enum AppThemePreset {
  polarisVioletGlass(
    'Polaris Violet Glass',
    'Violeta profundo, vidrio intenso y carátula circular con resplandor.',
  ),
  monolithMinimal(
    'Monolith Minimal',
    'Carbón mate, tarjetas sutiles y onda de audio minimalista.',
  ),
  bronzeVinyl(
    'Bronze Vinyl & Warm Dark',
    'Bronce cálido, vinilo giratorio y progreso circular envolvente.',
  ),
  custom(
    'Personalizado',
    'Configuración creada por ti y guardada en tu equipo.',
  );

  const AppThemePreset(this.label, this.description);

  final String label;
  final String description;
}

/// Configuración visual completa de la aplicación.
///
/// Es inmutable y serializable: se persiste como JSON en la tabla `settings`
/// de Drift, de modo que el tema sobrevive al reinicio sin depender de la UI.
@immutable
class AppThemeConfig {
  const AppThemeConfig({
    required this.preset,
    required this.cardStyle,
    required this.artworkShape,
    required this.progressBarType,
    required this.paletteMode,
    required this.accent,
    required this.background,
    required this.surface,
    required this.backdrop,
    this.panelRadius = 18,
    this.artworkRadius = 24,
    this.glassBlur = 24,
    this.glassOpacity = 0.10,
    this.progressColor = const Color(0xFF8B5CF6),
    this.volumeColor = const Color(0xFF8B5CF6),
    this.karaokeColor = const Color(0xFF8B5CF6),
    this.borderColor = const Color(0x1AFFFFFF),
    this.shadowColor = const Color(0xFF000000),
    this.shadowOpacity = 0.28,
    this.neumorphicLight = const Color(0xFF2A2A2A),
    this.neumorphicDark = const Color(0xFF000000),
  });

  final AppThemePreset preset;
  final CardStyle cardStyle;
  final ArtworkShape artworkShape;
  final ProgressBarType progressBarType;
  final ColorPaletteMode paletteMode;
  final Color accent;
  final Color background;
  final Color surface;

  /// Colores del degradado de fondo, de arriba-izquierda a abajo-derecha.
  final List<Color> backdrop;

  /// Radio compartido por paneles, tarjetas y hojas.
  final double panelRadius;

  /// Radio de la carátula cuando su forma es [ArtworkShape.squareRounded]
  /// o [ArtworkShape.card3D].
  final double artworkRadius;

  /// Intensidad del desenfoque de los paneles de vidrio.
  final double glassBlur;

  /// Opacidad de las tarjetas con estilo [CardStyle.glassmorphic].
  /// `1` es totalmente opaco y `0` completamente transparente.
  final double glassOpacity;

  /// Color dedicado al progreso musical (independiente del acento).
  final Color progressColor;

  /// Color dedicado al control de volumen (independiente del acento).
  final Color volumeColor;

  /// Color de la línea activa del karaoke.
  final Color karaokeColor;

  /// Borde de los paneles. Violet Glass usa blanco al 10 % de opacidad.
  final Color borderColor;

  /// Color base de las sombras del preset y su opacidad.
  final Color shadowColor;
  final double shadowOpacity;

  /// Luces y sombras del relieve neumórfico.
  final Color neumorphicLight;
  final Color neumorphicDark;

  static const AppThemeConfig polarisVioletGlass = AppThemeConfig(
    preset: AppThemePreset.polarisVioletGlass,
    cardStyle: CardStyle.glassmorphic,
    artworkShape: ArtworkShape.squareRounded,
    progressBarType: ProgressBarType.linearClassic,
    paletteMode: ColorPaletteMode.fixedPreset,
    accent: Color(0xFF8B5CF6),
    background: Color(0xFF0D0515),
    surface: Color(0xFF1A0B2A),
    backdrop: <Color>[Color(0xFF1A0B2A), Color(0xFF0D0515)],
    panelRadius: 28,
    artworkRadius: 32,
    glassBlur: 20,
    glassOpacity: 0.10,
    progressColor: Color(0xFF8B5CF6),
    volumeColor: Color(0xFF8B5CF6),
    karaokeColor: Color(0xFF8B5CF6),
    borderColor: Color(0x1AFFFFFF),
    shadowColor: Color(0xFF000000),
    shadowOpacity: 0.30,
    neumorphicLight: Color(0xFF3A2A52),
    neumorphicDark: Color(0xFF050208),
  );

  static const AppThemeConfig monolithMinimal = AppThemeConfig(
    preset: AppThemePreset.monolithMinimal,
    cardStyle: CardStyle.flatMinimal,
    artworkShape: ArtworkShape.squareRounded,
    progressBarType: ProgressBarType.waveform,
    paletteMode: ColorPaletteMode.fixedPreset,
    accent: Color(0xFF39FF14),
    background: Color(0xFF121212),
    surface: Color(0xFF1A1A1A),
    backdrop: <Color>[Color(0xFF1E1E1E), Color(0xFF121212), Color(0xFF0A0A0A)],
    panelRadius: 16,
    artworkRadius: 16,
    glassBlur: 18,
    glassOpacity: 0.08,
    progressColor: Color(0xFF39FF14),
    volumeColor: Color(0xFF39FF14),
    karaokeColor: Color(0xFF39FF14),
    borderColor: Color(0x12FFFFFF),
    shadowColor: Color(0xFF050505),
    shadowOpacity: 0.18,
    neumorphicLight: Color(0xFF2A2A2A),
    neumorphicDark: Color(0xFF050505),
  );

  static const AppThemeConfig bronzeVinyl = AppThemeConfig(
    preset: AppThemePreset.bronzeVinyl,
    cardStyle: CardStyle.neumorphic,
    artworkShape: ArtworkShape.circleVinyl,
    progressBarType: ProgressBarType.circularAroundArtwork,
    paletteMode: ColorPaletteMode.fixedPreset,
    accent: Color(0xFFD4A76A),
    background: Color(0xFF1F1F1F),
    surface: Color(0xFF242424),
    backdrop: <Color>[Color(0xFF2A2A2A), Color(0xFF1F1F1F), Color(0xFF141414)],
    panelRadius: 22,
    artworkRadius: 22,
    glassBlur: 18,
    glassOpacity: 0.08,
    progressColor: Color(0xFFD4A76A),
    volumeColor: Color(0xFFD4A76A),
    karaokeColor: Color(0xFFD4A76A),
    borderColor: Color(0x0DFFFFFF),
    shadowColor: Color(0xFF000000),
    shadowOpacity: 0.90,
    neumorphicLight: Color(0xFF2A2A2A),
    neumorphicDark: Color(0xFF000000),
  );

  /// Configuración usada la primera vez que se abre la app.
  static const AppThemeConfig defaults = polarisVioletGlass;

  /// Devuelve una copia con preset y valores del perfil base solicitado.
  factory AppThemeConfig.fromPreset(AppThemePreset preset) {
    return switch (preset) {
      AppThemePreset.polarisVioletGlass => polarisVioletGlass,
      AppThemePreset.monolithMinimal => monolithMinimal,
      AppThemePreset.bronzeVinyl => bronzeVinyl,
      AppThemePreset.custom => polarisVioletGlass,
    };
  }

  /// Todos los presets aplicables con un toque (sin el modo personalizado).
  static const List<AppThemeConfig> builtInPresets = <AppThemeConfig>[
    polarisVioletGlass,
    monolithMinimal,
    bronzeVinyl,
  ];

  bool get isGlass => cardStyle == CardStyle.glassmorphic;

  bool get usesDynamicPalette => paletteMode == ColorPaletteMode.dynamicArtwork;

  /// Color actual de un objetivo editable. Los tres degradados se leen del
  /// array `backdrop`, usando el primero como fallback si no hay más paradas.
  Color colorFor(ThemeColorTarget target) => switch (target) {
    ThemeColorTarget.background => background,
    ThemeColorTarget.backdropStart => backdrop.first,
    ThemeColorTarget.backdropMiddle =>
      backdrop.length > 1 ? backdrop[1] : backdrop.first,
    ThemeColorTarget.backdropEnd =>
      backdrop.length > 2 ? backdrop[2] : backdrop.last,
    ThemeColorTarget.accent => accent,
    ThemeColorTarget.surface => surface,
    ThemeColorTarget.progress => progressColor,
    ThemeColorTarget.volume => volumeColor,
    ThemeColorTarget.karaoke => karaokeColor,
    ThemeColorTarget.border => borderColor,
    ThemeColorTarget.shadow => shadowColor,
    ThemeColorTarget.neumorphicLight => neumorphicLight,
    ThemeColorTarget.neumorphicDark => neumorphicDark,
  };

  /// Devuelve una copia con el objetivo indicado cambiado. El resultado se
  /// marca como personalizado desde el controlador (no aquí) para que los
  /// setters que coinciden con un preset sigan siendo detectados por `_touch`.
  AppThemeConfig withColor(ThemeColorTarget target, Color color) {
    switch (target) {
      case ThemeColorTarget.background:
        return copyWith(background: color);
      case ThemeColorTarget.backdropStart:
      case ThemeColorTarget.backdropMiddle:
      case ThemeColorTarget.backdropEnd:
        final int index = switch (target) {
          ThemeColorTarget.backdropStart => 0,
          ThemeColorTarget.backdropMiddle => 1,
          _ => 2,
        };
        final List<Color> next = List<Color>.from(backdrop);
        if (index >= next.length) {
          next.addAll(List<Color>.filled(index + 1 - next.length, color));
        } else {
          next[index] = color;
        }
        return copyWith(backdrop: next);
      case ThemeColorTarget.accent:
        return copyWith(accent: color);
      case ThemeColorTarget.surface:
        return copyWith(surface: color);
      case ThemeColorTarget.progress:
        return copyWith(progressColor: color);
      case ThemeColorTarget.volume:
        return copyWith(volumeColor: color);
      case ThemeColorTarget.karaoke:
        return copyWith(karaokeColor: color);
      case ThemeColorTarget.border:
        return copyWith(borderColor: color);
      case ThemeColorTarget.shadow:
        return copyWith(shadowColor: color);
      case ThemeColorTarget.neumorphicLight:
        return copyWith(neumorphicLight: color);
      case ThemeColorTarget.neumorphicDark:
        return copyWith(neumorphicDark: color);
    }
  }

  AppThemeConfig copyWith({
    AppThemePreset? preset,
    CardStyle? cardStyle,
    ArtworkShape? artworkShape,
    ProgressBarType? progressBarType,
    ColorPaletteMode? paletteMode,
    Color? accent,
    Color? background,
    Color? surface,
    List<Color>? backdrop,
    double? panelRadius,
    double? artworkRadius,
    double? glassBlur,
    double? glassOpacity,
    Color? progressColor,
    Color? volumeColor,
    Color? karaokeColor,
    Color? borderColor,
    Color? shadowColor,
    double? shadowOpacity,
    Color? neumorphicLight,
    Color? neumorphicDark,
  }) {
    return AppThemeConfig(
      preset: preset ?? this.preset,
      cardStyle: cardStyle ?? this.cardStyle,
      artworkShape: artworkShape ?? this.artworkShape,
      progressBarType: progressBarType ?? this.progressBarType,
      paletteMode: paletteMode ?? this.paletteMode,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      backdrop: backdrop ?? this.backdrop,
      panelRadius: panelRadius ?? this.panelRadius,
      artworkRadius: artworkRadius ?? this.artworkRadius,
      glassBlur: glassBlur ?? this.glassBlur,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      progressColor: progressColor ?? this.progressColor,
      volumeColor: volumeColor ?? this.volumeColor,
      karaokeColor: karaokeColor ?? this.karaokeColor,
      borderColor: borderColor ?? this.borderColor,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowOpacity: shadowOpacity ?? this.shadowOpacity,
      neumorphicLight: neumorphicLight ?? this.neumorphicLight,
      neumorphicDark: neumorphicDark ?? this.neumorphicDark,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'preset': preset.name,
    'cardStyle': cardStyle.name,
    'artworkShape': artworkShape.name,
    'progressBarType': progressBarType.name,
    'paletteMode': paletteMode.name,
    'accent': accent.toARGB32(),
    'background': background.toARGB32(),
    'surface': surface.toARGB32(),
    'backdrop': backdrop.map((Color color) => color.toARGB32()).toList(),
    'panelRadius': panelRadius,
    'artworkRadius': artworkRadius,
    'glassBlur': glassBlur,
    'glassOpacity': glassOpacity,
    'progressColor': progressColor.toARGB32(),
    'volumeColor': volumeColor.toARGB32(),
    'karaokeColor': karaokeColor.toARGB32(),
    'borderColor': borderColor.toARGB32(),
    'shadowColor': shadowColor.toARGB32(),
    'shadowOpacity': shadowOpacity,
    'neumorphicLight': neumorphicLight.toARGB32(),
    'neumorphicDark': neumorphicDark.toARGB32(),
  };

  factory AppThemeConfig.fromJson(Map<String, Object?> json) {
    final AppThemePreset preset =
        _enumByName(AppThemePreset.values, json['preset']) ??
        AppThemePreset.custom;
    final AppThemeConfig base = preset == AppThemePreset.custom
        ? defaults
        : AppThemeConfig.fromPreset(preset);
    final List<Color>? backdrop = (json['backdrop'] as List<Object?>?)
        ?.whereType<int>()
        .map(Color.new)
        .toList(growable: false);

    return AppThemeConfig(
      preset: preset,
      cardStyle:
          _enumByName(CardStyle.values, json['cardStyle']) ?? base.cardStyle,
      artworkShape:
          _enumByName(ArtworkShape.values, json['artworkShape']) ??
          base.artworkShape,
      progressBarType:
          _enumByName(ProgressBarType.values, json['progressBarType']) ??
          base.progressBarType,
      paletteMode:
          _enumByName(ColorPaletteMode.values, json['paletteMode']) ??
          base.paletteMode,
      accent: _color(json['accent'], base.accent),
      background: _color(json['background'], base.background),
      surface: _color(json['surface'], base.surface),
      backdrop: backdrop == null || backdrop.length < 2
          ? base.backdrop
          : backdrop,
      panelRadius: _double(json['panelRadius'], base.panelRadius),
      artworkRadius: _double(json['artworkRadius'], base.artworkRadius),
      glassBlur: _blur(json['glassBlur'], base.glassBlur),
      glassOpacity: _clamp01(
        _double(json['glassOpacity'], base.glassOpacity),
        base.glassOpacity,
      ),
      progressColor: _color(json['progressColor'], base.progressColor),
      volumeColor: _color(json['volumeColor'], base.volumeColor),
      karaokeColor: _color(json['karaokeColor'], base.karaokeColor),
      borderColor: _color(json['borderColor'], base.borderColor),
      shadowColor: _color(json['shadowColor'], base.shadowColor),
      shadowOpacity: _double(json['shadowOpacity'], base.shadowOpacity),
      neumorphicLight: _color(json['neumorphicLight'], base.neumorphicLight),
      neumorphicDark: _color(json['neumorphicDark'], base.neumorphicDark),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppThemeConfig &&
          preset == other.preset &&
          cardStyle == other.cardStyle &&
          artworkShape == other.artworkShape &&
          progressBarType == other.progressBarType &&
          paletteMode == other.paletteMode &&
          accent == other.accent &&
          background == other.background &&
          surface == other.surface &&
          listEquals(backdrop, other.backdrop) &&
          panelRadius == other.panelRadius &&
          artworkRadius == other.artworkRadius &&
          glassBlur == other.glassBlur &&
          glassOpacity == other.glassOpacity &&
          progressColor == other.progressColor &&
          volumeColor == other.volumeColor &&
          karaokeColor == other.karaokeColor &&
          borderColor == other.borderColor &&
          shadowColor == other.shadowColor &&
          shadowOpacity == other.shadowOpacity &&
          neumorphicLight == other.neumorphicLight &&
          neumorphicDark == other.neumorphicDark;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    preset,
    cardStyle,
    artworkShape,
    progressBarType,
    paletteMode,
    accent,
    background,
    surface,
    Object.hashAll(backdrop),
    panelRadius,
    artworkRadius,
    glassBlur,
    glassOpacity,
    progressColor,
    volumeColor,
    karaokeColor,
    borderColor,
    shadowColor,
    shadowOpacity,
    neumorphicLight,
    neumorphicDark,
  ]);

  static T? _enumByName<T extends Enum>(List<T> values, Object? raw) {
    if (raw is! String) return null;
    for (final T value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }

  static Color _color(Object? raw, Color fallback) =>
      raw is int ? Color(raw) : fallback;

  static double _double(Object? raw, double fallback) =>
      raw is num ? raw.toDouble() : fallback;

  static double _clamp01(double value, double fallback) =>
      value.isNaN ? fallback : value.clamp(0.0, 1.0);

  /// El desenfoque se limita a 32: valores superiores no mejoran la lectura y
  /// multiplican el coste del `BackdropFilter` en Windows.
  static double _blur(Object? raw, double fallback) {
    final double value = _double(raw, fallback);
    if (value.isNaN || value < 0) return fallback;
    return value.clamp(0.0, 32.0);
  }
}

/// Perfil personalizado guardado por el usuario.
@immutable
class CustomThemeProfile {
  const CustomThemeProfile({
    required this.id,
    required this.name,
    required this.config,
  });

  final String id;
  final String name;
  final AppThemeConfig config;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'config': config.toJson(),
  };

  factory CustomThemeProfile.fromJson(Map<String, Object?> json) {
    return CustomThemeProfile(
      id:
          (json['id'] as String?) ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: (json['name'] as String?) ?? 'Perfil sin nombre',
      config: AppThemeConfig.fromJson(
        (json['config'] as Map<Object?, Object?>? ?? <Object?, Object?>{})
            .cast<String, Object?>(),
      ),
    );
  }
}

/// Estado expuesto por el [ThemeController].
@immutable
class ThemeState {
  const ThemeState({
    required this.config,
    this.profiles = const <CustomThemeProfile>[],
  });

  final AppThemeConfig config;
  final List<CustomThemeProfile> profiles;

  ThemeState copyWith({
    AppThemeConfig? config,
    List<CustomThemeProfile>? profiles,
  }) => ThemeState(
    config: config ?? this.config,
    profiles: profiles ?? this.profiles,
  );
}
