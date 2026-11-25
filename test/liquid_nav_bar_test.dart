import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/app/app_navigation.dart';
import 'package:polaris_music/shared/widgets/liquid_nav_bar.dart';

void main() {
  testWidgets('dos controladores comparten tickers sin error de vsync', (
    WidgetTester tester,
  ) async {
    AppSection selected = AppSection.player;
    LiquidNavLayout layout = LiquidNavLayout.bottom;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              children: <Widget>[
                TextButton(
                  onPressed: () => setState(
                    () => layout = layout == LiquidNavLayout.bottom
                        ? LiquidNavLayout.top
                        : LiquidNavLayout.bottom,
                  ),
                  child: const Text('Cambiar layout'),
                ),
                SizedBox(
                  width: 800,
                  child: LiquidNavBar(
                    selected: selected,
                    onChanged: (AppSection section) =>
                        setState(() => selected = section),
                    layout: layout,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // El indicador y el despliegue usan controladores distintos con el mismo
    // TickerProvider: antes esto lanzaba "multiple tickers were created".
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.library_music_outlined));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cambiar layout'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byType(LiquidNavBar), findsOneWidget);
  });
}
