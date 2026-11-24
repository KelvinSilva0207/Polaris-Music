import 'dart:convert';

/// Reparación de texto de etiquetas sin dependencias de Flutter.
///
/// `audio_metadata_reader` ya entrega las cadenas decodificadas, pero algunos
/// archivos declaran Latin-1 y en realidad contienen UTF-8 (o al revés). El
/// resultado es mojibake como `MÃºsica`, `Rock Â©` o `Rock â€™ roll`.
///
/// Además de esos marcadores, se limpian los glifos de reemplazo (`■`, `□`)
/// y la secuencia `ï¿½` (un U+FFFD decodificado como Latin-1), que dejan
/// títulos ilegibles aunque el resto de la etiqueta sea válido.
///
/// Las funciones son puras y sincrónicas: se pueden usar dentro de
/// `Isolate.run` durante el escaneo y también al leer la base de datos.
class MetadataText {
  MetadataText._();

  /// Inverso CP1252 → byte para los caracteres que aparecen en mojibake típico.
  static const Map<int, int> _cp1252Reverse = <int, int>{
    0x20AC: 0x80,
    0x201A: 0x82,
    0x0192: 0x83,
    0x201E: 0x84,
    0x2026: 0x85,
    0x2020: 0x86,
    0x2021: 0x87,
    0x02C6: 0x88,
    0x2030: 0x89,
    0x0160: 0x8A,
    0x2039: 0x8B,
    0x0152: 0x8C,
    0x017D: 0x8E,
    0x2018: 0x91,
    0x2019: 0x92,
    0x201C: 0x93,
    0x201D: 0x94,
    0x2022: 0x95,
    0x2013: 0x96,
    0x2014: 0x97,
    0x02DC: 0x98,
    0x2122: 0x99,
    0x0161: 0x9A,
    0x203A: 0x9B,
    0x0153: 0x9C,
    0x017E: 0x9E,
    0x0178: 0x9F,
  };

  /// Inverso del mapa anterior: byte CP1252 → carácter Unicode. Se usa cuando
  /// un `.lrc` no es UTF-8 válido y hay que decodificarlo como Windows-1252.
  static final Map<int, int> _cp1252Forward = Map<int, int>.fromIterables(
    _cp1252Reverse.values,
    _cp1252Reverse.keys,
  );

  static const List<String> _markers = <String>['Ã', 'Â', 'â€', 'ðŸ', 'ï¿½'];

  /// Puntos de código que indican que la etiqueta ya llegó rota.
  static const Set<int> _replacementCodePoints = <int>{
    0xFFFD,
    0x25A0,
    0x25A1,
    0x25A7,
    0x25A8,
    0x25AA,
  };

  /// Glifos de reemplazo que pueden descartarse sin perder texto legible.
  static final RegExp _replacementGlyphs = RegExp(
    r'[\u25A0\u25A1\u25A7\u25A8\u25AA]',
  );

