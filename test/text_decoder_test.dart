import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/utils/lrc_parser.dart';
import 'package:polaris_music/core/utils/text_decoder.dart';

void main() {
  group('TextDecoder', () {
    test('respeta UTF-8 válido y el BOM', () {
      final List<int> bytes = <int>[
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode('[00:01.00]Café'),
      ];
      expect(TextDecoder.decode(bytes), '[00:01.00]Café');
    });

    test('cae a Windows-1252 cuando el archivo no es UTF-8', () {
      final List<int> cp1252 = <int>[
        0x5B,
        0x30,
        0x30,
        0x3A,
        0x30,
        0x31,
        0x2E,
        0x30,
        0x30,
        0x5D,
        0x43,
        0x61,
        0x66,
        0xE9,
        0x0A,
        0x93,
        0x68,
        0x6F,
        0x6C,
        0x61,
        0x94,
      ];
      expect(TextDecoder.decode(cp1252), '[00:01.00]Café\n“hola”');
    });

    test('conserva los saltos de línea al reparar mojibake', () {
      final List<int> mojibake = utf8.encode(
        '[00:10.00]MÃºsica\n[00:12.00]CafÃ©',
      );
      final String decoded = TextDecoder.decode(mojibake);
      expect(decoded, '[00:10.00]Música\n[00:12.00]Café');

      final LrcDocument document = LrcDocument.parse(decoded);
      expect(document.lines, hasLength(2));
      expect(document.lines.first.text, 'Música');
      expect(document.lines.last.text, 'Café');
    });

    test('repara el mojibake directamente en el parser LRC', () {
      final LrcDocument document = LrcDocument.parse('[00:10.00]MÃºsica');
      expect(document.lines.single.text, 'Música');
    });
  });
}
