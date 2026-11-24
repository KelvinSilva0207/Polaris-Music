import 'dart:convert';
import 'dart:io';

import 'metadata_text.dart';

/// Lectura de archivos de texto con codificación tolerante.
///
/// `File.readAsString()` asume UTF-8 y sustituye los bytes inválidos por
/// U+FFFD, que es justamente el origen de muchas letras `.lrc` ilegibles.
/// Aquí se intenta UTF-8 estricto primero y solo después se cae a
/// Windows-1252, reparando el mojibake resultante.
class TextDecoder {
  TextDecoder._();

  /// Lee un archivo de texto (normalmente `.lrc`) de forma segura.
  static Future<String> readFile(File file) async =>
      decode(await file.readAsBytes());

  /// Decodifica bytes con BOM, UTF-8 estricto y fallback CP1252.
  static String decode(List<int> bytes) {
    if (bytes.isEmpty) return '';

    // BOM UTF-16: se respeta antes de cualquier heurística.
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return MetadataText.repairLines(
        _decodeUtf16(bytes.sublist(2), littleEndian: true),
      );
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return MetadataText.repairLines(
        _decodeUtf16(bytes.sublist(2), littleEndian: false),
      );
    }
    final int start =
        bytes.length >= 3 &&
            bytes[0] == 0xEF &&
            bytes[1] == 0xBB &&
            bytes[2] == 0xBF
        ? 3
        : 0;
    final List<int> body = bytes.sublist(start);
    try {
      return MetadataText.repairLines(
        const Utf8Decoder(allowMalformed: false).convert(body),
      );
    } on FormatException {
      // No era UTF-8: CP1252 conserva los acentos y las comillas de los
      /// archivos escritos por editores de Windows.
      return MetadataText.repairLines(MetadataText.decodeWindows1252(body));
    }
  }

  static String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
    final List<int> units = <int>[];
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      units.add(
        littleEndian
            ? bytes[i] | (bytes[i + 1] << 8)
            : (bytes[i] << 8) | bytes[i + 1],
      );
    }
    return String.fromCharCodes(units);
  }
}
