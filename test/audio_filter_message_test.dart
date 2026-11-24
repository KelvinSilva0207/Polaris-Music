import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/utils/audio_filter_message.dart';

void main() {
  group('AudioFilterMessage', () {
    test('reconoce los mensajes de inicialización de lavfi', () {
      expect(
        AudioFilterMessage.isFilterFailure('Audio filter initialized failed!'),
        isTrue,
      );
      expect(
        AudioFilterMessage.isFilterFailure(
          '[ffmpeg] Error parsing option af (Could not create audio filter chain)',
        ),
        isTrue,
      );
      expect(
        AudioFilterMessage.isFilterFailure("No such filter: 'alimiter'"),
        isTrue,
      );
    });

    test('no clasifica errores de apertura de archivo como DSP', () {
      expect(
        AudioFilterMessage.isFilterFailure('Failed to open file.mp3.'),
        isFalse,
      );
      expect(AudioFilterMessage.isFilterFailure('403 Forbidden'), isFalse);
    });
  });
}
