import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/models/track_technical_info.dart';

void main() {
  group('TrackTechnicalInfo', () {
    test('parsea propiedades de mpv y calcula la duración', () {
      final TrackTechnicalInfo info = TrackTechnicalInfo.fromMpv(
        <String, String?>{
          'codec': ' flac ',
          'container': 'native flac',
          'bitrate': '1411200',
          'samplerate': '44100',
          'channels': '2',
          'duration': '213.456',
          'file-size': '37698765',
        },
      );

      expect(info.codec, 'flac');
      expect(info.container, 'native flac');
      expect(info.bitrateBps, 1411200);
      expect(info.sampleRateHz, 44100);
      expect(info.channels, 2);
      expect(info.duration, const Duration(milliseconds: 213456));
      expect(info.sizeBytes, 37698765);
      expect(info.isEmpty, isFalse);
    });

    test('ignora propiedades ausentes o inválidas', () {
      final TrackTechnicalInfo info = TrackTechnicalInfo.fromMpv(
        <String, String?>{
          'codec': 'null',
          'bitrate': 'no disponible',
          'duration': '-1',
          'channels': '0',
        },
      );

      expect(info.codec, isNull);
      expect(info.bitrateBps, isNull);
      expect(info.duration, isNull);
      expect(info.channels, isNull);
      expect(info.isEmpty, isTrue);
    });

    test('orElse rellena solo los huecos', () {
      const TrackTechnicalInfo live = TrackTechnicalInfo(
        codec: 'aac',
        sampleRateHz: 48000,
      );
      const TrackTechnicalInfo indexed = TrackTechnicalInfo(
        codec: 'mp3',
        container: 'MP3',
        sampleRateHz: 44100,
        bitrateBps: 320000,
      );

      final TrackTechnicalInfo merged = live.orElse(indexed);
      expect(merged.codec, 'aac');
      expect(merged.sampleRateHz, 48000);
      expect(merged.container, 'MP3');
      expect(merged.bitrateBps, 320000);
    });
  });
}
