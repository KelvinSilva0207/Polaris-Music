/// Clasificación de mensajes de libmpv/FFmpeg relacionados con la cadena `af`.
///
/// mpv publica los errores de inicialización de filtros por el mismo stream que
/// los fallos de apertura de archivos. Sin esta distinción, un filtro inválido
/// se convierte en un banner rojo en cada pista aunque el audio se esté
/// reproduciendo correctamente.
class AudioFilterMessage {
  AudioFilterMessage._();

  static const List<String> _markers = <String>[
    'audio filter initialized failed',
    'creating filter',
    'filter graph',
    'avfiltergraph',
    'no such filter',
    'error parsing option af',
    'disabling filter',
    'could not create audio filter chain',
    'error at audio filter chain',
    'failed to configure',
    'cannot configure',
    'lavfi',
    'af-add',
    'af-append',
  ];

  /// `true` cuando el texto describe un problema del DSP, no del archivo.
  static bool isFilterFailure(String message) {
    final String lower = message.toLowerCase();
    for (final String marker in _markers) {
      if (lower.contains(marker)) return true;
    }
    return false;
  }
}
