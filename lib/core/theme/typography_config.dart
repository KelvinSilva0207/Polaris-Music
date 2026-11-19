import 'package:flutter/material.dart';

import 'font_catalog.dart';

/// Configuración tipográfica global persistida en `ui.typography`.
@immutable
class TypographyConfig {
  const TypographyConfig({
    this.familyId = fontIdPolarisSans,
    this.scale = 1,
    this.headlineWeight = 700,
    this.metadataWeight = 500,
    this.lyricsWeight = 600,
  });

  static const TypographyConfig defaults = TypographyConfig();

  final String familyId;
  final double scale;
  final int headlineWeight;
  final int metadataWeight;
  final int lyricsWeight;

  FontWeight get headline => _fontWeight(headlineWeight);
  FontWeight get metadata => _fontWeight(metadataWeight);
  FontWeight get lyrics => _fontWeight(lyricsWeight);

  static FontWeight _fontWeight(int value) {
    final int step = (value.clamp(100, 900).toInt() - 100) ~/ 100;
    return FontWeight.values[step.clamp(0, 8)];
  }

  TypographyConfig copyWith({
    String? familyId,
    double? scale,
    int? headlineWeight,
    int? metadataWeight,
    int? lyricsWeight,
  }) => TypographyConfig(
    familyId: familyId ?? this.familyId,
    scale: scale ?? this.scale,
    headlineWeight: headlineWeight ?? this.headlineWeight,
    metadataWeight: metadataWeight ?? this.metadataWeight,
    lyricsWeight: lyricsWeight ?? this.lyricsWeight,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'familyId': familyId,
    'scale': scale,
    'headlineWeight': headlineWeight,
    'metadataWeight': metadataWeight,
    'lyricsWeight': lyricsWeight,
  };

  factory TypographyConfig.fromJson(Map<String, Object?> json) {
    final TypographyConfig base = defaults;
    return TypographyConfig(
      familyId: json['familyId'] is String
          ? json['familyId']! as String
          : base.familyId,
      scale: _number(json['scale'], base.scale).clamp(0.80, 1.40),
      headlineWeight: _weight(json['headlineWeight'], base.headlineWeight),
      metadataWeight: _weight(json['metadataWeight'], base.metadataWeight),
      lyricsWeight: _weight(json['lyricsWeight'], base.lyricsWeight),
    );
  }

  static double _number(Object? raw, double fallback) =>
      raw is num && raw.isFinite ? raw.toDouble() : fallback;

  static int _weight(Object? raw, int fallback) =>
      raw is num && raw.isFinite ? raw.toInt().clamp(100, 900) : fallback;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypographyConfig &&
          other.familyId == familyId &&
          other.scale == scale &&
          other.headlineWeight == headlineWeight &&
          other.metadataWeight == metadataWeight &&
          other.lyricsWeight == lyricsWeight;

  @override
  int get hashCode => Object.hash(
    familyId,
    scale,
    headlineWeight,
    metadataWeight,
    lyricsWeight,
  );
}

/// Tipografía ya resuelta contra el registro de fuentes cargadas.
@immutable
class ResolvedTypography {
  const ResolvedTypography(this.config, this.family);

  final TypographyConfig config;

  /// `null` selecciona explícitamente la fuente del sistema.
  final String? family;
}
