import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:polaris_music/core/models/playback_state.dart';
import 'package:polaris_music/core/models/track.dart';
import 'package:polaris_music/core/providers/app_providers.dart';
import 'package:polaris_music/core/providers/compact_style_provider.dart';
import 'package:polaris_music/core/services/audio_engine_service.dart';
import 'package:polaris_music/core/services/playback_session_service.dart';
import 'package:polaris_music/core/services/window_service.dart';
import 'package:polaris_music/core/theme/compact_style_config.dart';
import 'package:polaris_music/core/theme/theme_tokens.dart';
import 'package:polaris_music/core/theme/typography_config.dart';
import 'package:polaris_music/features/dynamic_island/domain/dynamic_island_controller.dart';
import 'package:polaris_music/features/dynamic_island/presentation/dynamic_island_overlay.dart';
import 'package:polaris_music/features/dynamic_island/presentation/island_providers.dart';
import 'package:polaris_music/features/player/domain/player_controller.dart';
import 'package:polaris_music/features/player/presentation/player_providers.dart';
import 'package:polaris_music/shared/widgets/compact_surface.dart';

import 'support/fake_settings_service.dart';

class _SilentPlatformPlayer extends PlatformPlayer {
  _SilentPlatformPlayer() : super(configuration: const PlayerConfiguration());
}

/// Motor sin audio cuyo único trabajo es entregar un snapshot fijo a la isla.
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

Future<void> _pumpIsland(
  WidgetTester tester,
  PlaybackSnapshot playback, {
  IslandMode mode = IslandMode.compact,
}) async {
  final FakeSettingsService settings = FakeSettingsService();
  final _SnapshotEngine engine = _SnapshotEngine(playback);
  final PlayerController player = PlayerController(
    engine: engine,
    settings: settings,
    session: PlaybackSessionService(settings),
  );
  final DynamicIslandController island = DynamicIslandController(
    settings: settings,
    engine: engine,
  );
  if (mode != IslandMode.compact) {
    island.state = island.state.copyWith(mode: mode);
  }
  final ValueNotifier<WindowUiState> window = ValueNotifier<WindowUiState>(
    const WindowUiState(mode: WindowMode.island),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        playerControllerProvider.overrideWith((Ref ref) => player),
        dynamicIslandControllerProvider.overrideWith((Ref ref) => island),
        windowStateProvider.overrideWithValue(window),
        compactStyleProvider(CompactSurface.island).overrideWith(
          (ref) => CompactStyleConfig.island.copyWith(autoHide: false),
        ),
      ],
      child: MaterialApp(
        home: SizedBox(
          width: 400,
          height: 128,
          child: IslandWindow(
            onRestore: () {},
            onHide: () {},
            peekEdge: IslandPeekEdge.top,
            onPeekEdgeChanged: (_) async {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final Track track = Track.online(
    externalId: 'island:regression',
    streamUrl: 'https://example.invalid/island.mp3',
    title: 'Pista de la isla',
    artist: 'Artista de prueba',
    durationMs: 60000,
  );

  testWidgets('con pista activa se ve el contenido y el progreso', (
    WidgetTester tester,
  ) async {
    await _pumpIsland(
      tester,
      PlaybackSnapshot(
        currentTrack: track,
        playing: true,
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 60),
      ),
    );

    expect(find.text('Pista de la isla'), findsOneWidget);
    expect(find.text('Artista de prueba'), findsOneWidget);

    // Regresión: un Positioned dentro de RepaintBoundary no es hijo directo
    // del Stack y lanza "Incorrect use of ParentDataWidget", tumbando la
    // cápsula entera en cuanto hay progreso real.
    for (final Element element in tester.elementList(find.byType(Positioned))) {
      expect(
        element.renderObject?.parentData,
        isA<StackParentData>(),
        reason: 'Positioned debe ser hijo directo del Stack de la isla',
      );
    }
  });

  testWidgets('expandida muestra la pista y los controles', (
    WidgetTester tester,
  ) async {
    await _pumpIsland(
      tester,
      PlaybackSnapshot(
        currentTrack: track,
        playing: true,
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 60),
      ),
      mode: IslandMode.expanded,
    );

    expect(find.text('Pista de la isla'), findsOneWidget);
    expect(find.text('Artista de prueba'), findsOneWidget);
    expect(find.byTooltip('Anterior'), findsOneWidget);
    expect(find.byTooltip('Siguiente'), findsOneWidget);
    // Sin archivo de carátula, el respaldo de la pista sigue visible.
    expect(find.byIcon(Icons.music_note_rounded), findsWidgets);
  });

  testWidgets('sin pista se ve el estado vacío de respaldo', (
    WidgetTester tester,
  ) async {
    await _pumpIsland(tester, const PlaybackSnapshot());

    expect(find.text('Polaris Music'), findsWidgets);
    expect(find.text('Nada en reproducción'), findsOneWidget);
  });

  testWidgets('la sombra del panel no queda encerrada en el recorte', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const KeyedSubtree(
        key: Key('isla-panel'),
        child: CompactPanel(
          style: ResolvedCompactStyle(
            tokens: PolarisTokens.fallback,
            accent: Color(0xFF7C5CFF),
            background: Color(0xFF101018),
            progressColor: Color(0xFF7C5CFF),
            volumeColor: Color(0xFF7C5CFF),
            radius: 38,
            opacity: 0.94,
            blur: 16,
            glow: true,
            typography: TypographyConfig.defaults,
            fontFamily: null,
            autoHide: false,
            autoHideSeconds: 8,
          ),
          child: SizedBox(width: 196, height: 64),
        ),
      ),
    );

    final Finder shadow = find.descendant(
      of: find.byKey(const Key('isla-panel')),
      matching: find.byWidgetPredicate(
        (Widget widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).boxShadow?.isNotEmpty == true,
      ),
    );
    expect(shadow, findsOneWidget);
    expect(
      find.ancestor(of: shadow, matching: find.byType(ClipRRect)),
      findsNothing,
      reason: 'ClipRRect recorta la sombra si envuelve al DecoratedBox',
    );

    final DecoratedBox shadowBox = tester.widget<DecoratedBox>(shadow);
    final BorderRadiusGeometry? shadowRadius =
        (shadowBox.decoration as BoxDecoration).borderRadius;
    final ClipRRect clip = tester.widget<ClipRRect>(
      find.descendant(of: shadow, matching: find.byType(ClipRRect)),
    );
    expect(clip.borderRadius, shadowRadius);
  });
}
