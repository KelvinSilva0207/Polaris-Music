import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/theme/app_theme_config.dart';
import 'package:polaris_music/core/theme/theme_tokens.dart';

void main() {
  group('AppThemeConfig presets', () {
    test('los tres temas base tienen la combinación esperada', () {
      expect(
        AppThemeConfig.polarisVioletGlass.cardStyle,
        CardStyle.glassmorphic,
      );
      expect(
        AppThemeConfig.polarisVioletGlass.artworkShape,
        ArtworkShape.circleVinyl,
      );
      expect(
        AppThemeConfig.polarisVioletGlass.progressBarType,
        ProgressBarType.linearClassic,
      );

      expect(AppThemeConfig.monolithMinimal.cardStyle, CardStyle.flatMinimal);
      expect(
        AppThemeConfig.monolithMinimal.progressBarType,
        ProgressBarType.waveform,
      );

      expect(AppThemeConfig.bronzeVinyl.cardStyle, CardStyle.neumorphic);
      expect(
        AppThemeConfig.bronzeVinyl.progressBarType,
        ProgressBarType.circularAroundArtwork,
      );
      expect(AppThemeConfig.builtInPresets.length, 3);
    });

    test('fromPreset devuelve cada preset y usa el base para custom', () {
      expect(
        AppThemeConfig.fromPreset(AppThemePreset.monolithMinimal),
        AppThemeConfig.monolithMinimal,
      );
      expect(
        AppThemeConfig.fromPreset(AppThemePreset.custom),
        AppThemeConfig.defaults,
      );
    });
  });

  group('Tokens de panel', () {
    const Color surface = Color(0xFF171126);

    test('cada cardStyle define su propia superficie de panel', () {
      const PolarisTokens glass = PolarisTokens(
        accent: Color(0xFF8B5CF6),
        cardStyle: CardStyle.glassmorphic,
        surface: surface,
      );
      const PolarisTokens neumorphic = PolarisTokens(
        accent: Color(0xFF8B5CF6),
        cardStyle: CardStyle.neumorphic,
        surface: surface,
      );
      const PolarisTokens flat = PolarisTokens(
        accent: Color(0xFF8B5CF6),
        cardStyle: CardStyle.flatMinimal,
        surface: surface,
      );

      expect(glass.panelColor, isNot(surface));
      expect(neumorphic.panelColor, surface);
      expect(flat.panelColor, surface.withValues(alpha: 0.94));
    });

    test('las sombras siguen el estilo de tarjeta', () {
      const PolarisTokens glass = PolarisTokens(
        accent: Color(0xFF8B5CF6),
        cardStyle: CardStyle.glassmorphic,
      );
      const PolarisTokens neumorphic = PolarisTokens(
        accent: Color(0xFF8B5CF6),
        cardStyle: CardStyle.neumorphic,
      );
      const PolarisTokens flat = PolarisTokens(
        accent: Color(0xFF8B5CF6),
        cardStyle: CardStyle.flatMinimal,
      );

      expect(glass.panelShadows(), hasLength(1));
      expect(glass.panelShadows(glow: glass.accent), hasLength(2));
      expect(neumorphic.panelShadows(), hasLength(2));
      expect(flat.panelShadows(), isEmpty);
    });

    test('panelDecoration respeta radio y borde del estilo', () {
      const PolarisTokens tokens = PolarisTokens(
        accent: Color(0xFF8B5CF6),
        cardStyle: CardStyle.glassmorphic,
      );

      final BoxDecoration decoration = tokens.panelDecoration(radius: 12);

      expect(decoration.color, tokens.panelColor);
      expect(decoration.border, isNotNull);
      expect(decoration.borderRadius, BorderRadius.circular(12));
    });
  });

  group('Serialización', () {
    test('toJson/fromJson conserva todos los parámetros', () {
      final AppThemeConfig original = AppThemeConfig.bronzeVinyl.copyWith(
        paletteMode: ColorPaletteMode.dynamicArtwork,
        accent: const Color(0xFF123456),
      );

      final AppThemeConfig restored = AppThemeConfig.fromJson(
        original.toJson(),
      );

      expect(restored, original);
      expect(restored.preset, AppThemePreset.bronzeVinyl);
      expect(restored.paletteMode, ColorPaletteMode.dynamicArtwork);
      expect(restored.accent, const Color(0xFF123456));
    });

    test('un JSON incompleto cae en valores seguros', () {
      final AppThemeConfig restored = AppThemeConfig.fromJson(<String, Object?>{
        'preset': 'monolithMinimal',
      });

      expect(restored.preset, AppThemePreset.monolithMinimal);
      expect(restored.cardStyle, CardStyle.flatMinimal);
      expect(restored.backdrop.length, greaterThanOrEqualTo(2));
    });

    test('un preset desconocido se lee como personalizado', () {
      final AppThemeConfig restored = AppThemeConfig.fromJson(<String, Object?>{
        'preset': 'no-existe',
      });

      expect(restored.preset, AppThemePreset.custom);
      expect(restored.cardStyle, AppThemeConfig.defaults.cardStyle);
    });

    test('CustomThemeProfile sobrevive al viaje JSON', () {
      const CustomThemeProfile profile = CustomThemeProfile(
        id: 'perfil-1',
        name: 'Nocturno',
        config: AppThemeConfig.monolithMinimal,
      );

      final CustomThemeProfile restored = CustomThemeProfile.fromJson(
        profile.toJson(),
      );

      expect(restored.id, profile.id);
      expect(restored.name, profile.name);
      expect(restored.config, profile.config);
    });
  });
}
