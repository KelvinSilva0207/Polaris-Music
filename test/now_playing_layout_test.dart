import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:polaris_music/app/app_navigation.dart';
import 'package:polaris_music/app/app_shell.dart';
import 'package:polaris_music/core/database/app_database.dart';
import 'package:polaris_music/core/models/playback_state.dart';
import 'package:polaris_music/core/models/track.dart';
import 'package:polaris_music/core/providers/app_providers.dart';
import 'package:polaris_music/core/providers/compact_style_provider.dart';
import 'package:polaris_music/core/providers/motion_provider.dart';
import 'package:polaris_music/core/providers/theme_provider.dart';
import 'package:polaris_music/core/services/audio_engine_service.dart';
import 'package:polaris_music/core/services/audio_output_selection_service.dart';
import 'package:polaris_music/core/services/playback_session_service.dart';
import 'package:polaris_music/core/services/settings_service.dart';
import 'package:polaris_music/core/services/window_service.dart';
import 'package:polaris_music/core/theme/app_theme.dart';
import 'package:polaris_music/core/theme/app_theme_config.dart';
import 'package:polaris_music/core/theme/compact_style_config.dart';
import 'package:polaris_music/features/equalizer/domain/equalizer_controller.dart';
import 'package:polaris_music/features/equalizer/presentation/equalizer_providers.dart';
import 'package:polaris_music/features/player/domain/player_controller.dart';
import 'package:polaris_music/features/player/presentation/audio_output_providers.dart';
import 'package:polaris_music/features/player/presentation/now_playing_screen.dart';
import 'package:polaris_music/features/player/presentation/player_providers.dart';

import 'support/fake_settings_service.dart';

class _SilentPlatformPlayer extends PlatformPlayer {
  _SilentPlatformPlayer() : super(configuration: const PlayerConfiguration());
}

class _SnapshotEngine extends AudioEngineService {
  _SnapshotEngine(this._state)
    : _states = StreamController<PlaybackSnapshot>.broadcast(),
      super(player: Player(platformPlayer: _SilentPlatformPlayer()));

  final PlaybackSnapshot _state;
  final StreamController<PlaybackSnapshot> _states;

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
  Future<void> dispose() async {
    await _states.close();
  }
}

class _SnapshotEqualizerController extends EqualizerController {
  _SnapshotEqualizerController(
    AppDatabase db,
    SettingsService settings,
    AudioEngineService engine,
  ) : super(db.eqDao, settings, engine);
}

/// Ejecutor inerte: el DAO del ecualizador nunca recibe consultas en este test.
class _InertExecutor extends drift.QueryExecutor {
  @override
  drift.SqlDialect get dialect => drift.SqlDialect.sqlite;

  @override
  Future<bool> ensureOpen(drift.QueryExecutorUser user) async => true;

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
  Future<void> runBatched(drift.BatchedStatements statements) =>
      throw UnimplementedError();

  @override
  drift.TransactionExecutor beginTransaction() => throw UnimplementedError();

  @override
  drift.QueryExecutor beginExclusive() => throw UnimplementedError();
}

final Track _track = Track(
  id: 7,
  path: '/music/cancion.mp3',
  title: 'Canción de prueba',
  artist: 'Artista',
  album: 'Álbum',
  durationMs: 60000,
  isFavorite: true,
);

Future<void> _pumpPlayer(WidgetTester tester) async {
  final FakeSettingsService settings = FakeSettingsService();
  final _SnapshotEngine engine = _SnapshotEngine(
    PlaybackSnapshot(
      currentTrack: _track,
      queue: <Track>[_track],
      index: 0,
      playing: false,
      position: const Duration(seconds: 12),
      duration: const Duration(seconds: 60),
    ),
  );
  final PlayerController player = PlayerController(
    engine: engine,
    settings: settings,
    session: PlaybackSessionService(settings),
  );
  final AppDatabase db = AppDatabase.forTesting(_InertExecutor());
  final AudioOutputSelectionService output = AudioOutputSelectionService(
    engine: engine,
    settings: settings,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        playerControllerProvider.overrideWith((Ref ref) => player),
        audioEngineProvider.overrideWithValue(engine),
        themeConfigProvider.overrideWithValue(AppThemeConfig.defaults),
        compactStyleProvider(CompactSurface.player)
            .overrideWithValue(CompactStyleConfig.player),
        windowStateProvider.overrideWithValue(
          ValueNotifier<WindowUiState>(const WindowUiState()),
        ),
        motionControllerProvider.overrideWith(
          (Ref ref) => MotionController(settings),
        ),
        audioOutputSelectionProvider.overrideWith((Ref ref) => output),
        equalizerControllerProvider.overrideWith(
          (Ref ref) => _SnapshotEqualizerController(db, settings, engine),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.fromConfig(AppThemeConfig.defaults),
        home: Column(
          children: <Widget>[
            const _SectionProbe(),
            Expanded(
              child: SizedBox(
                width: 420,
                height: 520,
                child: NowPlayingScreen(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

class _SectionProbe extends ConsumerWidget {
  const _SectionProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Text('section:${ref.watch(appSectionProvider).name}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test('el reproductor no paga el hueco de la mini barra', () {
    expect(navClearanceFor(AppSection.player, 24), 24);
    expect(navClearanceFor(AppSection.library, 24), 108);
    expect(navClearanceFor(AppSection.settings, 0), 84);
  });

  testWidgets('⋮ queda bajo el corazón y la cola dentro del panel', (
    WidgetTester tester,
  ) async {
    await _pumpPlayer(tester);

    final Finder player = find.byKey(const ValueKey<String>('player'));
    final Finder heart = find.byTooltip('Quitar de favoritos');
    final Finder more = find.byTooltip('Más controles del reproductor');

    expect(player, findsOneWidget);
    expect(heart, findsOneWidget);
    expect(more, findsOneWidget);
    expect(
      find.descendant(of: player, matching: more),
      findsOneWidget,
      reason: 'el ⋮ debe vivir dentro del reproductor',
    );
    expect(tester.getCenter(more).dy, greaterThan(tester.getCenter(heart).dy));

    final Finder queue = find.byTooltip('Cola (1)');
    expect(queue, findsOneWidget);
    expect(
      find.ancestor(
        of: queue,
        matching: find.byKey(const ValueKey<String>('player-controls-surface')),
      ),
      findsOneWidget,
      reason: 'la cola no debe quedar como botón suelto',
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('el ⋮ del reproductor conserva la navegación', (
    WidgetTester tester,
  ) async {
    await _pumpPlayer(tester);
    expect(find.text('section:player'), findsOneWidget);

    await tester.tap(find.byTooltip('Más controles del reproductor'));
    await tester.pumpAndSettle();
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);

    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    expect(find.text('section:library'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
