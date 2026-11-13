import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Extrae un color dominante de una carátula.
///
/// Técnica: se decodifica la imagen a 48px de ancho (barato), se recorren los
/// píxeles ponderando saturación y se evita el negro/blanco puro para que el
/// color resultante sirva como acento. Base para el fondo dinámico de la Fase 2.
class PaletteExtractor {
  PaletteExtractor._();

  static const Color fallback = Color(0xFF8B5CF6);

  static Future<Color> fromFile(String? path) async {
    if (path == null || path.isEmpty) return fallback;
    try {
      final File file = File(path);
      if (!await file.exists()) return fallback;
      final Color extracted = await fromBytes(await file.readAsBytes());
      return extracted;
    } catch (_) {
      return fallback;
    }
  }

  static Future<Color> fromBytes(Uint8List bytes) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 48,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ByteData? data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      frame.image.dispose();
      codec.dispose();
      if (data == null) return fallback;

      double r = 0;
      double g = 0;
      double b = 0;
      double weightSum = 0;

      for (int i = 0; i < data.lengthInBytes; i += 4) {
        final int alpha = data.getUint8(i + 3);
        if (alpha < 128) continue;
        final int ri = data.getUint8(i);
        final int gi = data.getUint8(i + 1);
        final int bi = data.getUint8(i + 2);

        final double maxC = math.max(ri, math.max(gi, bi)).toDouble();
        final double minC = math.min(ri, math.min(gi, bi)).toDouble();
        final double saturation = maxC == 0 ? 0 : (maxC - minC) / maxC;
        final double luminance = (0.299 * ri + 0.587 * gi + 0.114 * bi) / 255;

        // Peso: colores con saturación media/alta y luminancia intermedia.
        final double weight =
            (0.15 + saturation) * (1 - (luminance - 0.5).abs());
        r += ri * weight;
        g += gi * weight;
        b += bi * weight;
        weightSum += weight;
      }

      if (weightSum == 0) return fallback;
      Color color = Color.fromARGB(
        255,
        (r / weightSum).round().clamp(0, 255),
        (g / weightSum).round().clamp(0, 255),
        (b / weightSum).round().clamp(0, 255),
      );
      // Garantiza legibilidad sobre fondos oscuros.
      final HSLColor hsl = HSLColor.fromColor(color);
      color = hsl
          .withSaturation(hsl.saturation.clamp(0.35, 0.85))
          .withLightness(hsl.lightness.clamp(0.35, 0.62))
          .toColor();
      return color;
    } catch (_) {
      return fallback;
    }
  }
}
