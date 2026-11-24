import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/models/track.dart';
import 'package:polaris_music/core/services/widget_bridge_service.dart';

/// El puente construye un snapshot completo; estos tests no necesitan Android:
/// comprueban el payload puro que después consume el provider nativo.
void main() {
  Track track({String title = 'Canción'}) => Track(
    id: 7,
    path: r'C:\music\cancion.mp3',
    title: title,
    artist: 'Artista',
    album: 'Álbum',
    durationMs: 180000,
  );

  test('el payload incluye título, artista, estado y carátula', () {
    final Uint8List artwork = Uint8List.fromList(const <int>[1, 2, 3]);
    final Map<String, Object> payload = buildWidgetPayload(
      track(),
      playing: true,
      artwork: artwork,
    );

    expect(payload, <String, Object>{
      'title': 'Canción',
      'artist': 'Artista',
      'playing': true,
      'artwork': artwork,
    });
  });

  test(
    'sin carátula el payload la omite para que Kotlin limpie la anterior',
    () {
      final Map<String, Object> payload = buildWidgetPayload(
        track(),
        playing: false,
      );

      expect(payload.containsKey('artwork'), isFalse);
      expect(payload['playing'], isFalse);
    },
  );

  test('una carátula vacía tampoco se envía', () {
    final Map<String, Object> payload = buildWidgetPayload(
      track(title: 'Otra'),
      playing: true,
      artwork: Uint8List(0),
    );

    expect(payload.containsKey('artwork'), isFalse);
    expect(payload['title'], 'Otra');
  });
}
