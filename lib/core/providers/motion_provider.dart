import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../di/service_locator.dart';
import '../services/settings_service.dart';
import '../theme/motion_config.dart';
import '../utils/logger.dart';

/// Persistencia y control de Animaciones y Movimiento.
class MotionController extends StateNotifier<MotionConfig> {
  MotionController(this._settings) : super(readConfig(_settings));

  static const String _tag = 'Motion';

  final SettingsService _settings;

  /// Lectura pública para controladores sin acceso a un [Ref] (por ejemplo,
  /// `ThemeController` al exportar el tema).
  static MotionConfig readConfig(SettingsService settings) {
    final String? raw = settings.getString(AppConstants.keyMotionConfig);
    if (raw == null || raw.isEmpty) return MotionConfig.defaults;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<Object?, Object?>) {
        return MotionConfig.fromJson(decoded);
      }
    } catch (error) {
      AppLog.w(
        _tag,
        'Configuración de movimiento inválida; se usan valores base',
        error,
      );
    }
    return MotionConfig.defaults;
  }

  /// Vuelve a leer la preferencia persistida y refresca la UI tras una importación.
  Future<void> reload() async {
    state = readConfig(_settings);
  }

  /// Persiste una configuración ya resuelta (por ejemplo, la de un `.json`).
  Future<void> applyImported(MotionConfig config) => _persist(config);

  Future<void> applyProfile(MotionProfile profile) =>
      _persist(MotionConfig.fromProfile(profile));

  Future<void> setSpeed(double value) => _persist(
    state.copyWith(speed: value.isNaN ? state.speed : value.clamp(0.4, 1.6)),
  );

  Future<void> setCategory(MotionCategory category, bool enabled) {
    return _persist(switch (category) {
      MotionCategory.transitions => state.copyWith(transitions: enabled),
      MotionCategory.ambient => state.copyWith(ambient: enabled),
      MotionCategory.gestures => state.copyWith(gestures: enabled),
      MotionCategory.island => state.copyWith(island: enabled),
    });
  }

  Future<void> reset() => _persist(MotionConfig.defaults);

  Future<void> _persist(MotionConfig next) async {
    state = next;
    await _settings.setString(
      AppConstants.keyMotionConfig,
      jsonEncode(next.toJson()),
    );
  }
}

final StateNotifierProvider<MotionController, MotionConfig>
motionControllerProvider =
    StateNotifierProvider<MotionController, MotionConfig>((Ref ref) {
      return MotionController(sl<SettingsService>());
    });

/// Configuración observada por la UI. `MotionScope` puede sustituirla cuando
/// el sistema solicita reducir el movimiento.
final Provider<MotionConfig> motionConfigProvider = Provider<MotionConfig>((
  Ref ref,
) {
  return ref.watch(motionControllerProvider);
});
