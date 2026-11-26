import 'package:drift/drift.dart'
    show
        BatchedStatements,
        QueryExecutor,
        QueryExecutorUser,
        SqlDialect,
        TransactionExecutor,
        driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:polaris_music/core/constants/app_constants.dart';
import 'package:polaris_music/core/database/app_database.dart';
import 'package:polaris_music/core/models/equalizer_config.dart';
import 'package:polaris_music/core/services/audio_engine_service.dart';
import 'package:polaris_music/features/equalizer/domain/equalizer_controller.dart';
import 'package:polaris_music/features/equalizer/presentation/eq_curve_painter.dart';

import 'support/fake_settings_service.dart';

class _SilentPlatformPlayer extends PlatformPlayer {
  _SilentPlatformPlayer() : super(configuration: const PlayerConfiguration());
}

class _RecordingEngine extends AudioEngineService {
  _RecordingEngine()
    : super(player: Player(platformPlayer: _SilentPlatformPlayer()));

  final List<String> filters = <String>[];

  @override
  bool get dspAvailable => true;

  @override
  Future<void> setAudioFilter(
    String filter, {
    List<String> fallbacks = const <String>[],
  }) async {
    filters.add(filter);
  }
}

class _EmptyEqDao extends EqDao {
  _EmptyEqDao(super.db);

  @override
  Future<List<EqPresetRow>> getAll() async => <EqPresetRow>[];
}

class _InertExecutor extends QueryExecutor {
  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async => true;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) => throw UnimplementedError();

  @override
  Future<int> runInsert(String statement, List<Object?> args) =>
      throw UnimplementedError();

  @override
  Future<int> runUpdate(String statement, List<Object?> args) =>
      throw UnimplementedError();

  @override
  Future<int> runDelete(String statement, List<Object?> args) =>
      throw UnimplementedError();

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) =>
      throw UnimplementedError();

  @override
  Future<void> runBatched(BatchedStatements statements) =>
      throw UnimplementedError();

  @override
  TransactionExecutor beginTransaction() => throw UnimplementedError();

  @override
  QueryExecutor beginExclusive() => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  EqualizerController build({
    required FakeSettingsService settings,
    required _RecordingEngine engine,
  }) {
    final AppDatabase db = AppDatabase.forTesting(_InertExecutor());
    return EqualizerController(_EmptyEqDao(db), settings, engine);
  }

  test('arrastrar bandas escribe una sola cadena DSP al soltar', () async {
    final FakeSettingsService settings = FakeSettingsService();
    await settings.setBool(AppConstants.keyEqEnabled, true);
    final _RecordingEngine engine = _RecordingEngine();
    final EqualizerController controller = build(
      settings: settings,
      engine: engine,
    );
    addTearDown(controller.dispose);
    await controller.load();
    expect(engine.filters, hasLength(1));

    await controller.setBand(0, 3);
    await controller.setBand(0, 5);
    await controller.setBand(0, 7);
    expect(engine.filters, hasLength(1));
    expect(controller.state.bands.first, 7);

    await Future<void>.delayed(const Duration(milliseconds: 220));
    expect(engine.filters, hasLength(2));
    expect(engine.filters.last, contains('g=7.00'));
  });

  test(
    'el interruptor por salida responde aunque no haya dispositivo',
    () async {
      final EqualizerController controller = build(
        settings: FakeSettingsService(),
        engine: _RecordingEngine(),
      );
      addTearDown(controller.dispose);
      await controller.load();

      expect(controller.state.perDeviceProfiles, isFalse);
      await controller.setPerDeviceProfiles(true);
      expect(controller.state.perDeviceProfiles, isTrue);
    },
  );

  testWidgets('la curva muestra dB y frecuencias legibles', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EqCurveView(config: EqualizerConfig())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+12 dB'), findsOneWidget);
    expect(find.text('-12 dB'), findsOneWidget);
    expect(find.text('1 kHz'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('cerrar durante el arrastre no pierde el último valor', () async {
    final FakeSettingsService settings = FakeSettingsService();
    final EqualizerController controller = build(
      settings: settings,
      engine: _RecordingEngine(),
    );
    await controller.load();

    await controller.setBand(0, 4);
    controller.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final String raw = settings.getString(AppConstants.keyEqConfig)!;
    expect(EqualizerConfig.deserialize(raw).bands.first, 4);
  });
}
