import '../constants/app_constants.dart';

/// Construye la cadena de filtros de audio de libmpv para el ecualizador.
///
/// mpv expone FFmpeg mediante el filtro `lavfi`; dentro de él se combinan el
/// preamplificador (`volume`) y una instancia de `equalizer` por banda. El
/// resultado se asigna a la propiedad `af` del reproductor.
///
/// Es una función pura (sin FFI ni Flutter) para poder probarla sin audio.
class EqualizerDsp {
  EqualizerDsp._();

  /// Ganancia mínima audible para incluir una banda en la cadena.
  static const double _epsilon = 0.05;

  /// Devuelve `''` cuando no hay procesamiento que aplicar.
  static String buildFilter({
    required bool enabled,
    required List<double> gains,
    double preampDb = 0,
  }) {
    if (!enabled) return '';

    final List<String> parts = <String>[];

    if (preampDb.isFinite && preampDb.abs() >= _epsilon) {
      parts.add('volume=${_format(_clampGain(preampDb))}dB');
    }

    final int length = gains.length < AppConstants.eqBands.length
        ? gains.length
        : AppConstants.eqBands.length;

    for (int i = 0; i < length; i++) {
      final double gain = gains[i];
      if (!gain.isFinite || gain.abs() < _epsilon) continue;
      final String frequency = _formatFrequency(AppConstants.eqBands[i]);
      parts.add(
        'equalizer=f=$frequency:t=q:w=1:g=${_format(_clampGain(gain))}',
      );
    }

    if (parts.isEmpty) return '';
    return 'lavfi=[${parts.join(',')}]';
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
