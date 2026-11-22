import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/utils/lrc_parser.dart';

void main() {
  group('Karaoke con LRC mejorado', () {
    test('lee las marcas por palabra y limpia el texto', () {
      const String raw = '[00:10.00]<00:10.00>Hola <00:10.60>mundo';
      final LrcDocument document = LrcDocument.parse(raw);

      expect(document.synced, isTrue);
      expect(document.lines, hasLength(1));
      expect(document.lines.single.text, 'Hola mundo');
      expect(document.lines.single.words, <String>['Hola', 'mundo']);
      expect(document.lines.single.wordTimes, <Duration>[
        Duration(milliseconds: 10000),
        Duration(milliseconds: 10600),
      ]);
    });

    test('reparte la duración si no hay marcas por palabra', () {
      final LrcDocument document = LrcDocument.parse(
        '[00:10.00]una dos tres\n[00:13.00]siguiente',
      );
      final LyricLine line = document.lines.first;

      expect(line.wordTimes, isNull);
      expect(document.endTimeFor(0), const Duration(seconds: 13));
      expect(
        line.wordIndexAt(const Duration(seconds: 10), document.endTimeFor(0)),
        0,
      );
      expect(
        line.wordIndexAt(
          const Duration(milliseconds: 12500),
          document.endTimeFor(0),
        ),
        2,
      );
    });

    test(
      'la siguiente línea cierra el hueco y las marcas afinan el progreso',
      () {
        final LrcDocument document = LrcDocument.parse(
          '[00:01.00]<00:01.00>uno <00:01.40>dos\n[00:05.00]tres',
        );

        expect(document.endTimeFor(0), const Duration(seconds: 5));
        expect(
          document.lines.first.wordProgressAt(
            const Duration(milliseconds: 1200),
            document.endTimeFor(0),
          ),
          closeTo(0.5, 0.01),
        );
      },
    );

    test('el resaltado respeta el desfase del documento', () {
      final LrcDocument document = LrcDocument.parse(
        '[offset:-500]\n[00:10.00]letra',
      );

      expect(document.offset, const Duration(milliseconds: -500));
      expect(document.activeIndexAt(const Duration(seconds: 10)), 0);
    });

    test('sin letra no hay índice de palabra', () {
      const LyricLine empty = LyricLine(time: Duration.zero, text: '');

      expect(empty.wordIndexAt(Duration.zero, const Duration(seconds: 2)), -1);
      expect(
        empty.wordProgressAt(Duration.zero, const Duration(seconds: 2)),
        0,
      );
    });
  });
}
