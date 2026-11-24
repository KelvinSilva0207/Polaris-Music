import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/constants/app_constants.dart';
import 'package:polaris_music/core/providers/motion_provider.dart';
import 'package:polaris_music/core/theme/motion_config.dart';
import 'package:polaris_music/shared/widgets/light_motion.dart';
import 'package:polaris_music/shared/widgets/motion_scope.dart';

import 'support/fake_settings_service.dart';

class _FadeProbe extends StatelessWidget {
  const _FadeProbe({required this.value});

  final ValueNotifier<double> value;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: value,
      builder: (BuildContext context, double opacity, Widget? child) {
        return KeyedSubtree(
          key: const Key('fade-probe'),
          child: MotionFade(
            opacity: opacity,
            category: MotionCategory.gestures,
            duration: const Duration(milliseconds: 200),
            child: const SizedBox(width: 10, height: 10),
          ),
        );
      },
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  MotionConfig config,
  ValueNotifier<double> value,
) async {
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
      child: MaterialApp(
        home: MotionScope(child: _FadeProbe(value: value)),
      ),
    ),
  );
}

double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(
        of: find.byKey(const Key('fade-probe')),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

class _ScopeProbe extends ConsumerWidget {
  const _ScopeProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool disabled = MediaQuery.of(context).disableAnimations;
    final bool ambient = ref.watch(ambientMotionGateProvider);
    return Text('media:$disabled|ambient:$ambient');
  }
}

Future<void> _pumpScope(WidgetTester tester, MotionConfig config) async {
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
      child: MaterialApp(home: MotionScope(child: const _ScopeProbe())),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Modo puro / rendimiento visual', () {
    test('desactiva las cuatro categorías sin borrar el perfil', () {
      final MotionConfig pure = MotionConfig.alto.copyWith(pure: true);

      expect(pure.profile, MotionProfile.alto);
      expect(pure.pure, isTrue);
      expect(pure.transitions, isTrue);
      expect(pure.ambient, isTrue);
      expect(pure.anyAnimation, isFalse);
      for (final MotionCategory category in MotionCategory.values) {
        expect(pure.enabled(category), isFalse, reason: category.name);
        expect(
          pure.duration(const Duration(milliseconds: 400), category: category),
          Duration.zero,
          reason: category.name,
        );
      }
      expect(pure.intensity, 0);
      expect(pure.travelScale, 0.55);
    });

    test('el perfil alto habilita duraciones, intensidad y recorrido', () {
      const MotionConfig alto = MotionConfig.alto;

      expect(alto.pure, isFalse);
      expect(alto.anyAnimation, isTrue);
      for (final MotionCategory category in MotionCategory.values) {
        expect(alto.enabled(category), isTrue, reason: category.name);
        expect(
          alto.duration(const Duration(milliseconds: 400), category: category),
          greaterThan(Duration.zero),
          reason: category.name,
        );
      }
      expect(alto.intensity, 1);
      expect(alto.travelScale, 1);
      expect(alto.sectionInCurve, Curves.elasticOut);
    });

    test('sobrescribe la configuración sin convertir el perfil en custom', () {
      final MotionConfig pure = MotionConfig.alto.copyWith(pure: true);
      final MotionConfig restored = MotionConfig.fromJson(pure.toJson());

      expect(restored, pure);
      expect(restored.profile, MotionProfile.alto);
      expect(restored.pure, isTrue);

      final MotionConfig again = pure.copyWith(pure: false);
      expect(again.profile, MotionProfile.alto);
      expect(again.pure, isFalse);
      expect(again.enabled(MotionCategory.ambient), isTrue);
    });

    test('un backup antiguo sin bloque pure conserva el movimiento', () {
      final MotionConfig restored = MotionConfig.fromJson(<Object?, Object?>{
        'profile': 'alto',
      });

      expect(restored.pure, isFalse);
      expect(restored.anyAnimation, isTrue);
    });

    test('setPure persiste el flag sin tocar el perfil', () async {
      final FakeSettingsService settings = FakeSettingsService();
      await settings.setString(
        AppConstants.keyMotionConfig,
        jsonEncode(MotionConfig.alto.toJson()),
      );
      final MotionController controller = MotionController(settings);

      await controller.setPure(true);
      expect(controller.state.profile, MotionProfile.alto);
      expect(MotionController.readConfig(settings).pure, isTrue);

      await controller.setPure(false);
      expect(controller.state.profile, MotionProfile.alto);
      expect(MotionController.readConfig(settings).pure, isFalse);
      controller.dispose();
    });
  });

  group('Animaciones ligeras de presentación', () {
    testWidgets('el modo puro aplica la opacidad final sin animar', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<double> value = ValueNotifier<double>(1);
      addTearDown(value.dispose);
      await _pump(tester, MotionConfig.alto.copyWith(pure: true), value);

      value.value = 0.25;
      await tester.pump();

      expect(_opacity(tester), closeTo(0.25, 0.001));
    });

    testWidgets('el perfil alto interpola la opacidad hasta el destino', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<double> value = ValueNotifier<double>(1);
      addTearDown(value.dispose);
      await _pump(tester, MotionConfig.alto, value);

      value.value = 0;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final double intermediate = _opacity(tester);
      expect(intermediate, greaterThan(0));
      expect(intermediate, lessThan(1));

      await tester.pumpAndSettle();
      expect(_opacity(tester), 0);
    });

    testWidgets(
      'MotionScope apaga MediaQuery y el gate ambiental en modo puro',
      (WidgetTester tester) async {
        await _pumpScope(tester, MotionConfig.alto.copyWith(pure: true));

        expect(find.text('media:true|ambient:false'), findsOneWidget);
      },
    );

    testWidgets('MotionScope mantiene el gate ambiental con el perfil alto', (
      WidgetTester tester,
    ) async {
      await _pumpScope(tester, MotionConfig.alto);

      expect(find.text('media:false|ambient:true'), findsOneWidget);
    });
  });
}
