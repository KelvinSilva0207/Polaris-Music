import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../models/equalizer_config.dart';

/// Cálculo de la respuesta en frecuencia de la cadena del ecualizador.
///
/// Reproduce con biquads digitales (RBJ) los mismos filtros que la cadena
/// `lavfi` envía a libmpv. Además de dibujar la curva, sirve para estimar el
/// pico de ganancia y derivar la compensación del anti-clip sin leer audio.
class FrequencyResponse {
  FrequencyResponse._();

  static const double minHz = 20;
  static const double maxHz = 20000;
  static const double sampleRate = AppConstants.dspSampleRate;

  /// Número de muestras logarítmicas usadas para buscar el pico.
  static const int peakSamples = 128;

  /// Respuesta total en dB a una frecuencia dada.
  static double dbAt({
    required double frequencyHz,
    required EqualizerConfig config,
    bool includePreamp = true,
  }) {
    final double f = frequencyHz.clamp(minHz, maxHz).toDouble();
    double db = includePreamp ? config.preampDb : 0;

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

  /// Ganancia máxima de la curva en dB, sin contar el preamplificador.
  ///
  /// Se evalúa en una rejilla logarítmica fija: es determinista, no depende de
  /// la pista y cuesta lo mismo tanto con 2 bandas como con 31. El valor se
  /// usa para bajar la ganancia antes del limitador cuando hay procesamiento.
  static double peakDb(EqualizerConfig config, {bool includePreamp = false}) {
    double peak = double.negativeInfinity;
    for (int i = 0; i < peakSamples; i++) {
      final double t = i / (peakSamples - 1);
      final double hz = minHz * math.pow(maxHz / minHz, t).toDouble();
      final double db = dbAt(
        frequencyHz: hz,
        config: config,
        includePreamp: includePreamp,
      );
      if (db > peak) peak = db;
    }
    return peak.isFinite ? peak : 0;
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
        // La cadena usa `bass`/`treble` con `t=q`: FFmpeg calcula
        // alpha = sin(w0)/(2·Q) y, para esos dos filtros, beta = sqrt(2·A).
        // Usar pendiente S (o el beta de `lowshelf`) hacía que la curva no
        // coincidiera con el audio: un Q bajo parecía plano en la UI pero sí
        // ensanchaba el filtro.
        final double beta = math.sqrt(2 * a) * alpha;
        return _Biquad(
          a * ((a + 1) - (a - 1) * cw + beta),
          2 * a * ((a - 1) - (a + 1) * cw),
          a * ((a + 1) - (a - 1) * cw - beta),
          (a + 1) + (a - 1) * cw + beta,
          -2 * ((a - 1) + (a + 1) * cw),
          (a + 1) + (a - 1) * cw - beta,
        );
      case ParametricFilterType.highShelf:
        final double a = math.pow(10, gain / 40).toDouble();
        final double beta = math.sqrt(2 * a) * alpha;
        return _Biquad(
          a * ((a + 1) + (a - 1) * cw + beta),
          -2 * a * ((a - 1) + (a + 1) * cw),
          a * ((a + 1) + (a - 1) * cw - beta),
          (a + 1) - (a - 1) * cw + beta,
          2 * ((a - 1) - (a + 1) * cw),
          (a + 1) - (a - 1) * cw - beta,
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
