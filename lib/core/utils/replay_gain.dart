import 'dart:math' as math;

/// Utilidades de ReplayGain.
///
/// ReplayGain se expresa en dB respecto a un objetivo de -18 LUFS (o -14 en
/// algunos servicios). Convertimos la ganancia a un factor lineal que se aplica
/// sobre el volumen del usuario.
class ReplayGain {
  ReplayGain._();

  /// Convierte dB a factor lineal: `10^(db/20)`.
  static double dbToLinear(double db) => math.pow(10, db / 20).toDouble();

  /// Volumen efectivo (0..100 para media_kit) aplicando la ganancia.
  ///
  /// [baseVolume] va de 0 a 1. Se recorta a [minPercent]..[maxPercent] para
  /// evitar silencios o distorsión por clipping.
  static double effectiveVolume({
    required double baseVolume,
    double? gainDb,
    double minPercent = 0,
    double maxPercent = 100,
  }) {
    if (gainDb == null || gainDb.isNaN || gainDb.isInfinite) {
      return (baseVolume * 100).clamp(minPercent, maxPercent);
    }
    final double factor = dbToLinear(gainDb);
    return (baseVolume * factor * 100).clamp(minPercent, maxPercent);
  }

  /// Interpreta etiquetas tipo `-7.50 dB`, `+2.1dB` o `-7.50`.
  static double? parseTag(String? raw) {
    if (raw == null) return null;
    final RegExpMatch? match = RegExp(r'([+-]?\d+(?:[.,]\d+)?)')
        .firstMatch(raw);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  /// Ganancia preferida: pista, con fallback a álbum.
  static double? preferred({
    double? trackGainDb,
    double? albumGainDb,
    bool preferAlbum = false,
  }) {
    if (preferAlbum) return albumGainDb ?? trackGainDb;
    return trackGainDb ?? albumGainDb;
  }
}
