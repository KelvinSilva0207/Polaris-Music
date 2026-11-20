import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/theme/motion_config.dart';

void main() {
  group('MotionConfig', () {
    test('los perfiles predefinidos activan las categorías esperadas', () {
      expect(MotionConfig.fluid.transitions, isTrue);
      expect(MotionConfig.fluid.ambient, isTrue);
      expect(MotionConfig.balanced.speed, 1);
      expect(MotionConfig.minimal.transitions, isFalse);
      expect(MotionConfig.minimal.ambient, isFalse);
      expect(MotionConfig.minimal.gestures, isFalse);
      expect(MotionConfig.minimal.island, isFalse);
      expect(MotionConfig.presets, hasLength(3));
    });

    test(
      'la velocidad acorta duraciones y las categorías apagadas duran cero',
      () {
        const Duration base = Duration(milliseconds: 400);

        expect(MotionConfig.balanced.duration(base), base);
        expect(
          MotionConfig.fluid.duration(base).inMilliseconds,
          lessThan(base.inMilliseconds),
        );
        expect(MotionConfig.minimal.duration(base), Duration.zero);
        expect(
          MotionConfig.balanced.duration(
            base,
            category: MotionCategory.ambient,
          ),
          base,
        );
      },
    );

    test('editar cualquier categoría convierte el perfil en personalizado', () {
      final MotionConfig edited = MotionConfig.balanced.copyWith(
        gestures: false,
      );

      expect(edited.profile, MotionProfile.custom);
      expect(edited.gestures, isFalse);
      expect(edited.ambient, isTrue);
      expect(edited.enabled(MotionCategory.gestures), isFalse);
    });

    test('JSON conserva perfil, velocidad e interruptores', () {
      const MotionConfig original = MotionConfig(
        profile: MotionProfile.custom,
        speed: 1.35,
        transitions: true,
        ambient: false,
        gestures: true,
        island: false,
      );

      final MotionConfig restored = MotionConfig.fromJson(original.toJson());

      expect(restored, original);
      expect(restored.speed, 1.35);
      expect(restored.ambient, isFalse);
      expect(restored.island, isFalse);
    });

    test('un JSON incompleto o inválido cae en valores seguros', () {
      final MotionConfig fromProfile = MotionConfig.fromJson(<Object?, Object?>{
        'profile': 'minimal',
      });
      expect(fromProfile, MotionConfig.minimal);

      final MotionConfig normalized = MotionConfig.fromJson(<Object?, Object?>{
        'profile': 'no-existe',
        'speed': 99,
        'ambient': 'sí',
      });
      expect(normalized.profile, MotionProfile.custom);
      expect(normalized.speed, 1.6);
      expect(normalized.ambient, isTrue);
    });
  });
}
