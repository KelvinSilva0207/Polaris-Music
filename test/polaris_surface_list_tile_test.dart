import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/shared/widgets/polaris_surface.dart';

void main() {
  testWidgets('PolarisSurface da un Material propio a los ListTile', (
    WidgetTester tester,
  ) async {
    final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
    final List<String> errors = <String>[];
    FlutterError.onError = (FlutterErrorDetails details) {
      final String message = details.exceptionAsString();
      if (message.contains('ListTile background color')) errors.add(message);
    };
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PolarisSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(title: const Text('A'), onTap: () {}),
                SwitchListTile(
                  title: const Text('B'),
                  value: true,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // Se restaura antes de cualquier expect: flutter_test exige que el
    // handler original esté activo cuando termina el cuerpo del test.
    FlutterError.onError = previous;

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(errors, isEmpty, reason: errors.join('\n'));
  });
}
