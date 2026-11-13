import 'package:flutter_test/flutter_test.dart';

import 'package:polaris_music/core/utils/formatters.dart';

void main() {
  group('Formatters.duration', () {
    test('formatea minutos y segundos', () {
      expect(Formatters.duration(const Duration(seconds: 65)), '01:05');
      expect(Formatters.duration(Duration.zero), '00:00');
    });

    test('incluye horas cuando hace falta', () {
      expect(
        Formatters.duration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });
  });
}
