import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/constants/app_constants.dart';
import 'package:polaris_music/core/models/equalizer_config.dart';

void main() {
  group('EqualizerConfig', () {
    test('serializa y restaura modo, bandas, filtros y sub-armónico', () {
      const EqualizerConfig config = EqualizerConfig(
        mode: EqMode.parametric,
        frequencies: <double>[60, 230, 910, 3600, 14000],
        bands: <double>[2, -1, 0, 3, 1],
        filters: <ParametricFilter>[
          ParametricFilter(frequencyHz: 420, gainDb: -4, q: 2.5),
        ],
        preampDb: -3.5,
        sub: SubHarmonicSettings(enabled: true, mix: 0.22, crossoverHz: 110),
      );

      final EqualizerConfig restored = EqualizerConfig.deserialize(
        config.serialize(),
      );
      expect(restored.mode, EqMode.parametric);
      expect(restored.frequencies, config.frequencies);
      expect(restored.bands, config.bands);
      expect(restored.preampDb, -3.5);
      expect(restored.sub.enabled, isTrue);
      expect(restored.sub.mix, closeTo(0.22, 0.001));
      expect(restored.sub.crossoverHz, closeTo(110, 0.001));
      expect(restored.filters, hasLength(1));
      expect(restored.filters.first.type, ParametricFilterType.peaking);
      expect(restored.filters.first.q, closeTo(2.5, 0.001));
    });

    test('reconoce el diseño de bandas y marca los personalizados', () {
      final EqualizerConfig five = EqualizerConfig(
        frequencies: AppConstants.eqBandLayouts['5']!,
        bands: List<double>.filled(5, 0),
      );
      expect(five.layoutId, '5');
      expect(const EqualizerConfig().layoutId, '10');
      expect(
        const EqualizerConfig(frequencies: <double>[50, 300, 9000]).layoutId,
        AppConstants.eqCustomLayout,
      );
    });

    test('lee presets históricos de 10 bandas', () {
      final EqualizerConfig legacy = EqualizerConfig.fromLegacy(
        gains: const <double>[1, 2],
        preampDb: 4,
      );
      expect(legacy.bands, hasLength(10));
      expect(legacy.bands.sublist(0, 2), <double>[1, 2]);
      expect(legacy.preampDb, 4);
      expect(legacy.mode, EqMode.graphic);
    });

    test('un JSON corrupto deja una configuración plana', () {
      final EqualizerConfig config = EqualizerConfig.deserialize('{no-es-json');
      expect(config.mode, EqMode.graphic);
      expect(config.isFlat, isTrue);
    });

    test('acota valores fuera de rango', () {
      final EqualizerConfig config = EqualizerConfig.fromJson(<String, dynamic>{
        'bands': <dynamic>[99, -99],
        'frequencies': <dynamic>[1, 999999],
        'preampDb': 80,
        'sub': <String, dynamic>{
          'enabled': true,
          'mix': 9,
          'crossoverHz': 9000,
        },
      });
      expect(config.bands.first, AppConstants.eqMaxGain);
      expect(config.bands.last, AppConstants.eqMinGain);
      expect(config.frequencies.first, AppConstants.eqMinFrequency);
      expect(config.frequencies.last, AppConstants.eqMaxFrequency);
      expect(config.sub.mix, AppConstants.subMaxMix);
      expect(config.sub.crossoverHz, AppConstants.subMaxCrossover);
    });
  });
}
