import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:polaris_music/core/services/audio_engine_service.dart';

class _TestPlatformPlayer extends PlatformPlayer {
  _TestPlatformPlayer() : super(configuration: const PlayerConfiguration());

  @override
  Future<void> setVolume(double value) async {}

  @override
  Future<void> setRate(double value) async {}

  void emitFilterFailure() {
    errorController.add('Failed to configure audio filter chain');
  }
}

/// Sustituye la propiedad `af` de libmpv sin abrir ningún archivo.
class _MemoryFilterSink implements AudioFilterSink {
  final List<String> writes = <String>[];
  String current = '';

  /// Simula el caso de mpv: acepta el valor pero el grafo sigue con el anterior.
  String? forcedReadback;

  @override
  Future<void> write(String filter) async {
    writes.add(filter);
    current = filter;
  }

  @override
  Future<String> read() async => forcedReadback ?? current;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String full = 'lavfi=[equalizer=f=100:t=q:w=1:g=3.00]';
  const String safe = 'lavfi=[equalizer=f=100:t=q:w=1:g=0.00]';

  Future<(AudioEngineService, _TestPlatformPlayer, _MemoryFilterSink)>
  build() async {
    final _TestPlatformPlayer platform = _TestPlatformPlayer();
    final _MemoryFilterSink sink = _MemoryFilterSink();
    final AudioEngineService engine = AudioEngineService(
      player: Player(platformPlayer: platform),
      filterSink: sink,
    );
    addTearDown(engine.dispose);
    await engine.initialize();
    return (engine, platform, sink);
  }

  Future<void> pumpEvents() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test('un fallo de mpv degrada la cadena y expone el estado', () async {
    final (engine, platform, sink) = await build();
    await engine.setAudioFilter(full, fallbacks: const <String>[safe, '']);

    expect(sink.writes, <String>[full]);
    expect(engine.audioFilterDegraded.value, isFalse);

    platform.emitFilterFailure();
    await pumpEvents();

    expect(sink.writes.last, safe);
    expect(engine.audioFilterDegraded.value, isTrue);
  });

  test(
    'reenviar la misma cadena después de un fallo vuelve a intentarla',
    () async {
      final (engine, platform, sink) = await build();
      await engine.setAudioFilter(full, fallbacks: const <String>[safe, '']);
      platform.emitFilterFailure();
      await pumpEvents();
      expect(sink.writes.last, safe);

      await engine.setAudioFilter(full, fallbacks: const <String>[safe, '']);

      expect(sink.writes.last, full);
      expect(engine.audioFilterDegraded.value, isFalse);
    },
  );

  test('la lectura engañosa de af también degrada', () async {
    final (engine, _, sink) = await build();
    sink.forcedReadback = '';

    await engine.setAudioFilter(full, fallbacks: const <String>[safe, '']);

    expect(sink.writes, contains(safe));
    expect(engine.audioFilterDegraded.value, isTrue);
  });

  test('al cambiar de pista se reintenta el plan completo', () async {
    final (engine, platform, sink) = await build();
    await engine.setAudioFilter(full, fallbacks: const <String>[safe, '']);
    platform.emitFilterFailure();
    await pumpEvents();
    expect(sink.writes.last, safe);

    await engine.reassertAudioFilter();

    expect(sink.writes.last, full);
    expect(engine.audioFilterDegraded.value, isFalse);
  });

  test('modo puro no degrada aunque af quede vacío', () async {
    final (engine, _, sink) = await build();
    await engine.setAudioFilter('', fallbacks: const <String>[]);

    expect(sink.writes, <String>['']);
    expect(engine.audioFilterDegraded.value, isFalse);
  });
}
