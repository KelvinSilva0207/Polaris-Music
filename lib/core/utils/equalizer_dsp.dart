import 'dart:math' as math;

import '../constants/app_constants.dart';
import '../models/equalizer_config.dart';
import 'frequency_response.dart';

/// Construye la cadena de filtros de audio de libmpv para el ecualizador.
///
/// mpv expone FFmpeg mediante el filtro `lavfi`; dentro de él se combinan el
/// preamplificador (`volume`), las bandas del ecualizador (`equalizer`,
/// `bass`, `treble`, `lowpass`, `highpass`) y, opcionalmente, una rama
/// sub-armónica. Si hay procesamiento, se añaden compensación de ganancia y un
/// limitador suave al final. El resultado se asigna a `af`.
///
/// [pure] corta la cadena antes de cualquier filtro, incluido el limitador: es
/// un bypass temporal, no un borrado de la configuración.
///
/// Es una función pura (sin FFI ni Flutter) para poder probarla sin audio.
class EqualizerDsp {
  EqualizerDsp._();

  /// Ganancia mínima audible para incluir un filtro en la cadena.
  static const double _epsilon = 0.05;

  /// Frecuencia interna a la que se desplaza la rama sub-armónica.
  ///
  /// Se fuerza esta tasa antes y después del cambio de sample rate para no
  /// depender de la frecuencia de la pista: 48 kHz -> 24 kHz (una octava) y
  /// `atempo=2` devuelve la duración original sin recuperar el tono.
  static const double sampleRate = AppConstants.dspSampleRate;

  /// Devuelve `''` cuando no hay procesamiento que aplicar.
  static String buildFilter({
    required bool enabled,
    required List<double> gains,
    List<double>? frequencies,
    double preampDb = 0,
    EqMode mode = EqMode.graphic,
    List<ParametricFilter> filters = const <ParametricFilter>[],
    SubHarmonicSettings sub = const SubHarmonicSettings(),
    bool pure = false,
    bool antiClip = true,
  }) {
    // Modo puro: ni el limitador se inserta. La curva sigue viva en el
    // controlador, así que al salir del modo vuelve exactamente la misma.
    if (!enabled || pure) return '';

    final List<double> safeGains = gains
        .map((double gain) => _finiteGain(gain))
        .toList(growable: false);
    final List<double> hz = frequencies ?? AppConstants.eqBands;
    final double clampedPreamp = preampDb.isFinite ? _clampGain(preampDb) : 0;

    final List<String> chain = <String>[];

    if (mode == EqMode.parametric) {
      for (final ParametricFilter filter in filters) {
        if (!filter.enabled) continue;
        final String? part = _parametricPart(filter);
        if (part != null) chain.add(part);
      }
    } else {
      final int length = safeGains.length < hz.length
          ? safeGains.length
          : hz.length;
      for (int i = 0; i < length; i++) {
        final double gain = safeGains[i];
        if (gain.abs() < _epsilon) continue;
        final String frequency = _formatFrequency(hz[i]);
        chain.add('equalizer=f=$frequency:t=q:w=1:g=${_format(gain)}');
      }
    }

    double subBoostDb = 0;
    if (sub.enabled) {
      final String subGraph = _subGraph(sub);
      if (subGraph.isNotEmpty) {
        chain.add(subGraph);
        final double mix = sub.mix.clamp(
          AppConstants.subMinMix,
          AppConstants.subMaxMix,
        );
        // Peor caso: la rama desplazada se suma en fase con la original.
        subBoostDb = 20 * math.log(1 + mix) / math.ln10;
      }
    }

    // Solo el preamplificador no cuenta como procesamiento: se aplica tal cual
    // y no se le añade limitador (coste CPU innecesario).
    final bool hasProcessing = chain.isNotEmpty;
    if (!hasProcessing && clampedPreamp.abs() < _epsilon) return '';

    if (hasProcessing && antiClip) {
      final double autoDb = antiClipGainDb(
        gains: safeGains,
        frequencies: hz,
        preampDb: clampedPreamp,
        mode: mode,
        filters: filters,
        subBoostDb: subBoostDb,
      );
      final double totalPreamp = clampedPreamp + autoDb;
      if (totalPreamp.abs() >= _epsilon) {
        chain.insert(0, 'volume=${_format(totalPreamp)}dB');
      }
      // Un único limitador para toda la cadena (incluida la rama sub-armónica).
      chain.add('alimiter=limit=0.89:level=0');
    } else if (clampedPreamp.abs() >= _epsilon) {
      chain.insert(0, 'volume=${_format(clampedPreamp)}dB');
    }

    if (chain.isEmpty) return '';
    return 'lavfi=[${chain.join(',')}]';
  }

