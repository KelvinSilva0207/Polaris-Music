import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/models/equalizer_config.dart';
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

    test('respeta frecuencias personalizadas', () {
      expect(
        EqualizerDsp.buildFilter(
          enabled: true,
          gains: <double>[2, 3],
          frequencies: const <double>[100, 5000],
        ),
        'lavfi=[equalizer=f=100:t=q:w=1:g=2.00,'
        'equalizer=f=5000:t=q:w=1:g=3.00]',
      );
    });

    test('construye filtros paramétricos con Q y tipo', () {
      final List<ParametricFilter> filters = <ParametricFilter>[
        const ParametricFilter(frequencyHz: 1000, gainDb: 3, q: 1.2),
        const ParametricFilter(
          type: ParametricFilterType.lowShelf,
          frequencyHz: 100,
          gainDb: 4,
          q: 0.7,
        ),
        const ParametricFilter(
          type: ParametricFilterType.highShelf,
          frequencyHz: 5000,
          gainDb: -3,
          q: 0.9,
        ),
        const ParametricFilter(
          type: ParametricFilterType.lowpass,
          frequencyHz: 200,
          q: 0.7,
        ),
        const ParametricFilter(
          type: ParametricFilterType.highpass,
          frequencyHz: 80,
        ),
        const ParametricFilter(enabled: false, frequencyHz: 300),
      ];

      expect(
        EqualizerDsp.buildFilter(
          enabled: true,
          gains: const <double>[],
          mode: EqMode.parametric,
          filters: filters,
        ),
        'lavfi=[equalizer=f=1000:t=q:w=1.20:g=3.00,'
        'bass=f=100:g=4.00:t=q:w=0.70,'
        'treble=f=5000:g=-3.00:t=q:w=0.90,'
        'lowpass=f=200:t=q:w=0.70,'
        'highpass=f=80:t=q:w=1.00]',
      );
    });

    test('el sub-armónico usa una octava, mezcla acotada y limitador', () {
      const SubHarmonicSettings sub = SubHarmonicSettings(
        enabled: true,
        mix: 0.18,
        crossoverHz: 90,
      );
      expect(
        EqualizerDsp.buildFilter(
          enabled: true,
          gains: const <double>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          sub: sub,
        ),
        'lavfi=[asplit=2[pm][sb];'
        '[sb]lowpass=f=90,volume=0.18,aresample=48000,'
        'asetrate=24000,atempo=2,aresample=48000[so];'
        '[pm][so]amix=inputs=2:duration=first:normalize=0,'
        'alimiter=limit=0.89:level=0]',
      );
    });

    test('el limitador va al final de la cadena completa', () {
      const SubHarmonicSettings sub = SubHarmonicSettings(
        enabled: true,
        mix: 0.4, // Se recorta al 35 % máximo.
        crossoverHz: 500, // Se recorta a 200 Hz.
      );
      final String filter = EqualizerDsp.buildFilter(
        enabled: true,
        gains: const <double>[3, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        preampDb: -2,
        sub: sub,
      );
      expect(
        filter.startsWith(
          'lavfi=[volume=-2.00dB,equalizer=f=31:t=q:w=1:g=3.00,asplit=2',
        ),
        isTrue,
      );
      expect(filter, contains('volume=0.35'));
      expect(filter, contains('lowpass=f=200'));
      expect(filter, endsWith('alimiter=limit=0.89:level=0]'));
    });

    test('un sub-armónico desactivado no altera la cadena', () {
      expect(
        EqualizerDsp.buildFilter(
          enabled: true,
          gains: const <double>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          sub: const SubHarmonicSettings(
            enabled: false,
            mix: 0.3,
            crossoverHz: 100,
          ),
        ),
        '',
      );
    });
  });
}
