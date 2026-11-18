import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Color en espacio HSV (también llamado HSB) con opacidad.
///
/// * [h] tono en grados `[0, 360)`.
/// * [s], [v] y [a] en el rango `[0, 1]`.
///
/// Se usa en el editor de color porque tono, saturación y valor son
/// independientes entre sí, a diferencia de RGB. `copyWith` permite construir
/// un color nuevo sin mutar el original.
@immutable
class HsvColor {
  const HsvColor({
    required this.h,
    required this.s,
    required this.v,
    this.a = 1,
  });

  final double h;
  final double s;
  final double v;
  final double a;

  factory HsvColor.fromColor(Color color) {
    final double r = color.r;
    final double g = color.g;
    final double b = color.b;
    final double max = math.max(r, math.max(g, b));
    final double min = math.min(r, math.min(g, b));
    final double delta = max - min;

    double hue = 0;
    if (delta != 0) {
      if (max == r) {
        hue = 60 * (((g - b) / delta) % 6);
      } else if (max == g) {
        hue = 60 * ((b - r) / delta + 2);
      } else {
        hue = 60 * ((r - g) / delta + 4);
      }
    }
    if (hue < 0) hue += 360;

    return HsvColor(h: hue, s: max == 0 ? 0 : delta / max, v: max, a: color.a);
  }

  Color toColor() {
    final double c = v * s;
    final double hp = (h % 360) / 60;
    final double x = c * (1 - (hp % 2 - 1).abs());
    final double m = v - c;

    final double r;
    final double g;
    final double b;
    if (hp < 1) {
      r = c;
      g = x;
      b = 0;
    } else if (hp < 2) {
      r = x;
      g = c;
      b = 0;
    } else if (hp < 3) {
      r = 0;
      g = c;
      b = x;
    } else if (hp < 4) {
      r = 0;
      g = x;
      b = c;
    } else if (hp < 5) {
      r = x;
      g = 0;
      b = c;
    } else {
      r = c;
      g = 0;
      b = x;
    }

    return Color.fromRGBO(
      _clampByte((r + m) * 255),
      _clampByte((g + m) * 255),
      _clampByte((b + m) * 255),
      a.clamp(0, 1),
    );
  }

  HsvColor copyWith({double? h, double? s, double? v, double? a}) =>
      HsvColor(h: h ?? this.h, s: s ?? this.s, v: v ?? this.v, a: a ?? this.a);

  static int _clampByte(double value) => value.round().clamp(0, 255).toInt();

  @override
  bool operator ==(Object other) =>
      other is HsvColor &&
      other.h == h &&
      other.s == s &&
      other.v == v &&
      other.a == a;

  @override
  int get hashCode => Object.hash(h, s, v, a);
}

/// Utilidades para convertir y formatear colores en la UI de personalización.
class ColorMath {
  const ColorMath._();

  /// Normaliza cualquier longitud de HEX (`#RGB`, `#RRGGBB`, `#AARRGGBB` o
  /// `#RRGGBBAA`) a un [Color] con alfa. Devuelve `null` si no es válido.
  static Color? tryParseHex(String input) {
    String hex = input.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.isEmpty) return null;

    if (hex.length == 3) {
      hex = hex.split('').map((String c) => '$c$c').join();
    }
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length == 8) {
      final int? value = int.tryParse(hex, radix: 16);
      if (value == null) return null;
      return Color(value);
    }
    return null;
  }

  /// Devuelve el HEX con alfa (`#AARRGGBB`) o sin él (`#RRGGBB`).
  static String toHex(Color color, {bool withAlpha = false}) {
    final String value = color
        .toARGB32()
        .toRadixString(16)
        .toUpperCase()
        .padLeft(8, '0');
    return withAlpha ? '#$value' : '#${value.substring(2)}';
  }

  /// Color de texto legible sobre [background].
  static Color onColor(Color background) {
    final double luminance =
        background.r * 0.299 + background.g * 0.587 + background.b * 0.114;
    return luminance > 0.58 ? const Color(0xFF0B0B12) : const Color(0xFFFFFFFF);
  }

  /// Mezcla lineal simple, usada para derivar degradados del color base.
  static Color lerp(Color a, Color b, double t) => Color.lerp(a, b, t)!;
}
