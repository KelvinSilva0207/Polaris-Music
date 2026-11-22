import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/constants/app_constants.dart';
import 'package:polaris_music/core/models/equalizer_config.dart';
import 'package:polaris_music/core/utils/equalizer_dsp.dart';

void main() {
  const String limiter = ',alimiter=limit=0.89:level=0]';

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

    test('el modo puro bypassa EQ, sub-armónico y limitador', () {
      expect(
        EqualizerDsp.buildFilter(
          enabled: true,
          gains: const <double>[12, 8, 0, 0, 0, 0, 0, 0, 0, 0],
          preampDb: 6,
          sub: const SubHarmonicSettings(enabled: true, mix: 0.3),
          pure: true,
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

    test('una banda activa compensa ganancia y termina en limitador', () {
      final List<double> gains = List<double>.filled(10, 0);
      gains[0] = 5;
      gains[5] = -4.5;

      final String filter = EqualizerDsp.buildFilter(
        enabled: true,
        gains: gains,
      );
      final double auto = EqualizerDsp.antiClipGainDb(gains: gains);

      expect(auto, lessThan(0));
      expect(filter, startsWith('lavfi=[volume=${auto.toStringAsFixed(2)}dB,'));
      expect(filter, contains('equalizer=f=31:t=q:w=1:g=5.00'));
      expect(filter, contains('equalizer=f=1000:t=q:w=1:g=-4.50'));
      expect(filter, endsWith(limiter));
    });

    test('el preamplificador manual cuenta para la compensación', () {
      final List<double> gains = List<double>.filled(10, 0);
      gains[1] = 12; // Banda recortada a +12 dB.

      final double autoWithoutPreamp = EqualizerDsp.antiClipGainDb(
        gains: gains,
      );
      final double autoWithPreamp = EqualizerDsp.antiClipGainDb(
        gains: gains,
        preampDb: -4,
      );

      // El preamp manual ya baja 4 dB el pico: el anti-clip completa el resto.
      expect(autoWithoutPreamp, lessThan(0));
      expect(autoWithPreamp, closeTo(autoWithoutPreamp + 4, 0.15));

      final String filter = EqualizerDsp.buildFilter(
        enabled: true,
        gains: gains,
        preampDb: -4,
      );
      // El nodo `volume` es el preamp manual ya compensado, no solo el auto.
      expect(
        filter,
        contains('volume=${(-4 + autoWithPreamp).toStringAsFixed(2)}dB'),
      );
      expect(filter, contains('equalizer=f=62:t=q:w=1:g=12.00'));
      expect(filter, endsWith(limiter));
    });

    test('si el preamp manual ya elimina el pico no se atenúa', () {
      final List<double> gains = List<double>.filled(10, 0);
      gains[1] = 12;

      final String filter = EqualizerDsp.buildFilter(
        enabled: true,
        gains: gains,
        preampDb: -12,
      );

      expect(filter, contains('volume=-12.00dB'));
      expect(filter, contains('equalizer=f=62:t=q:w=1:g=12.00'));
      expect(filter, endsWith(limiter));
    });

    test('ignora valores no finitos y listas cortas', () {
      final String filter = EqualizerDsp.buildFilter(
        enabled: true,
        gains: <double>[double.nan, 0, 2],
      );
      expect(filter, contains('equalizer=f=125:t=q:w=1:g=2.00'));
      expect(filter, isNot(contains('NaN')));
      expect(filter, endsWith(limiter));
    });

    test('respeta frecuencias personalizadas', () {
      final String filter = EqualizerDsp.buildFilter(
        enabled: true,
        gains: const <double>[2, 3],
        frequencies: const <double>[100, 5000],
      );
      expect(filter, contains('equalizer=f=100:t=q:w=1:g=2.00'));
      expect(filter, contains('equalizer=f=5000:t=q:w=1:g=3.00'));
      expect(filter, endsWith(limiter));
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

      final String filter = EqualizerDsp.buildFilter(
        enabled: true,
        gains: const <double>[],
        mode: EqMode.parametric,
        filters: filters,
      );
      expect(filter, contains('equalizer=f=1000:t=q:w=1.20:g=3.00'));
      expect(filter, contains('bass=f=100:g=4.00:t=q:w=0.70'));
      expect(filter, contains('treble=f=5000:g=-3.00:t=q:w=0.90'));
      expect(filter, contains('lowpass=f=200:t=q:w=0.70'));
      expect(filter, contains('highpass=f=80:t=q:w=1.00'));
      expect(filter, isNot(contains('300')));
      expect(filter, endsWith(limiter));
    });

    test('el sub-armónico usa una octava y mezcla acotada', () {
      const SubHarmonicSettings sub = SubHarmonicSettings(
        enabled: true,
        mix: 0.18,
        crossoverHz: 90,
      );
      final String filter = EqualizerDsp.buildFilter(
        enabled: true,
        gains: const <double>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        sub: sub,
      );
      expect(filter, startsWith('lavfi=[volume='));
      expect(filter, contains('asplit=2[pm][sb];'));
      expect(
        filter,
        contains(
          '[sb]lowpass=f=90,volume=0.18,aresample=48000,'
          'asetrate=24000,atempo=2,aresample=48000[so];',
        ),
      );
      expect(
        filter,
        endsWith('[pm][so]amix=inputs=2:duration=first:normalize=0$limiter'),
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
      expect(filter, contains('equalizer=f=31:t=q:w=1:g=3.00'));
      expect(filter, contains('volume=0.35'));
      expect(filter, contains('lowpass=f=200'));
      expect(filter, endsWith(limiter));
    });

    test('sin anti-clip se conserva la cadena histórica', () {
      expect(
        EqualizerDsp.buildFilter(
          enabled: true,
          gains: const <double>[3, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          preampDb: -2,
          antiClip: false,
        ),
        'lavfi=[volume=-2.00dB,equalizer=f=31:t=q:w=1:g=3.00]',
      );
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

  group('EqualizerDsp.antiClipGainDb', () {
    test('una curva plana no atenúa', () {
      expect(EqualizerDsp.antiClipGainDb(gains: List<double>.filled(10, 0)), 0);
    });

    test('el refuerzo del sub-armónico aumenta la atenuación', () {
      final List<double> gains = List<double>.filled(10, 0);
      gains[1] = 4;
      final double withoutSub = EqualizerDsp.antiClipGainDb(gains: gains);
      final double withSub = EqualizerDsp.antiClipGainDb(
        gains: gains,
        subBoostDb: 20 * 0.3,
      );
      expect(withoutSub, lessThan(0));
      expect(withSub, lessThan(withoutSub));
    });

    test('nunca supera la atenuación máxima permitida', () {
      final double auto = EqualizerDsp.antiClipGainDb(
        gains: List<double>.filled(10, 12),
        preampDb: 12,
      );
      expect(auto, lessThanOrEqualTo(0));
      expect(
        auto,
        greaterThanOrEqualTo(-AppConstants.antiClipMaxAttenuationDb),
      );
    });
  });
}
