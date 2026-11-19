import '../constants/app_constants.dart';
import '../models/equalizer_config.dart';

/// Construye la cadena de filtros de audio de libmpv para el ecualizador.
///
/// mpv expone FFmpeg mediante el filtro `lavfi`; dentro de él se combinan el
/// preamplificador (`volume`), las bandas del ecualizador (`equalizer`,
/// `bass`, `treble`, `lowpass`, `highpass`) y, opcionalmente, una rama
/// sub-armónica con limitador final. El resultado se asigna a `af`.
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
  static const double sampleRate = 48000;

  /// Devuelve `''` cuando no hay procesamiento que aplicar.
  static String buildFilter({
    required bool enabled,
    required List<double> gains,
    List<double>? frequencies,
    double preampDb = 0,
    EqMode mode = EqMode.graphic,
    List<ParametricFilter> filters = const <ParametricFilter>[],
    SubHarmonicSettings sub = const SubHarmonicSettings(),
  }) {
    if (!enabled) return '';

    final List<String> chain = <String>[];

    if (preampDb.isFinite && preampDb.abs() >= _epsilon) {
      chain.add('volume=${_format(_clampGain(preampDb))}dB');
    }

    if (mode == EqMode.parametric) {
      for (final ParametricFilter filter in filters) {
        if (!filter.enabled) continue;
        final String? part = _parametricPart(filter);
        if (part != null) chain.add(part);
      }
    } else {
      final List<double> hz = frequencies ?? AppConstants.eqBands;
      final int length = gains.length < hz.length ? gains.length : hz.length;
      for (int i = 0; i < length; i++) {
        final double gain = gains[i];
        if (!gain.isFinite || gain.abs() < _epsilon) continue;
        final String frequency = _formatFrequency(hz[i]);
        chain.add(
          'equalizer=f=$frequency:t=q:w=1:g=${_format(_clampGain(gain))}',
        );
      }
    }

    if (sub.enabled) {
      final String subGraph = _subGraph(sub);
      if (subGraph.isNotEmpty) {
        final String prefix = chain.isEmpty ? '' : '${chain.join(',')},';
        return 'lavfi=[$prefix$subGraph]';
      }
    }

    if (chain.isEmpty) return '';
    return 'lavfi=[${chain.join(',')}]';
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
  /// * mezcla ambas ramas sin normalizar y aplica un limitador de true peak
  ///   para que el refuerzo nunca recorte ni desactive el filtro por exceso.
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
        '[pm][so]amix=inputs=2:duration=first:normalize=0,'
        'alimiter=limit=0.89:level=0';
  }

  static double _clampGain(double value) =>
      value.clamp(AppConstants.eqMinGain, AppConstants.eqMaxGain);

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
