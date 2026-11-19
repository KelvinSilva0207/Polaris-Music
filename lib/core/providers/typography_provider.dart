import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../di/service_locator.dart';
import '../services/font_service.dart';
import '../services/settings_service.dart';
import '../theme/font_catalog.dart';
import '../theme/typography_config.dart';

/// Servicio de fuentes importadas (el registro real en el motor).
final fontServiceProvider = Provider<FontService>((ref) => sl<FontService>());

/// Fuentes importadas por el usuario. Reconstruye la tema al cambiar.
final fontLibraryProvider =
    StateNotifierProvider<FontLibraryController, List<ImportedFont>>((ref) {
      return FontLibraryController(ref.read(fontServiceProvider));
    });

class FontLibraryController extends StateNotifier<List<ImportedFont>> {
  FontLibraryController(this._service) : super(_service.fonts);

  final FontService _service;

  Future<ImportedFont> importFont(String path) async {
    final ImportedFont font = await _service.importFont(path);
    state = _service.fonts;
    return font;
  }

  Future<void> removeFont(String id) async {
    await _service.removeFont(id);
    state = _service.fonts;
  }
}

/// Tipografía global persistida en `ui.typography`.
final typographyProvider =
    StateNotifierProvider<TypographyController, TypographyConfig>((ref) {
      return TypographyController(sl<SettingsService>());
    });

class TypographyController extends StateNotifier<TypographyConfig> {
  TypographyController(this._settings) : super(_read(_settings));

  final SettingsService _settings;

  static TypographyConfig _read(SettingsService settings) {
    final String? raw = settings.getString(AppConstants.keyTypography);
    if (raw == null || raw.isEmpty) return TypographyConfig.defaults;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return TypographyConfig.defaults;
      return TypographyConfig.fromJson(decoded);
    } on FormatException {
      return TypographyConfig.defaults;
    }
  }

  void setFamily(String familyId) =>
      _update(state.copyWith(familyId: familyId));

  void setScale(double scale) => _update(state.copyWith(scale: scale));

  void setHeadlineWeight(int weight) =>
      _update(state.copyWith(headlineWeight: weight));

  void setMetadataWeight(int weight) =>
      _update(state.copyWith(metadataWeight: weight));

  void setLyricsWeight(int weight) =>
      _update(state.copyWith(lyricsWeight: weight));

  void reset() => _update(TypographyConfig.defaults);

  void _update(TypographyConfig next) {
    state = next;
    _settings.setString(AppConstants.keyTypography, jsonEncode(next.toJson()));
  }
}
