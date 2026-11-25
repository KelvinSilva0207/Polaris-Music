import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:polaris_music/core/models/playback_state.dart';
import 'package:polaris_music/core/models/track.dart';
import 'package:polaris_music/core/providers/compact_style_provider.dart';
import 'package:polaris_music/core/services/audio_engine_service.dart';
import 'package:polaris_music/core/services/playback_session_service.dart';
import 'package:polaris_music/core/theme/compact_style_config.dart';
import 'package:polaris_music/features/player/domain/player_controller.dart';
import 'package:polaris_music/features/player/presentation/mini_player_bar.dart';
import 'package:polaris_music/features/player/presentation/player_providers.dart';
import 'package:polaris_music/features/player/presentation/tray_mini_player.dart';

import 'support/fake_settings_service.dart';

class _SilentPlatformPlayer extends PlatformPlayer {
  _SilentPlatformPlayer() : super(configuration: const PlayerConfiguration());
}

/// Motor sin audio: entrega un snapshot fijo para que el test no dependa de mpv.
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

Future<void> _pumpMini(
  WidgetTester tester,
  PlaybackSnapshot playback, {
  required bool tray,
}) async {
  final FakeSettingsService settings = FakeSettingsService();
  final _SnapshotEngine engine = _SnapshotEngine(playback);
  final PlayerController player = PlayerController(
    engine: engine,
    settings: settings,
    session: PlaybackSessionService(settings),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        playerControllerProvider.overrideWith((Ref ref) => player),
        compactStyleProvider(CompactSurface.mini)
            .overrideWith((ref) => CompactStyleConfig.mini),
      ],
      child: MaterialApp(
        home: SizedBox(
          width: 430,
          height: 152,
          child: tray
              ? TrayMiniPlayer(onOpen: () {}, onHide: () {})
              : MiniPlayerBar(onOpen: () {}),
        ),
      ),
    ),
  );
  // La barra normal tiene una onda ambiental que se repite: un solo frame
  // basta para comprobar el contenido sin esperar a que terminen los tickers.
  if (tray) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final Track track = Track.online(
    externalId: 'mini:regression',
    streamUrl: 'https://example.invalid/mini.mp3',
    title: 'Pista del mini',
    artist: 'Artista del mini',
    durationMs: 60000,
  );

  final PlaybackSnapshot playing = PlaybackSnapshot(
    currentTrack: track,
    playing: true,
    position: const Duration(seconds: 30),
    duration: const Duration(seconds: 60),
    volume: 70,
  );

  testWidgets(
    'mini de bandeja con pista activa renderiza contenido y controles',
    (WidgetTester tester) async {
      await _pumpMini(tester, playing, tray: true);

      expect(find.text('Pista del mini'), findsOneWidget);
      expect(find.text('Artista del mini'), findsOneWidget);
      expect(find.byTooltip('Anterior'), findsOneWidget);
      expect(find.byTooltip('Siguiente'), findsOneWidget);
      expect(find.byTooltip('Abrir ventana principal'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);

      // Regresión: un Positioned dentro de RepaintBoundary lanza
      // "Incorrect use of ParentDataWidget" al avanzar la pista y deja el mini
      // reducido a la sombra de la ventana.
      for (final Element element in tester.elementList(
        find.byType(Positioned),
      )) {
        expect(
          element.renderObject?.parentData,
          isA<StackParentData>(),
          reason: 'Positioned debe ser hijo directo del Stack del mini',
        );
      }

      final Finder shadow = find.descendant(
        of: find.byType(TrayMiniPlayer),
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).boxShadow?.isNotEmpty ==
                  true,
        ),
      );
      expect(shadow, findsOneWidget);
      expect(
        find.ancestor(of: shadow, matching: find.byType(ClipRRect)),
        findsNothing,
        reason: 'la sombra no debe quedar recortada por ClipRRect',
      );
    },
  );

  testWidgets('mini de bandeja sin pista muestra el estado de respaldo', (
    WidgetTester tester,
  ) async {
    await _pumpMini(tester, const PlaybackSnapshot(), tray: true);

    expect(find.text('Polaris en espera'), findsOneWidget);
    expect(find.text('Elige una canción desde la biblioteca'), findsOneWidget);
    expect(find.text('Abrir'), findsOneWidget);
    expect(find.byTooltip('Ocultar en la bandeja'), findsOneWidget);
  });

  testWidgets('barra compacta de la ventana normal muestra la pista', (
    WidgetTester tester,
  ) async {
    await _pumpMini(tester, playing, tray: false);

    expect(find.text('Pista del mini'), findsOneWidget);
    expect(find.text('Artista del mini'), findsOneWidget);
    expect(find.text('00:30'), findsOneWidget);
    expect(find.text('01:00'), findsOneWidget);
    expect(find.byTooltip('Siguiente'), findsOneWidget);
  });

  testWidgets('barra compacta sin pista muestra su respaldo', (
    WidgetTester tester,
  ) async {
    await _pumpMini(tester, const PlaybackSnapshot(), tray: false);

    expect(find.text('Sin reproducción activa'), findsOneWidget);
    expect(find.text('Abrir'), findsOneWidget);
  });
}
