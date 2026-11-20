import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/constants/app_constants.dart';
import 'package:polaris_music/core/providers/motion_provider.dart';
import 'package:polaris_music/core/theme/motion_config.dart';
import 'package:polaris_music/shared/widgets/motion_scope.dart';

import 'support/fake_settings_service.dart';

class _MotionProbe extends ConsumerWidget {
  const _MotionProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MotionConfig config = ref.watch(motionConfigProvider);
    final bool disableAnimations = MediaQuery.of(context).disableAnimations;
    return Column(
      children: <Widget>[
        Text('config:${config.profile.name}|${config.speed}'),
        Text('transiciones:${config.transitions}'),
        Text('media:$disableAnimations'),
      ],
    );
  }
}

Future<void> _bombear(WidgetTester tester, MotionConfig config) async {
  final FakeSettingsService settings = FakeSettingsService();
  await settings.setString(
    AppConstants.keyMotionConfig,
    jsonEncode(config.toJson()),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        motionControllerProvider.overrideWith(
          (Ref ref) => MotionController(settings),
        ),
      ],
      child: const MaterialApp(home: MotionScope(child: _MotionProbe())),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  testWidgets(
    'MotionScope expone la config efectiva y desactiva animaciones sin transiciones',
    (WidgetTester tester) async {
      final MotionConfig stored = MotionConfig.fluid.copyWith(
        transitions: false,
      );

      await _bombear(tester, stored);

      expect(find.text('config:custom|1.2'), findsOneWidget);
      expect(find.text('transiciones:false'), findsOneWidget);
      expect(find.text('media:true'), findsOneWidget);
    },
  );

  testWidgets('MotionScope conserva el perfil activo cuando hay transiciones', (
    WidgetTester tester,
  ) async {
    await _bombear(tester, MotionConfig.fluid);

    // `media` depende de la accesibilidad del sistema; la config efectiva debe
    // reflejar la preferencia guardada sin importar ese ajuste externo.
    expect(find.text('config:fluid|1.2'), findsOneWidget);
  });
}