  /// Atenuación (dB, valor ≤ 0) necesaria para dejar [headroom] por debajo de
  /// 0 dBFS antes del limitador.
  ///
  /// Se calcula sobre la respuesta RBJ de los mismos biquads que se envían a
  /// mpv, más el refuerzo estimado del sub-armónico. Es una operación pura y
  /// barata: se ejecuta al cambiar un filtro, nunca por muestra de audio.
  static double antiClipGainDb({
    required List<double> gains,
    List<double>? frequencies,
    double preampDb = 0,
    EqMode mode = EqMode.graphic,
    List<ParametricFilter> filters = const <ParametricFilter>[],
    double subBoostDb = 0,
    double headroomDb = AppConstants.antiClipHeadroomDb,
  }) {
    final EqualizerConfig config = EqualizerConfig(
      mode: mode,
      frequencies: frequencies ?? AppConstants.eqBands,
      bands: gains
          .map((double gain) => _finiteGain(gain))
          .toList(growable: false),
      filters: filters,
      preampDb: preampDb.isFinite ? _clampGain(preampDb) : 0,
    );
    final double peak =
        FrequencyResponse.peakDb(config, includePreamp: true) + subBoostDb;
    // Sin pico positivo no hay nada que compensar: el margen solo se aplica
    // cuando la curva realmente puede empujar la señal por encima de 0 dBFS.
    final double needed = peak <= 0
        ? 0
        : (peak + headroomDb).clamp(0, AppConstants.antiClipMaxAttenuationDb);
    return -needed.toDouble();
  }

  /// Traduce un filtro paramétrico a su equivalente en FFmpeg.
  static String? _parametricPart(ParametricFilter filter) {
    final double frequency = filter.frequencyHz;
    if (!frequency.isFinite ||
        frequency < AppConstants.eqMinFrequency ||
        frequency > AppConstants.eqMaxFrequency) {
      return null;
    }
    final String f = _formatFrequency(frequency);
    final String q = _format(
      filter.q.clamp(AppConstants.eqMinQ, AppConstants.eqMaxQ),
    );
    switch (filter.type) {
      case ParametricFilterType.peaking:
        return 'equalizer=f=$f:t=q:w=$q:g=${_format(_clampGain(filter.gainDb))}';
      case ParametricFilterType.lowShelf:
        return 'bass=f=$f:g=${_format(_clampGain(filter.gainDb))}:t=q:w=$q';
      case ParametricFilterType.highShelf:
        return 'treble=f=$f:g=${_format(_clampGain(filter.gainDb))}:t=q:w=$q';
      case ParametricFilterType.lowpass:
        return 'lowpass=f=$f:t=q:w=$q';
      case ParametricFilterType.highpass:
        return 'highpass=f=$f:t=q:w=$q';
    }
  }

  /// Cadena sub-armónica:
  ///
  /// * separa la señal en dos ramas;
  /// * filtra la segunda por debajo del corte y baja su nivel;
  /// * desplaza esa rama una octava (`asetrate` a la mitad de la tasa) y
  ///   compensa la duración con `atempo=2`, que no altera el tono;
  /// * mezcla ambas ramas sin normalizar. El limitador común se añade al final
  ///   de toda la cadena en [buildFilter], para no duplicarlo.
  static String _subGraph(SubHarmonicSettings sub) {
    final double crossover = sub.crossoverHz.clamp(
      AppConstants.subMinCrossover,
      AppConstants.subMaxCrossover,
    );
    final double mix = sub.mix.clamp(
      AppConstants.subMinMix,
      AppConstants.subMaxMix,
    );
    if (!crossover.isFinite || !mix.isFinite || mix <= 0) return '';

    final String cutoff = _formatFrequency(crossover);
    final String level = _format(mix);
    final int halfRate = (sampleRate / 2).round();
    return 'asplit=2[pm][sb];'
        '[sb]lowpass=f=$cutoff,volume=$level,'
        'aresample=${sampleRate.round()},asetrate=$halfRate,'
        'atempo=2,aresample=${sampleRate.round()}[so];'
        '[pm][so]amix=inputs=2:duration=first:normalize=0';
  }

  static double _clampGain(double value) =>
      value.clamp(AppConstants.eqMinGain, AppConstants.eqMaxGain);

  static double _finiteGain(double value) =>
      value.isFinite ? _clampGain(value) : 0;

  static String _format(double value) {
    final String text = value.toStringAsFixed(2);
    // Evita "-0.00" y ceros innecesarios en la cadena de mpv.
    if (text == '-0.00') return '0.00';
    return text;
  }

  static String _formatFrequency(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
