import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/features/equalizer/presentation/precision_controls.dart';

void main() {
  group('precisionStepValue', () {
    const double min = -12;
    const double max = 12;
    const double step = 1;

    test('ajusta de 1 en 1 dB dentro del rango de las bandas', () {
      expect(precisionStepValue(0, 1, min: min, max: max, step: step), 1);
      expect(precisionStepValue(0, -1, min: min, max: max, step: step), -1);
      expect(precisionStepValue(7, 1, min: min, max: max, step: step), 8);
    });

    test('nunca rebasa los límites de la banda', () {
      expect(precisionStepValue(max, 1, min: min, max: max, step: step), max);
      expect(precisionStepValue(min, -1, min: min, max: max, step: step), min);
    });

    test('mantiene el paso exacto con valores fraccionarios', () {
      expect(precisionStepValue(3.5, 1, min: min, max: max, step: step), 4.5);
      expect(
        precisionStepValue(-3.5, -1, min: min, max: max, step: step),
        -4.5,
      );
    });

    test('los pasos fraccionarios no acumulan ruido decimal', () {
      expect(
        precisionStepValue(0.22, 1, min: 0, max: 0.35, step: 0.01),
        closeTo(0.23, 1e-8),
      );
      expect(
        precisionStepValue(0.1, 1, min: 0.1, max: 18, step: 0.1),
        closeTo(0.2, 1e-8),
      );
    });
  });

  group('PrecisionSliderRow', () {
    testWidgets('cabe en móvil y aplica el valor escrito con doble toque', (
      WidgetTester tester,
    ) async {
      double? applied;
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: PrecisionSliderRow(
                  label: 'Ganancia',
                  value: 0,
                  min: -12,
                  max: 12,
                  step: 1,
                  decimals: 1,
                  unit: 'dB',
                  onChanged: (double value) => applied = value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('0.0 dB'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('0.0 dB'));
      await tester.pumpAndSettle();
      expect(find.text('Valor exacto'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '7');
      await tester.pump();
      expect(applied, 7);

      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(find.text('Valor exacto'), findsNothing);
      expect(applied, 7);
    });

    testWidgets('cancelar restaura el valor original', (
      WidgetTester tester,
    ) async {
      double applied = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: PrecisionSliderRow(
                  label: 'Ganancia',
                  value: 0,
                  min: -12,
                  max: 12,
                  step: 1,
                  decimals: 1,
                  unit: 'dB',
                  onChanged: (double value) => applied = value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('0.0 dB'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('0.0 dB'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '9');
      await tester.pump();
      expect(applied, 9);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(applied, 0);
    });
  });
}
