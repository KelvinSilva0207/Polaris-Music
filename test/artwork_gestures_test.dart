import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:polaris_music/features/player/presentation/artwork_gestures.dart';

void main() {
  Future<String> swipe(WidgetTester tester, Offset delta) async {
    String action = 'none';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ArtworkGestures(
              size: 200,
              child: const SizedBox(width: 200, height: 200),
              onSeekFraction: (_) => action = 'seek',
              onPrevious: () => action = 'previous',
              onNext: () => action = 'next',
              onLyrics: () => action = 'lyrics',
              onMinimize: () => action = 'minimize',
            ),
          ),
        ),
      ),
    );

    final Offset center = tester.getCenter(find.byType(ArtworkGestures));
    final TestGesture gesture = await tester.startGesture(center);
    await gesture.moveBy(delta);
    await gesture.up();
    await tester.pump();
    return action;
  }

  testWidgets('deslizar a la izquierda reproduce la siguiente canción', (
    WidgetTester tester,
  ) async {
    expect(await swipe(tester, const Offset(-60, 0)), 'next');
  });

  testWidgets('deslizar a la derecha reproduce la canción anterior', (
    WidgetTester tester,
  ) async {
    expect(await swipe(tester, const Offset(60, 0)), 'previous');
  });

  testWidgets('deslizar arriba alterna las letras en la carátula', (
    WidgetTester tester,
  ) async {
    expect(await swipe(tester, const Offset(0, -60)), 'lyrics');
  });

  testWidgets('deslizar abajo minimiza el reproductor', (
    WidgetTester tester,
  ) async {
    expect(await swipe(tester, const Offset(0, 60)), 'minimize');
  });

  testWidgets('un toque en el centro no cambia de canción', (
    WidgetTester tester,
  ) async {
    expect(await swipe(tester, Offset.zero), 'none');
  });

  testWidgets(
    'arrastrar el borde derecho sube el volumen sin cambiar de pista',
    (WidgetTester tester) async {
      final List<double> volume = <double>[];
      String action = 'none';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ArtworkGestures(
                size: 200,
                onSeekFraction: (_) => action = 'seek',
                onPrevious: () => action = 'previous',
                onNext: () => action = 'next',
                onLyrics: () => action = 'lyrics',
                onMinimize: () => action = 'minimize',
                onVolumeDelta: volume.add,
                child: const SizedBox(width: 200, height: 200),
              ),
            ),
          ),
        ),
      );

      final Rect rect = tester.getRect(find.byType(ArtworkGestures));
      final TestGesture gesture = await tester.startGesture(
        Offset(rect.right - 10, rect.center.dy),
      );
      await gesture.moveBy(const Offset(0, -40));
      await gesture.up();
      await tester.pump();

      expect(volume, isNotEmpty);
      expect(volume.first, greaterThan(0));
      expect(action, 'none');
    },
  );

  testWidgets('arrastrar el borde izquierdo ajusta el brillo', (
    WidgetTester tester,
  ) async {
    final List<double> brightness = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ArtworkGestures(
              size: 200,
              onSeekFraction: (_) {},
              onPrevious: () {},
              onNext: () {},
              onLyrics: () {},
              onMinimize: () {},
              onBrightnessDelta: brightness.add,
              child: const SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      ),
    );

    final Rect rect = tester.getRect(find.byType(ArtworkGestures));
    final TestGesture gesture = await tester.startGesture(
      Offset(rect.left + 10, rect.center.dy),
    );
    await gesture.moveBy(const Offset(0, 30));
    await gesture.up();
    await tester.pump();

    expect(brightness, isNotEmpty);
    expect(brightness.first, lessThan(0));
  });

  testWidgets(
    'con el anillo activo, el borde derecho sigue controlando el volumen',
    (WidgetTester tester) async {
      final List<double> volume = <double>[];
      String action = 'none';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ArtworkGestures(
                size: 200,
                onSeekFraction: (_) => action = 'seek',
                onPrevious: () => action = 'previous',
                onNext: () => action = 'next',
                onLyrics: () => action = 'lyrics',
                onMinimize: () => action = 'minimize',
                onVolumeDelta: volume.add,
                seekEnabled: true,
                child: const SizedBox(width: 200, height: 200),
              ),
            ),
          ),
        ),
      );

      final Rect rect = tester.getRect(find.byType(ArtworkGestures));
      final TestGesture gesture = await tester.startGesture(
        Offset(rect.right - 10, rect.center.dy),
      );
      await gesture.moveBy(const Offset(0, -40));
      await gesture.up();
      await tester.pump();

      expect(volume, isNotEmpty);
      expect(volume.first, greaterThan(0));
      expect(action, 'none');
    },
  );

  testWidgets('con el anillo activo, tocar el borde busca en la canción', (
    WidgetTester tester,
  ) async {
    String action = 'none';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ArtworkGestures(
              size: 200,
              onSeekFraction: (_) => action = 'seek',
              onPrevious: () => action = 'previous',
              onNext: () => action = 'next',
              onLyrics: () => action = 'lyrics',
              onMinimize: () => action = 'minimize',
              seekEnabled: true,
              child: const SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      ),
    );

    final Rect rect = tester.getRect(find.byType(ArtworkGestures));
    final TestGesture gesture = await tester.startGesture(
      Offset(rect.right - 10, rect.center.dy),
    );
    await gesture.up();
    await tester.pump();

    expect(action, 'seek');
  });
}
