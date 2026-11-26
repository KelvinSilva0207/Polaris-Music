import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/models/equalizer_config.dart';
import 'package:polaris_music/core/utils/frequency_response.dart';

void main() {
  group('FrequencyResponse', () {
    test('una configuración plana no altera la respuesta', () {
      for (final double hz in <double>[20, 100, 1000, 10000, 20000]) {
        expect(
          FrequencyResponse.dbAt(
            frequencyHz: hz,
            config: const EqualizerConfig(),
          ),
          closeTo(0, 0.001),
        );
      }
    });

    test('una campana realza su frecuencia central', () {
      const EqualizerConfig config = EqualizerConfig(
        bands: <double>[0, 0, 0, 0, 0, 6, 0, 0, 0, 0],
      );
      final double atCenter = FrequencyResponse.dbAt(
        frequencyHz: 1000,
        config: config,
      );
      final double farAway = FrequencyResponse.dbAt(
        frequencyHz: 100,
        config: config,
      );
      expect(atCenter, greaterThan(5));
      expect(farAway.abs(), lessThan(1));
    });

    test('el modo paramétrico dibuja sus propios filtros', () {
      const EqualizerConfig config = EqualizerConfig(
        mode: EqMode.parametric,
        filters: <ParametricFilter>[
          ParametricFilter(
            type: ParametricFilterType.lowpass,
            frequencyHz: 200,
            q: 0.7,
          ),
        ],
      );
      expect(
        FrequencyResponse.dbAt(frequencyHz: 100, config: config),
        greaterThan(FrequencyResponse.dbAt(frequencyHz: 5000, config: config)),
      );
    });

    test('el Q de los estantes coincide con el Q de bass/treble de FFmpeg', () {
      EqualizerConfig shelf(double q) => EqualizerConfig(
        mode: EqMode.parametric,
        filters: <ParametricFilter>[
          ParametricFilter(
            type: ParametricFilterType.lowShelf,
            frequencyHz: 100,
            gainDb: 12,
            q: q,
          ),
        ],
      );

      // Con `t=q`, un Q bajo ensancha la transición: a 200 Hz queda más
      // refuerzo que con un Q alto. Con la antigua pendiente S ambos casos se
      // veían igual en la curva aunque sonaban distinto.
      final double wide = FrequencyResponse.dbAt(
        frequencyHz: 200,
        config: shelf(0.2),
      );
      final double narrow = FrequencyResponse.dbAt(
        frequencyHz: 200,
        config: shelf(8),
      );
      expect(wide, greaterThan(narrow));
      expect(wide, greaterThan(0));
    });

    test('la escala logarítmica es reversible', () {
      const double width = 320;
      for (final double hz in <double>[20, 100, 1000, 10000, 20000]) {
        final double x = FrequencyResponse.xFor(hz, width);
        expect(
          FrequencyResponse.frequencyForX(x, width),
          closeTo(hz, hz / 1000),
        );
      }
    });
  });
}
