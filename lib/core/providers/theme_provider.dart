import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../di/service_locator.dart';
import '../services/settings_service.dart';
import '../theme/app_theme_config.dart';
import '../utils/logger.dart';
import '../utils/palette_extractor.dart';

/// Motor de personalización visual de Polaris.
///
/// Mantiene la [AppThemeConfig] activa y los perfiles guardados por el usuario.
/// Todo se persiste como JSON en la tabla `settings` de Drift; la UI observa
/// este provider y se reconstruye en vivo, sin reiniciar.
class ThemeController extends StateNotifier<ThemeState> {
  ThemeController(this._settings)
    : super(
        ThemeState(
          config: _readConfig(_settings),
          profiles: _readProfiles(_settings),
        ),
      );

  static const String _tag = 'Theme';

  final SettingsService _settings;

  AppThemeConfig get config => state.config;
  List<CustomThemeProfile> get profiles => state.profiles;

  static AppThemeConfig _readConfig(SettingsService settings) {
    final String? raw = settings.getString(AppConstants.keyThemeConfig);
    if (raw != null && raw.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map<Object?, Object?>) {
          return AppThemeConfig.fromJson(decoded.cast<String, Object?>());
        }
      } catch (error) {
        AppLog.w(
          _tag,
          'Configuración de tema inválida; se usan valores base',
          error,
        );
      }
    }

    // Compatibilidad con Fase 1: solo existía `theme.accent`.
    final String legacy = settings.stringOr(AppConstants.keyAccentColor, '');
    if (legacy.isNotEmpty) {
      final String hex = legacy.replaceFirst('0x', '').replaceFirst('#', '');
      final int? value = int.tryParse(hex, radix: 16);
      if (value != null) {
        return AppThemeConfig.defaults.copyWith(accent: Color(value));
      }
    }
    return AppThemeConfig.defaults;
  }

  static List<CustomThemeProfile> _readProfiles(SettingsService settings) {
    final String? raw = settings.getString(AppConstants.keyThemeProfiles);
    if (raw == null || raw.isEmpty) return const <CustomThemeProfile>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) return const <CustomThemeProfile>[];
      return decoded
          .whereType<Map<Object?, Object?>>()
          .map(
            (Map<Object?, Object?> json) =>
                CustomThemeProfile.fromJson(json.cast<String, Object?>()),
          )
          .toList(growable: false);
    } catch (error) {
      AppLog.w(_tag, 'Perfiles de tema inválidos; se ignoran', error);
      return const <CustomThemeProfile>[];
    }
  }

  /// Aplica uno de los tres temas base con un solo toque.
  Future<void> applyPreset(AppThemePreset preset) {
    return _persist(AppThemeConfig.fromPreset(preset));
  }

  Future<void> resetToDefaults() => _persist(AppThemeConfig.defaults);

  Future<void> setCardStyle(CardStyle style) =>
      _persist(_touch(config.copyWith(cardStyle: style)));

  Future<void> setArtworkShape(ArtworkShape shape) =>
      _persist(_touch(config.copyWith(artworkShape: shape)));

  Future<void> setProgressBarType(ProgressBarType type) =>
      _persist(_touch(config.copyWith(progressBarType: type)));

  Future<void> setPaletteMode(ColorPaletteMode mode) =>
      _persist(_touch(config.copyWith(paletteMode: mode)));

  /// Cambia cualquier objetivo cromático desde el editor RGB/HSV/HEX.
  ///
  /// Tono, saturación, brillo y opacidad se resuelven en el widget; aquí solo
  /// se recibe el [Color] final y se persiste una vez.
  Future<void> setColor(ThemeColorTarget target, Color color) =>
      _persist(_touch(config.withColor(target, color)));

  Future<void> setGlassBlur(double value) => _persist(
    _touch(config.copyWith(glassBlur: value.isNaN ? 0 : value.clamp(0, 32))),
  );

  Future<void> setGlassOpacity(double value) => _persist(
    _touch(config.copyWith(glassOpacity: value.isNaN ? 0 : value.clamp(0, 1))),
  );

  Future<void> setAccent(Color color) {
    final AppThemeConfig current = config;
    // Los colores derivados acompañan al acento mientras el usuario no los
    // haya editado por separado: así el preset sigue coherente al cambiar el
    // acento rápido desde Ajustes.
    final bool progressLinked = current.progressColor == current.accent;
    final bool volumeLinked = current.volumeColor == current.accent;
    final bool karaokeLinked = current.karaokeColor == current.accent;
    return _persist(
      _touch(
        current.copyWith(
          accent: color,
          progressColor: progressLinked ? color : null,
          volumeColor: volumeLinked ? color : null,
          karaokeColor: karaokeLinked ? color : null,
        ),
      ),
    );
  }

  /// Guarda la configuración actual como perfil con nombre.
  Future<CustomThemeProfile> saveProfile(String name) async {
    final String clean = name.trim();
    final String id = DateTime.now().microsecondsSinceEpoch.toString();
    final CustomThemeProfile profile = CustomThemeProfile(
      id: id,
      name: clean.isEmpty ? 'Mi tema' : clean,
      config: config,
    );
    final List<CustomThemeProfile> next = <CustomThemeProfile>[
      ...state.profiles.where((CustomThemeProfile p) => p.name != profile.name),
      profile,
    ];
    state = state.copyWith(profiles: next);
    await _persistProfiles(next);
    return profile;
  }

  Future<void> applyProfile(CustomThemeProfile profile) =>
      _persist(profile.config.copyWith(preset: AppThemePreset.custom));

  Future<void> deleteProfile(String id) async {
    final List<CustomThemeProfile> next = state.profiles
        .where((CustomThemeProfile p) => p.id != id)
        .toList(growable: false);
    state = state.copyWith(profiles: next);
    await _persistProfiles(next);
  }

  /// Serializa el diseño activo y los perfiles para exportarlos a `.json`.
  String exportJson() {
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'app': AppConstants.appName,
      'kind': 'polaris-theme',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'config': config.toJson(),
      'profiles': state.profiles
          .map((CustomThemeProfile profile) => profile.toJson())
          .toList(),
    });
  }

  /// Importa un archivo exportado por esta misma pantalla.
  ///
  /// Devuelve cuántos perfiles se añadieron o actualizaron.
  Future<int> importJson(String raw) async {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('El archivo no contiene un objeto JSON.');
    }
    final Map<String, Object?> json = decoded.cast<String, Object?>();
    final Object? configRaw = json['config'];
    if (configRaw is! Map<Object?, Object?>) {
      throw const FormatException('Falta la configuración del tema.');
    }

    final AppThemeConfig imported = AppThemeConfig.fromJson(
      configRaw.cast<String, Object?>(),
    );
    final List<CustomThemeProfile> importedProfiles =
        (json['profiles'] as List<Object?>?)
            ?.whereType<Map<Object?, Object?>>()
            .map(
              (Map<Object?, Object?> item) =>
                  CustomThemeProfile.fromJson(item.cast<String, Object?>()),
            )
            .toList(growable: false) ??
        const <CustomThemeProfile>[];

    final Map<String, CustomThemeProfile> merged = <String, CustomThemeProfile>{
      for (final CustomThemeProfile profile in state.profiles)
        profile.id: profile,
      for (final CustomThemeProfile profile in importedProfiles)
        profile.id: profile,
    };
    final List<CustomThemeProfile> next = merged.values.toList(growable: false);

    state = state.copyWith(profiles: next);
    await _persistProfiles(next);
    await _persist(imported);
    return importedProfiles.length;
  }

  Future<void> _persist(AppThemeConfig next) async {
    state = state.copyWith(config: next);
    await _settings.setString(
      AppConstants.keyThemeConfig,
      jsonEncode(next.toJson()),
    );
    // Se mantiene la clave antigua para que otras pantallas/backups sigan
    // leyendo el acento sin migraciones adicionales.
    await _settings.setString(AppConstants.keyAccentColor, _hex(next.accent));
  }

  Future<void> _persistProfiles(List<CustomThemeProfile> profiles) {
    return _settings.setString(
      AppConstants.keyThemeProfiles,
      jsonEncode(
        profiles.map((CustomThemeProfile profile) => profile.toJson()).toList(),
      ),
    );
  }

  /// Marca la configuración como personalizada si ya no coincide con un preset.
  AppThemeConfig _touch(AppThemeConfig next) {
    for (final AppThemeConfig base in AppThemeConfig.builtInPresets) {
      if (base == next) return next;
    }
    return next.copyWith(preset: AppThemePreset.custom);
  }

  static String _hex(Color color) =>
      '0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

final StateNotifierProvider<ThemeController, ThemeState>
themeControllerProvider = StateNotifierProvider<ThemeController, ThemeState>((
  Ref ref,
) {
  return ThemeController(sl<SettingsService>());
});

/// Atajo para widgets que solo necesitan la configuración activa.
final Provider<AppThemeConfig> themeConfigProvider = Provider<AppThemeConfig>((
  Ref ref,
) {
  return ref.watch(themeControllerProvider).config;
});

/// Acento real del reproductor: paleta de la carátula o color fijo.
final FutureProviderFamily<Color, String?> artworkAccentProvider =
    FutureProvider.family<Color, String?>((Ref ref, String? path) {
      return PaletteExtractor.fromFile(path);
    });
