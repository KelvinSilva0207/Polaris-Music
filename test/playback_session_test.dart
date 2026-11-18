import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/models/playback_state.dart';
import 'package:polaris_music/core/services/playback_session_service.dart';

void main() {
  group('PlaybackSession', () {
    test('el viaje JSON conserva cola, índice y posición exacta', () {
      const PlaybackSession session = PlaybackSession(
        paths: <String>[r'C:\Music\a.mp3', r'C:\Music\b.flac'],
        index: 1,
        positionMs: 83742,
        playing: true,
        shuffle: true,
        repeat: RepeatMode.all,
        playlistId: 7,
      );

      final Map<String, dynamic> json =
          jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>;
      final PlaybackSession restored = PlaybackSession.fromJson(json);

      expect(restored.paths, session.paths);
      expect(restored.index, 1);
      expect(restored.positionMs, 83742);
      expect(restored.playing, isTrue);
      expect(restored.shuffle, isTrue);
      expect(restored.repeat, RepeatMode.all);
      expect(restored.playlistId, 7);
      expect(restored.isEmpty, isFalse);
    });

    test('valores ausentes o corruptos caen en valores seguros', () {
      final PlaybackSession restored = PlaybackSession.fromJson(
        <String, dynamic>{
          'paths': <dynamic>['ok.mp3', 42, ''],
          'index': 'no-entero',
          'positionMs': -5,
          'repeat': 99,
        },
      );

      expect(restored.paths, <String>['ok.mp3']);
      expect(restored.index, -1);
      expect(restored.positionMs, 0);
      expect(restored.playing, isFalse);
      expect(restored.shuffle, isFalse);
      expect(restored.repeat, RepeatMode.off);
      expect(restored.playlistId, isNull);
      expect(restored.isEmpty, isTrue);
    });
  });
}
