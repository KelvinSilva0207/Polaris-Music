import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/models/equalizer_config.dart';
import 'package:polaris_music/core/utils/equalizer_dsp.dart';

void main() {
  group('EqualizerDsp.buildFilterCandidates', () {
    test('retira primero el sub-armónico y después el limitador', () {
      final List<String> candidates = EqualizerDsp.buildFilterCandidates(
        enabled: true,
        gains: const <double>[6, 3, 0, 0, 0, 0, 0, 0, 0, 0],
        preampDb: 3,
        sub: const SubHarmonicSettings(enabled: true, mix: 0.3),
      );

      expect(candidates, isNotEmpty);
      expect(candidates.first, contains('asetrate'));
      expect(candidates.first, contains('alimiter'));
      expect(candidates[1], isNot(contains('asetrate')));
      expect(candidates[1], contains('alimiter'));
      expect(candidates[candidates.length - 2], isNot(contains('alimiter')));
      expect(candidates.last, isEmpty);
    });

    test('en modo puro solo ofrece la cadena vacía', () {
      expect(
        EqualizerDsp.buildFilterCandidates(
          enabled: true,
          gains: const <double>[12, 8, 0, 0, 0, 0, 0, 0, 0, 0],
          pure: true,
        ),
        <String>[''],
      );
    });
  });
}
