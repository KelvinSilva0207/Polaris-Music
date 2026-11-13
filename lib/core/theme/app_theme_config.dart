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

  static const AppThemeConfig polarisVioletGlass = AppThemeConfig(
    preset: AppThemePreset.polarisVioletGlass,
    cardStyle: CardStyle.glassmorphic,
    artworkShape: ArtworkShape.circleVinyl,
    progressBarType: ProgressBarType.linearClassic,
    paletteMode: ColorPaletteMode.fixedPreset,
    accent: Color(0xFF8B5CF6),
    background: Color(0xFF0B0710),
    surface: Color(0xFF171126),
    backdrop: <Color>[Color(0xFF180E2E), Color(0xFF0B0710), Color(0xFF2A1450)],
  );

  static const AppThemeConfig monolithMinimal = AppThemeConfig(
    preset: AppThemePreset.monolithMinimal,
    cardStyle: CardStyle.flatMinimal,
    artworkShape: ArtworkShape.squareRounded,
    progressBarType: ProgressBarType.waveform,
    paletteMode: ColorPaletteMode.fixedPreset,
    accent: Color(0xFFE4E4E7),
    background: Color(0xFF0E0E10),
    surface: Color(0xFF1A1A1D),
    backdrop: <Color>[Color(0xFF151517), Color(0xFF0E0E10), Color(0xFF202024)],
  );

  static const AppThemeConfig bronzeVinyl = AppThemeConfig(
    preset: AppThemePreset.bronzeVinyl,
    cardStyle: CardStyle.neumorphic,
    artworkShape: ArtworkShape.circleVinyl,
    progressBarType: ProgressBarType.circularAroundArtwork,
    paletteMode: ColorPaletteMode.fixedPreset,
    accent: Color(0xFFC98B4B),
    background: Color(0xFF161210),
    surface: Color(0xFF241C16),
    backdrop: <Color>[Color(0xFF2B1D13), Color(0xFF161210), Color(0xFF3B2A1A)],
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
          listEquals(backdrop, other.backdrop);

  @override
  int get hashCode => Object.hash(
    preset,
    cardStyle,
    artworkShape,
    progressBarType,
    paletteMode,
    accent,
    background,
    surface,
    Object.hashAll(backdrop),
  );

  static T? _enumByName<T extends Enum>(List<T> values, Object? raw) {
    if (raw is! String) return null;
    for (final T value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }

  static Color _color(Object? raw, Color fallback) =>
      raw is int ? Color(raw) : fallback;
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
