import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:polaris_music/core/models/track.dart';
import 'package:polaris_music/core/services/audio_engine_service.dart';

class _RecordingPlatform extends PlatformPlayer {
  _RecordingPlatform() : super(configuration: const PlayerConfiguration());

  final List<String> calls = <String>[];

  @override
  Future<void> setVolume(double value) async {}

  @override
  Future<void> setRate(double value) async {}

  @override
  Future<void> setShuffle(bool value) async {}

  @override
  Future<void> setPlaylistMode(PlaylistMode mode) async {}

  @override
  Future<void> seek(Duration duration) async {}

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    calls.add('open');
    state = state.copyWith(playlist: playable as Playlist);
    playlistController.add(state.playlist);
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> jump(int index) async => calls.add('jump:$index');

  @override
  Future<void> stop() async {
    calls.add('stop');
    state = state.copyWith(playlist: const Playlist(<Media>[]));
  }

  void emit(String message) => errorController.add(message);

  void emitPlaylistIndex(int index, List<Track> tracks) {
    final Playlist playlist = Playlist(
      tracks.map((Track track) => Media(track.path)).toList(),
      index: index,
    );
    state = state.copyWith(playlist: playlist);
    playlistController.add(playlist);
  }

  void emitCompleted() => completedController.add(true);
}

class _MemoryFilterSink implements AudioFilterSink {
  final List<String> writes = <String>[];

  @override
  Future<void> write(String filter) async => writes.add(filter);

  @override
  Future<String> read() async => '';
}

Future<void> pumpEvents() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late Track first;
  late Track second;
  late Track broken;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('polaris_open_failure_');
    first = Track(
      id: 1,
      path: '${dir.path}${Platform.pathSeparator}primera.mp3',
      title: 'Primera',
      artist: 'Artista',
      album: 'Álbum',
      durationMs: 60000,
    );
    second = Track(
      id: 2,
      path: '${dir.path}${Platform.pathSeparator}segunda.mp3',
      title: 'Segunda',
      artist: 'Artista',
      album: 'Álbum',
      durationMs: 90000,
    );
    // Una ruta que no existe nunca es legible, en ningún sistema operativo.
    broken = Track(
      id: 3,
      path: '${dir.path}${Platform.pathSeparator}desaparecida.mp3',
      title: 'Rota',
      artist: 'Artista',
      album: 'Álbum',
      durationMs: 30000,
    );
    await File(first.path).writeAsBytes(<int>[1, 2, 3]);
    await File(second.path).writeAsBytes(<int>[4, 5, 6]);
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  Future<(AudioEngineService, _RecordingPlatform, _MemoryFilterSink)>
  build() async {
    final _RecordingPlatform platform = _RecordingPlatform();
    final _MemoryFilterSink sink = _MemoryFilterSink();
    final AudioEngineService engine = AudioEngineService(
      player: Player(platformPlayer: platform),
      filterSink: sink,
    );
    addTearDown(engine.dispose);
    await engine.initialize();
    await engine.setQueue(<Track>[first, second], autoPlay: true);
    await pumpEvents();
    return (engine, platform, sink);
  }

  test('un fallo local se detiene en la pista sin encadenar saltos', () async {
    final (engine, platform, sink) = await build();

    platform.emit('Failed to open ${first.path}.');
    await pumpEvents();

    expect(engine.state.index, 0);
    expect(engine.state.currentTrack?.id, first.id);
    expect(engine.state.playing, isFalse);
    expect(engine.state.error, contains(first.title));
    expect(engine.state.error, isNot(contains(dir.path)));
    expect(engine.state.queue.map((Track t) => t.id), <int>[1, 2]);
    expect(platform.calls, contains('pause'));
    expect(platform.calls, isNot(contains('jump:1')));
    expect(platform.calls, isNot(contains('stop')));
    // El DSP nunca se reconfigura por un fallo de apertura.
    expect(sink.writes, isEmpty);

    // mpv puede publicar el avance a la pista siguiente justo después del
    // error. No debe cambiar la pista señalada ni borrar el aviso.
    platform.emitPlaylistIndex(1, <Track>[first, second]);
    await pumpEvents();
    expect(engine.state.index, 0);
    expect(engine.state.error, contains(first.title));

    // Un error duplicado no rearma el aviso ni vuelve a pausar.
    final String? error = engine.state.error;
    final int calls = platform.calls.length;
    platform.emit('Failed to open ${first.path}.');
    await pumpEvents();
    expect(engine.state.error, error);
    expect(platform.calls.length, calls);
  });

  test('un archivo ilegible elegido a mano no dispara recursión', () async {
    final (engine, platform, _) = await build();
    await engine.setQueue(<Track>[first, broken], autoPlay: true);
    await pumpEvents();
    platform.calls.clear();

    await engine.playIndex(1);
    await pumpEvents();

    expect(engine.state.index, 0);
    expect(engine.state.currentTrack?.id, first.id);
    expect(engine.state.error, contains('Rota'));
    expect(platform.calls, isNot(contains('jump:1')));
    expect(platform.calls, isNot(contains('jump:0')));
  });

  test('un fallo no se contabiliza como pista completada', () async {
    final (engine, platform, _) = await build();

    platform.emit('Failed to open ${first.path}.');
    await pumpEvents();
    platform.emitCompleted();
    await pumpEvents();

    expect(engine.state.completed, isFalse);
  });

  test('reanudar reintenta la misma pista y permite volver a avisar', () async {
    final (engine, platform, _) = await build();

    platform.emit('Failed to open ${first.path}.');
    await pumpEvents();
    expect(engine.state.error, isNotNull);

    await engine.play();
    await pumpEvents();

    expect(engine.state.error, isNull);
    expect(platform.calls, contains('jump:0'));
    expect(platform.calls, contains('play'));

    platform.emit('Failed to open ${first.path}.');
    await pumpEvents();
    expect(engine.state.error, contains(first.title));
  });
}
