import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/constants/app_constants.dart';
import 'package:polaris_music/core/providers/motion_provider.dart';
import 'package:polaris_music/core/providers/theme_provider.dart';
import 'package:polaris_music/core/theme/app_theme_config.dart';
import 'package:polaris_music/core/theme/motion_config.dart';

import 'support/fake_settings_service.dart';

MotionConfig _configPersonalizada() => const MotionConfig(
  profile: MotionProfile.custom,
  speed: 1.35,
  transitions: true,
  ambient: false,
  gestures: true,
  island: false,
);

Map<String, Object?> _exportTema({Object? motion}) => <String, Object?>{
  'kind': 'polaris-theme',
  'version': 1,
  'config': AppThemeConfig.defaults.toJson(),
  'profiles': <Object>[],
  'motion': ?motion,
};

Future<void> _escribirMotion(
  FakeSettingsService settings,
  MotionConfig config,
) => settings.setString(
  AppConstants.keyMotionConfig,
  jsonEncode(config.toJson()),
);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Persistencia de MotionConfig', () {
    test(
      'readConfig lee la preferencia y cae en defaults si no hay nada',
      () async {
        final FakeSettingsService settings = FakeSettingsService();
        expect(MotionController.readConfig(settings), MotionConfig.defaults);

        final MotionConfig config = _configPersonalizada();
        await _escribirMotion(settings, config);

        expect(MotionController.readConfig(settings), config);
      },
    );

    test(
      'applyImported persiste y actualiza el estado del controlador',
      () async {
        final FakeSettingsService settings = FakeSettingsService();
        final MotionController controller = MotionController(settings);
        final MotionConfig config = _configPersonalizada();

        await controller.applyImported(config);

        expect(controller.state, config);
        expect(MotionController.readConfig(settings), config);
        expect(
          MotionController(settings).state,
          config,
          reason: 'Otro controlador debe leer lo persistido.',
        );
      },
    );

    test('reload recoge cambios externos sin recrear el controlador', () async {
      final FakeSettingsService settings = FakeSettingsService();
      final MotionController controller = MotionController(settings);
      final MotionConfig config = MotionConfig.fluid;

      await settings.setString(
        AppConstants.keyMotionConfig,
        jsonEncode(config.toJson()),
      );
      expect(controller.state, MotionConfig.defaults);

      await controller.reload();

      expect(controller.state, config);
    });
  });

  group('Movimiento en export/import del tema', () {
    test('exportJson incluye el bloque motion con la config vigente', () async {
      final FakeSettingsService settings = FakeSettingsService();
      final MotionConfig config = _configPersonalizada();
      await _escribirMotion(settings, config);

      final Object? decoded = jsonDecode(
        ThemeController(settings).exportJson(),
      );

      expect(decoded, isA<Map<Object?, Object?>>());
      final Map<Object?, Object?> json = decoded! as Map<Object?, Object?>;
      expect(json['kind'], 'polaris-theme');
      expect(json['version'], 1);
      expect(json['config'], isA<Map<Object?, Object?>>());
      expect(json['profiles'], isA<List<Object?>>());
      expect(json['motion'], isA<Map<Object?, Object?>>());
      expect(
        MotionConfig.fromJson(json['motion']! as Map<Object?, Object?>),
        config,
      );
    });

    test(
      'importJson restaura movimiento y devuelve el número de perfiles',
      () async {
        final FakeSettingsService settings = FakeSettingsService();
        final ThemeController controller = ThemeController(settings);
        final MotionConfig config = _configPersonalizada();
        final Map<String, Object?> perfil = CustomThemeProfile(
          id: 'perfil-1',
          name: 'Nocturno',
          config: AppThemeConfig.defaults,
        ).toJson();

        final int perfiles = await controller.importJson(
          jsonEncode(
            _exportTema(motion: config.toJson())
              ..['profiles'] = <Object>[perfil],
          ),
        );

        expect(perfiles, 1);
        expect(controller.profiles, hasLength(1));
        expect(controller.profiles.first.name, 'Nocturno');
        expect(MotionController.readConfig(settings), config);
      },
    );

    test('un export antiguo sin motion no modifica el movimiento', () async {
      final FakeSettingsService settings = FakeSettingsService();
      final MotionConfig config = _configPersonalizada();
      await _escribirMotion(settings, config);
      final ThemeController controller = ThemeController(settings);

      final int perfiles = await controller.importJson(
        jsonEncode(_exportTema()),
      );

      expect(perfiles, 0);
      expect(MotionController.readConfig(settings), config);
    });
  });
}
