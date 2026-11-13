import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/utils/equalizer_dsp.dart';

void main() {
  group('EqualizerDsp', () {
    test('no genera filtros si está desactivado', () {
      expect(
        EqualizerDsp.buildFilter(
          enabled: false,
          gains: const <double>[6, 3, 0, 0, 0, 0, 0, 0, 0, 0],
          preampDb: 3,
        ),
        '',
      );
    });

    test('no genera filtros si todo está plano', () {
      expect(
        EqualizerDsp.buildFilter(
          enabled: true,
          gains: const <double>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        ),
        '',
      );
    });

    test('aplica solo el preamplificador cuando no hay bandas', () {
      expect(
        EqualizerDsp.buildFilter(
          enabled: true,
          gains: const <double>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          preampDb: 3,
        ),
        'lavfi=[volume=3.00dB]',
      );
    });

    test('construye una instancia de equalizer por banda', () {
      final List<double> gains = List<double>.filled(10, 0);
      gains[0] = 5;
      gains[5] = -4.5;

      expect(
        EqualizerDsp.buildFilter(enabled: true, gains: gains),
        'lavfi=[equalizer=f=31:t=q:w=1:g=5.00,'
        'equalizer=f=1000:t=q:w=1:g=-4.50]',
      );
    });

    test('el preamplificador va primero y se respetan los límites', () {
      final List<double> gains = List<double>.filled(10, 0);
      gains[1] = 40; // Se recorta a +12 dB.

      expect(
        EqualizerDsp.buildFilter(
          enabled: true,
          gains: gains,
          preampDb: -20, // Se recorta a -12 dB.
        ),
        'lavfi=[volume=-12.00dB,equalizer=f=62:t=q:w=1:g=12.00]',
      );
    });

    test('ignora valores no finitos y listas cortas', () {
      expect(
        EqualizerDsp.buildFilter(
          enabled: true,
          gains: <double>[double.nan, 0, 2],
        ),
        'lavfi=[equalizer=f=125:t=q:w=1:g=2.00]',
      );
    });
  });
}
