import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:polaris_music/core/models/playback_state.dart';
import 'package:polaris_music/core/models/track.dart';
import 'package:polaris_music/core/services/audio_engine_service.dart';
import 'package:polaris_music/core/services/playback_session_service.dart';
import 'package:polaris_music/features/library/presentation/alphabet_index.dart';
import 'package:polaris_music/features/player/domain/player_controller.dart';
import 'package:polaris_music/features/player/presentation/player_providers.dart';

import 'support/fake_settings_service.dart';

class _SilentPlatformPlayer extends PlatformPlayer {
  _SilentPlatformPlayer() : super(configuration: const PlayerConfiguration());
}

/// Motor sin audio: al índice solo le importa que la fila pueda construirse.
class _SnapshotEngine extends AudioEngineService {
  _SnapshotEngine()
    : _states = StreamController<PlaybackSnapshot>.broadcast(),
      super(player: Player(platformPlayer: _SilentPlatformPlayer()));

  final StreamController<PlaybackSnapshot> _states;

  @override
  PlaybackSnapshot get state => const PlaybackSnapshot();

  @override
  Stream<PlaybackSnapshot> get states => _states.stream;

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Future<void> configureCrossfade({
    required bool enabled,
    required int ms,
  }) async {}

  @override
  Future<void> configureSilenceTrim({
    required bool enabled,
    required int startMs,
    required int endMs,
  }) async {}

  @override
  Future<void> setFadeFactor(double value) async {}

  @override
  Future<void> dispose() async {
    await _states.close();
  }
}

Track _track(int id, String title) => Track(
  id: id,
  path: '/music/$title.mp3',
  title: title,
  artist: 'Artista',
  album: 'Álbum',
  durationMs: 180000,
);

void main() {
  test('trackInitial pliega acentos y respeta la Ñ', () {
    expect(trackInitial('Ángel'), 'A');
    expect(trackInitial('Éxito'), 'E');
    expect(trackInitial('Ñandú'), 'Ñ');
    expect(trackInitial('  Órbita'), 'O');
    expect(trackInitial('Über'), 'U');
  });

  test('trackInitial manda números y símbolos a #', () {
    expect(trackInitial('123五天'), '#');
    expect(trackInitial('!!! Difícil'), '#');
    expect(trackInitial('   '), '#');
    expect(trackInitial('7 segundos'), '#');
  });

  test(
    'buildAlphabetPositions guarda la primera aparición de cada inicial',
    () {
      final List<Track> tracks = <Track>[
        _track(1, 'Arbol'),
        _track(2, 'Balada'),
        _track(3, 'Aire'),
        _track(4, 'Ñandú'),
        _track(5, '123'),
      ];

      final Map<String, int> positions = buildAlphabetPositions(tracks);

      expect(positions['A'], 0);
      expect(positions['B'], 1);
      expect(positions['Ñ'], 3);
      expect(positions['#'], 4);
      expect(positions.containsKey('C'), isFalse);
    },
  );

  testWidgets('tocar una letra muestra las canciones con esa inicial', (
    WidgetTester tester,
  ) async {
    final FakeSettingsService settings = FakeSettingsService();
    final _SnapshotEngine engine = _SnapshotEngine();
    final PlayerController player = PlayerController(
      engine: engine,
      settings: settings,
      session: PlaybackSessionService(settings),
    );
    final List<Track> tracks = <Track>[
      for (int i = 0; i < 12; i++) _track(i + 1, 'Cancion ${i + 1}'),
      _track(20, 'Kansas'),
      _track(21, 'Luna'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playerControllerProvider.overrideWith((Ref ref) => player),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: AlphabetizedTrackList(
                tracks: tracks,
                storageKey: 'test-alphabet',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('K'), findsOneWidget);
    await tester.tap(find.text('K'));
    await tester.pumpAndSettle();

    expect(find.text('Kansas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
