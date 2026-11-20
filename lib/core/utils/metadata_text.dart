import 'dart:convert';

/// Reparación de texto de etiquetas sin dependencias de Flutter.
///
/// `audio_metadata_reader` ya entrega las cadenas decodificadas, pero algunos
/// archivos declaran Latin-1 y en realidad contienen UTF-8 (o al revés). El
/// resultado es mojibake como `MÃºsica`, `Rock Â©` o `Rock â€™ roll`.
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

  static const List<String> _markers = <String>['Ã', 'Â', 'â€', 'ðŸ'];

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

  /// Repara `Ã©`, `Â©`, `â€™`, `ÃƒÂ©`... de forma conservadora e idempotente.
  static String repair(String input) {
    String current = input.replaceAll('\x00', '').trim();
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
      candidate = candidate.trim();
      if (candidate.isEmpty || candidate == current) break;
      if (_mojibakeScore(candidate) >= _mojibakeScore(current)) break;
      current = candidate;
    }
    // Un `Â` suelto al final no tiene pareja UTF-8: se descarta.
    return current.replaceAll(RegExp(r'Â+$'), '').trim();
  }

  /// Texto listo para guardar o mostrar: repara, quita caracteres de control
  /// y cae a [fallback] si no queda nada legible.
  static String clean(String? raw, String fallback) {
    if (raw == null) return fallback;
    String value = repair(raw);
    value = value.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\u0080-\u009F]'),
      '',
    );
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (value.isEmpty || _isIllegible(value)) return fallback;
    return value;
  }

  static bool _isIllegible(String value) {
    if (value.contains('\uFFFD')) return true;
    final int controls = value.codeUnits
        .where((int unit) => unit < 0x20 || (unit >= 0x7F && unit <= 0x9F))
        .length;
    return controls / value.length > 0.05;
  }
}
