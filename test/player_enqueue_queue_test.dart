import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:polaris_music/core/models/playback_state.dart';
import 'package:polaris_music/core/models/track.dart';
import 'package:polaris_music/core/services/audio_engine_service.dart';
import 'package:polaris_music/core/services/playback_session_service.dart';
import 'package:polaris_music/features/player/domain/player_controller.dart';

import 'support/fake_settings_service.dart';

class _SilentPlatformPlayer extends PlatformPlayer {
  _SilentPlatformPlayer() : super(configuration: const PlayerConfiguration());
}

class _SetQueueCall {
  _SetQueueCall(this.tracks, this.autoPlay);

  final List<Track> tracks;
  final bool autoPlay;
}

class _FakeEngine extends AudioEngineService {
  _FakeEngine()
    : _states = StreamController<PlaybackSnapshot>.broadcast(),
      super(player: Player(platformPlayer: _SilentPlatformPlayer()));

  PlaybackSnapshot _state = const PlaybackSnapshot();
  final StreamController<PlaybackSnapshot> _states;
  final List<_SetQueueCall> setQueueCalls = <_SetQueueCall>[];
  final List<Track> added = <Track>[];

  @override
  PlaybackSnapshot get state => _state;

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
  Future<void> setQueue(
    List<Track> tracks, {
    int startIndex = 0,
    bool autoPlay = true,
  }) async {
    setQueueCalls.add(_SetQueueCall(tracks, autoPlay));
    _state = _state.copyWith(queue: List<Track>.unmodifiable(tracks));
    _states.add(_state);
  }

  @override
  Future<void> addToQueue(Track track) async {
    added.add(track);
    _state = _state.copyWith(queue: <Track>[..._state.queue, track]);
    _states.add(_state);
  }

  @override
  Future<void> dispose() async {
    await _states.close();
  }
}

Track _track(String id) => Track.online(
  externalId: 'audius:$id',
  streamUrl: 'https://example.invalid/$id.mp3',
  title: 'Pista $id',
  artist: 'Artista',
  durationMs: 1000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('enqueueQueue con cola vacía usa setQueue sin autoplay', () async {
    final _FakeEngine engine = _FakeEngine();
    final PlayerController controller = PlayerController(
      engine: engine,
      settings: FakeSettingsService(),
      session: PlaybackSessionService(FakeSettingsService()),
    );

    final List<Track> tracks = <Track>[_track('a'), _track('b')];
    await controller.enqueueQueue(tracks);

    expect(engine.setQueueCalls, hasLength(1));
    expect(engine.setQueueCalls.single.autoPlay, isFalse);
    expect(engine.setQueueCalls.single.tracks, tracks);
    expect(engine.added, isEmpty);
    controller.dispose();
    await engine.dispose();
  });

  test(
    'enqueueQueue con cola activa añade sin detener la reproducción',
    () async {
      final _FakeEngine engine = _FakeEngine();
      final PlayerController controller = PlayerController(
        engine: engine,
        settings: FakeSettingsService(),
        session: PlaybackSessionService(FakeSettingsService()),
      );

      await engine.setQueue(<Track>[_track('actual')]);
      final Track next = _track('nueva');
      await controller.enqueueQueue(<Track>[next]);

      expect(engine.added, <Track>[next]);
      expect(engine.setQueueCalls, hasLength(1));
      expect(controller.state.playback.queue, hasLength(2));
      controller.dispose();
      await engine.dispose();
    },
  );
}
