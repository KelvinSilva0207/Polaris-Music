import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../models/equalizer_config.dart';
import 'equalizer_dsp.dart';

/// Cálculo de la respuesta en frecuencia de la cadena del ecualizador.
///
/// Se usa solo para dibujar la curva de la interfaz: reproduce con biquads
/// digitales (RBJ) los mismos filtros que [EqualizerDsp] envía a libmpv.
class FrequencyResponse {
  FrequencyResponse._();

  static const double minHz = 20;
  static const double maxHz = 20000;
  static const double sampleRate = EqualizerDsp.sampleRate;

  /// Respuesta total en dB a una frecuencia dada.
  static double dbAt({
    required double frequencyHz,
    required EqualizerConfig config,
  }) {
    final double f = frequencyHz.clamp(minHz, maxHz).toDouble();
    double db = config.preampDb;

    if (config.mode == EqMode.parametric) {
      for (final ParametricFilter filter in config.filters) {
        if (!filter.enabled) continue;
        db += _magnitudeDb(f, _coefficients(filter));
      }
    } else {
      final int length = config.bands.length < config.frequencies.length
          ? config.bands.length
          : config.frequencies.length;
      for (int i = 0; i < length; i++) {
        db += _magnitudeDb(
          f,
          _peaking(config.frequencies[i], config.bands[i], 1),
        );
      }
    }

    return db.clamp(AppConstants.eqMinGain * 2, AppConstants.eqMaxGain * 2);
  }

  /// Posición X (0..width) de una frecuencia en escala logarítmica.
  static double xFor(double frequencyHz, double width) =>
      width *
      math.log(frequencyHz.clamp(minHz, maxHz) / minHz) /
      math.log(maxHz / minHz);

  /// Frecuencia correspondiente a una posición X de la curva.
  static double frequencyForX(double x, double width) =>
      minHz * math.pow(maxHz / minHz, (x / width).clamp(0.0, 1.0));

  static _Biquad _coefficients(ParametricFilter filter) {
    final double f0 = filter.frequencyHz.clamp(minHz, maxHz).toDouble();
    final double gain = filter.gainDb.clamp(
      AppConstants.eqMinGain,
      AppConstants.eqMaxGain,
    );
    final double q = filter.q.clamp(AppConstants.eqMinQ, AppConstants.eqMaxQ);
    final double w0 = 2 * math.pi * f0 / sampleRate;
    final double cw = math.cos(w0);
    final double sw = math.sin(w0);
    final double alpha = sw / (2 * q);

    switch (filter.type) {
      case ParametricFilterType.peaking:
        return _peaking(f0, gain, q);
      case ParametricFilterType.lowpass:
        final double b0 = (1 - cw) / 2;
        return _Biquad(b0, 1 - cw, b0, 1 + alpha, -2 * cw, 1 - alpha);
      case ParametricFilterType.highpass:
        final double b0 = (1 + cw) / 2;
        return _Biquad(b0, -(1 + cw), b0, 1 + alpha, -2 * cw, 1 - alpha);
      case ParametricFilterType.lowShelf:
        final double a = math.pow(10, gain / 40).toDouble();
        // En estantes el Q se interpreta como pendiente inversa; se acota a
        // valores que mantienen la raíz real (solo afecta a la curva dibujada).
        final double shelfQ = q.clamp(1, 10);
        final double s = sw / 2 * math.sqrt(2 + (a + 1 / a) * (shelfQ - 1));
        return _Biquad(
          a * ((a + 1) - (a - 1) * cw + 2 * math.sqrt(a) * s),
          2 * a * ((a - 1) - (a + 1) * cw),
          a * ((a + 1) - (a - 1) * cw - 2 * math.sqrt(a) * s),
          (a + 1) + (a - 1) * cw + 2 * math.sqrt(a) * s,
          -2 * ((a - 1) + (a + 1) * cw),
          (a + 1) + (a - 1) * cw - 2 * math.sqrt(a) * s,
        );
      case ParametricFilterType.highShelf:
        final double a = math.pow(10, gain / 40).toDouble();
        final double shelfQ = q.clamp(1, 10);
        final double s = sw / 2 * math.sqrt(2 + (a + 1 / a) * (shelfQ - 1));
        return _Biquad(
          a * ((a + 1) + (a - 1) * cw + 2 * math.sqrt(a) * s),
          -2 * a * ((a - 1) + (a + 1) * cw),
          a * ((a + 1) + (a - 1) * cw - 2 * math.sqrt(a) * s),
          (a + 1) - (a - 1) * cw + 2 * math.sqrt(a) * s,
          2 * ((a - 1) - (a + 1) * cw),
          (a + 1) - (a - 1) * cw - 2 * math.sqrt(a) * s,
        );
    }
  }

  static _Biquad _peaking(double frequencyHz, double gainDb, double q) {
    final double f0 = frequencyHz.clamp(minHz, maxHz).toDouble();
    final double gain = gainDb.clamp(
      AppConstants.eqMinGain,
      AppConstants.eqMaxGain,
    );
    final double safeQ = q <= 0 ? 1 : q;
    final double w0 = 2 * math.pi * f0 / sampleRate;
    final double cw = math.cos(w0);
    final double sw = math.sin(w0);
    final double alpha = sw / (2 * safeQ);
    final double a = math.pow(10, gain / 40).toDouble();
    return _Biquad(
      1 + alpha * a,
      -2 * cw,
      1 - alpha * a,
      1 + alpha / a,
      -2 * cw,
      1 - alpha / a,
    );
  }

  /// |H(e^jw)| en dB evaluando directamente los coeficientes del biquad.
  static double _magnitudeDb(double frequencyHz, _Biquad c) {
    final double w = 2 * math.pi * frequencyHz / sampleRate;
    final double cw = math.cos(w);
    final double sw = math.sin(w);
    final double c2 = math.cos(2 * w);
    final double s2 = math.sin(2 * w);

    final double br = c.b0 + c.b1 * cw + c.b2 * c2;
    final double bi = -(c.b1 * sw + c.b2 * s2);
    final double ar = c.a0 + c.a1 * cw + c.a2 * c2;
    final double ai = -(c.a1 * sw + c.a2 * s2);

    final double magnitudeSq =
        (br * br + bi * bi) / (ar * ar + ai * ai).abs().clamp(1e-12, 1e12);
    return 10 * math.log(magnitudeSq.clamp(1e-12, 1e12)) / math.ln10;
  }
}

@immutable
class _Biquad {
  const _Biquad(this.b0, this.b1, this.b2, this.a0, this.a1, this.a2);

  final double b0;
  final double b1;
  final double b2;
  final double a0;
  final double a1;
  final double a2;
}
