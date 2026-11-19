import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../di/service_locator.dart';
import '../services/settings_service.dart';
import '../theme/compact_style_config.dart';
import '../utils/logger.dart';

/// Persiste y expone un diseño distinto para cada superficie compacta.
///
/// Cada estilo vive en su propia clave de `settings`, así cambiar la isla no
/// altera el mini-reproductor ni el reproductor principal.
class CompactStyleController
    extends StateNotifier<Map<CompactSurface, CompactStyleConfig>> {
  CompactStyleController(this._settings)
    : super(<CompactSurface, CompactStyleConfig>{
        for (final CompactSurface surface in CompactSurface.values)
          surface: _read(_settings, surface),
      });

  static const String _tag = 'CompactStyle';

  final SettingsService _settings;

  String keyFor(CompactSurface surface) => switch (surface) {
    CompactSurface.island => AppConstants.keyCompactIslandStyle,
    CompactSurface.mini => AppConstants.keyCompactMiniStyle,
    CompactSurface.phone => AppConstants.keyCompactPhoneStyle,
    CompactSurface.player => AppConstants.keyCompactPlayerStyle,
  };

  CompactStyleConfig styleOf(CompactSurface surface) =>
      state[surface] ?? CompactStyleConfig.defaultsFor(surface);

  Future<void> update(CompactSurface surface, CompactStyleConfig style) async {
    state = <CompactSurface, CompactStyleConfig>{...state, surface: style};
    await _settings.setString(keyFor(surface), jsonEncode(style.toJson()));
  }

  Future<void> reset(CompactSurface surface) =>
      update(surface, CompactStyleConfig.defaultsFor(surface));

  Future<void> setAccent(CompactSurface surface, Color? color) =>
      update(surface, styleOf(surface).copyWith(accent: color));

  Future<void> setBackground(CompactSurface surface, Color? color) =>
      update(surface, styleOf(surface).copyWith(background: color));

  Future<void> setCardStyle(CompactSurface surface, CardStyle style) =>
      update(surface, styleOf(surface).copyWith(cardStyle: style));

  Future<void> setCornerRadius(CompactSurface surface, double value) => update(
    surface,
    styleOf(surface).copyWith(cornerRadius: value.clamp(8, 56)),
  );

  Future<void> setOpacity(CompactSurface surface, double value) => update(
    surface,
    styleOf(surface).copyWith(opacity: value.clamp(0.35, 1.0)),
  );

  Future<void> setBlur(CompactSurface surface, double value) =>
      update(surface, styleOf(surface).copyWith(blur: value.clamp(0, 32)));

  Future<void> setGlow(CompactSurface surface, bool value) =>
      update(surface, styleOf(surface).copyWith(glow: value));

  /// `null` vuelve a heredar la tipografía global.
  Future<void> setFontFamily(CompactSurface surface, String? familyId) =>
      update(surface, styleOf(surface).copyWith(fontFamilyId: familyId));

  /// `null` vuelve a heredar la escala global.
  Future<void> setFontScale(CompactSurface surface, double? scale) => update(
    surface,
    styleOf(surface).copyWith(fontScale: scale?.clamp(0.8, 1.4).toDouble()),
  );

  Future<void> setAutoHide(CompactSurface surface, bool value) =>
      update(surface, styleOf(surface).copyWith(autoHide: value));

  Future<void> setAutoHideSeconds(CompactSurface surface, int value) => update(
    surface,
    styleOf(surface).copyWith(autoHideSeconds: value.clamp(2, 60)),
  );

  static CompactStyleConfig _read(
    SettingsService settings,
    CompactSurface surface,
  ) {
    final String key = switch (surface) {
      CompactSurface.island => AppConstants.keyCompactIslandStyle,
      CompactSurface.mini => AppConstants.keyCompactMiniStyle,
      CompactSurface.phone => AppConstants.keyCompactPhoneStyle,
      CompactSurface.player => AppConstants.keyCompactPlayerStyle,
    };
    final String? raw = settings.getString(key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map<Object?, Object?>) {
          return CompactStyleConfig.fromJson(decoded.cast<String, Object?>());
        }
      } catch (error) {
        AppLog.w(
          _tag,
          'Estilo de ${surface.name} inválido; se usan valores base',
          error,
        );
      }
    }
    return CompactStyleConfig.defaultsFor(surface);
  }
}

final StateNotifierProvider<
  CompactStyleController,
  Map<CompactSurface, CompactStyleConfig>
>
compactStylesProvider =
    StateNotifierProvider<
      CompactStyleController,
      Map<CompactSurface, CompactStyleConfig>
    >((Ref ref) {
      return CompactStyleController(sl<SettingsService>());
    });

/// Atajo usado por las vistas y el editor de ajustes.
final ProviderFamily<CompactStyleConfig, CompactSurface> compactStyleProvider =
    Provider.family<CompactStyleConfig, CompactSurface>((
      Ref ref,
      CompactSurface surface,
    ) {
      return ref.watch(compactStylesProvider)[surface] ??
          CompactStyleConfig.defaultsFor(surface);
    });
