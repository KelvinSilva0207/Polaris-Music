import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/models/scrobble_config.dart';
import 'package:polaris_music/core/models/track.dart';
import 'package:polaris_music/core/services/scrobble_service.dart';

import 'support/fake_settings_service.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.responses);

  final List<Map<String, Object?>> responses;
  final List<Map<String, Object?>> requests = <Map<String, Object?>>[];
  int _index = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(Map<String, Object?>.from(options.data as Map));
    final Map<String, Object?> body = responses[_index++ % responses.length];
    return ResponseBody.fromString(jsonEncode(body), 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ScrobbleConfig', () {
    test(
      'sobrevive al viaje JSON y solo está lista si hay sesión y está activa',
      () {
        const ScrobbleConfig config = ScrobbleConfig(
          enabled: true,
          apiKey: 'key',
          apiSecret: 'secret',
          sessionKey: 'sk',
          username: 'polaris',
          endpoint: 'https://ejemplo/2.0/',
          pendingToken: 'token',
        );
        final ScrobbleConfig read = ScrobbleConfig.fromJson(config.toJson());

        expect(read, equals(config));
        expect(read.connected, isTrue);
        expect(read.ready, isTrue);
        expect(
          ScrobbleConfig.fromJson(<String, Object?>{'enabled': true}).ready,
          isFalse,
        );
        expect(ScrobbleConfig.fromJson('roto').connected, isFalse);
      },
    );
  });

  group('ScrobbleService', () {
    test('la firma sigue el orden de claves e ignora format', () {
      expect(
        ScrobbleService.signature(<String, String>{
          'api_key': 'key',
          'method': 'auth.getToken',
        }, 'secret'),
        'b4705499705a550b07ca058a15bde9b0',
      );
      expect(
        ScrobbleService.signature(<String, String>{
          'format': 'json',
          'api_key': 'key',
          'method': 'auth.getToken',
        }, 'secret'),
        ScrobbleService.signature(<String, String>{
          'api_key': 'key',
          'method': 'auth.getToken',
        }, 'secret'),
      );
    });

    test('conecta, guarda la sesión y envía la escucha con su marca de tiempo', () async {
      final FakeSettingsService settings = FakeSettingsService();
      final _RecordingAdapter adapter = _RecordingAdapter(
        <Map<String, Object?>>[
          <String, Object?>{'token': 'tok-123'},
          <String, Object?>{
            'session': <String, Object?>{'name': 'polaris', 'key': 'sk-999'},
          },
          <String, Object?>{'scrobbles': <String, Object?>{}},
        ],
      );
      final ScrobbleService service = ScrobbleService(
        settings: settings,
        dio: Dio()..httpClientAdapter = adapter,
      );

      final String token = await service.beginLogin(
        apiKey: 'key',
        apiSecret: 'secret',
      );
      expect(token, 'tok-123');
      expect(
        adapter.requests.single['api_sig'],
        'b4705499705a550b07ca058a15bde9b0',
      );
      expect(service.authorizationUrl(token).host, 'www.last.fm');
      expect(settings.scrobbleConfig.pendingToken, 'tok-123');

      final ScrobbleConfig connected = await service.finishLogin();
      expect(connected.connected, isTrue);
      expect(connected.ready, isTrue);
      expect(connected.username, 'polaris');
      expect(connected.pendingToken, isEmpty);

      final DateTime listenedAt = DateTime.utc(2026, 11, 21, 12, 0, 0);
      await service.scrobble(
        Track(
          id: 1,
          path: '/musica/a.mp3',
          title: 'T',
          artist: 'A',
          album: 'X',
          durationMs: 180000,
        ),
        listenedAt: listenedAt,
      );

      final Map<String, Object?> last = adapter.requests.last;
      expect(last['method'], 'track.scrobble');
      expect(last['sk'], 'sk-999');
      expect(last['artist'], 'A');
      expect(last['track'], 'T');
      expect(last['timestamp'], '${listenedAt.millisecondsSinceEpoch ~/ 1000}');
      // La marca de tiempo es real, así que se recalcula la firma esperada con
      // los parámetros que acaba de enviar el servicio.
      expect(
        last['api_sig'],
        ScrobbleService.signature(<String, String>{
          'api_key': 'key',
          'sk': 'sk-999',
          'artist': 'A',
          'track': 'T',
          'timestamp': last['timestamp']! as String,
          'method': 'track.scrobble',
        }, 'secret'),
      );
    });

    test('no envía nada si no hay sesión activa', () async {
      final _RecordingAdapter adapter = _RecordingAdapter(
        <Map<String, Object?>>[],
      );
      final ScrobbleService service = ScrobbleService(
        settings: FakeSettingsService(),
        dio: Dio()..httpClientAdapter = adapter,
      );

      await service.scrobble(
        Track(
          id: 2,
          path: '/musica/b.mp3',
          title: 'B',
          artist: 'A',
          album: 'X',
          durationMs: 120000,
        ),
      );

      expect(adapter.requests, isEmpty);
    });

    test('los errores del servidor se muestran como mensaje', () async {
      final FakeSettingsService settings = FakeSettingsService();
      await settings.setScrobbleConfig(
        const ScrobbleConfig(
          apiKey: 'key',
          apiSecret: 'secret',
          sessionKey: 'sk',
          enabled: true,
        ),
      );
      final _RecordingAdapter adapter = _RecordingAdapter(
        <Map<String, Object?>>[
          <String, Object?>{'error': 9, 'message': 'Invalid session key'},
        ],
      );
      final ScrobbleService service = ScrobbleService(
        settings: settings,
        dio: Dio()..httpClientAdapter = adapter,
      );

      await expectLater(
        service.scrobble(
          Track(
            id: 3,
            path: '/musica/c.mp3',
            title: 'C',
            artist: 'A',
            album: 'X',
            durationMs: 1000,
          ),
        ),
        throwsA(
          isA<ScrobbleException>().having(
            (ScrobbleException error) => error.message,
            'message',
            'Invalid session key',
          ),
        ),
      );
    });
  });
}