  static final RegExp _controlCharacters = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\u0080-\u009F]',
  );

  static final RegExp _whiteSpace = RegExp(r'\s+');

  /// Detecta marcadores clásicos de UTF-8 leído como Latin-1/CP1252.
  static bool _looksLikeMojibake(String value) {
    for (final int unit in value.codeUnits) {
      if (unit >= 0x80 && unit <= 0x9F) return true;
    }
    for (final String marker in _markers) {
      if (value.contains(marker)) return true;
    }
    return false;
  }

  /// Cuenta marcadores para aceptar solo cambios que mejoran el texto.
  static int _mojibakeScore(String value) {
    int score = 0;
    for (final int unit in value.codeUnits) {
      if (unit >= 0x80 && unit <= 0x9F) score++;
    }
    for (final String marker in _markers) {
      score += value.split(marker).length - 1;
    }
    return score;
  }

  /// Reenvía la cadena como bytes single-byte. Devuelve `null` si aparece un
  /// carácter que no pueda representarse: en ese caso no se toca el original.
  static List<int>? _encodeAsSingleByte(String value) {
    final List<int> bytes = <int>[];
    for (final int unit in value.codeUnits) {
      if (unit <= 0xFF) {
        bytes.add(unit);
        continue;
      }
      final int? mapped = _cp1252Reverse[unit];
      if (mapped == null) return null;
      bytes.add(mapped);
    }
    return bytes;
  }

  /// Quita controles, BOM, espacios de ancho cero y glifos de reemplazo,
  /// normaliza NBSP y colapsa espacios. U+FFFD se conserva a propósito para
  /// que [clean] pueda decidir si toca devolver el respaldo.
  static String _tidy(String value) => value
      .replaceAll(_controlCharacters, '')
      .replaceAll('\uFEFF', '')
      .replaceAll('\u200B', '')
      .replaceAll(_replacementGlyphs, ' ')
      .replaceAll('\u00A0', ' ')
      .replaceAll(_whiteSpace, ' ')
      .trim();

  /// Decodifica bytes Latin-1/Windows-1252 a Unicode.
  ///
  /// Latin-1 puro deja 0x80–0x9F como controles; CP1252 les da su significado
  /// real (€, comillas tipográficas, guiones...). Los bytes no asignados se
  /// conservan y [clean]/[repair] se encargan de descartarlos.
  static String decodeWindows1252(List<int> bytes) => String.fromCharCodes(
    bytes.map(
      (int byte) =>
          byte >= 0x80 && byte <= 0x9F ? (_cp1252Forward[byte] ?? byte) : byte,
    ),
  );

  /// Repara el mojibake sin colapsar espacios: imprescindible para `.lrc`,
  /// donde los saltos de línea forman parte del formato.
  static String repairLines(String input) =>
      _tidyLines(repairMojibakeOnly(input));

  /// Solo corrige la codificación. No normaliza espacios ni recorta texto.
  static String repairMojibakeOnly(String input) {
    String current = input.replaceAll('\x00', '');
    // Hasta tres pasadas para mojibake doble: `ÃƒÂ©` → `Ã©` → `é`.
    for (int pass = 0; pass < 3; pass++) {
      if (!_looksLikeMojibake(current)) break;
      final List<int>? bytes = _encodeAsSingleByte(current);
      if (bytes == null) break;
      String candidate;
      try {
        candidate = utf8.decode(bytes);
      } on FormatException {
        // Si no es UTF-8 válido, conservamos el texto original.
        break;
      }
      if (candidate.isEmpty || candidate == current) break;
      if (_mojibakeScore(candidate) >= _mojibakeScore(current)) break;
      current = candidate;
    }
    // Un `Â` suelto al final no tiene pareja UTF-8: se descarta.
    return current.replaceAll(RegExp(r'Â+$'), '');
  }

  /// Repara `Ã©`, `Â©`, `â€™`, `ÃƒÂ©`, `ï¿½`... de forma conservadora e
  /// idempotente, sin devolver caracteres de control al editor de etiquetas.
  static String repair(String input) => _tidy(repairMojibakeOnly(input));

  /// Como [_tidy] pero conservando saltos de línea y sangrías.
  static String _tidyLines(String value) => value
      .replaceAll(_controlCharacters, '')
      .replaceAll('\uFEFF', '')
      .replaceAll('\u200B', '')
      .replaceAll(_replacementGlyphs, ' ');

  /// Texto listo para guardar o mostrar: repara, quita caracteres de control
  /// y cae a [fallback] si no queda nada legible.
  static String clean(String? raw, String fallback) {
    if (raw == null) return fallback;
    final String value = _tidy(repair(raw));
    if (value.isEmpty || _isIllegible(value)) return fallback;
    return value;
  }

  static bool _isIllegible(String value) {
    if (value.codeUnits.any(_replacementCodePoints.contains)) return true;
    if (value.contains('ï¿½')) return true;
    final int controls = value.codeUnits
        .where((int unit) => unit < 0x20 || (unit >= 0x7F && unit <= 0x9F))
        .length;
    return controls / value.length > 0.05;
  }
}
