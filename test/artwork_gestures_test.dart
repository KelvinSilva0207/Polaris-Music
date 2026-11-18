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

  testWidgets('deslizar arriba abre las letras inmersivas', (
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
}
