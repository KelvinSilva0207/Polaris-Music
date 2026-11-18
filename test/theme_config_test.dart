import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/theme/app_theme_config.dart';
import 'package:polaris_music/core/theme/color_math.dart';
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
        ArtworkShape.squareRounded,
      );
      expect(
        AppThemeConfig.polarisVioletGlass.progressBarType,
        ProgressBarType.linearClassic,
      );
      expect(AppThemeConfig.polarisVioletGlass.artworkRadius, 32);
      expect(AppThemeConfig.polarisVioletGlass.glassBlur, 20);
      expect(
        AppThemeConfig.polarisVioletGlass.borderColor,
        const Color(0x1AFFFFFF),
      );

      expect(AppThemeConfig.monolithMinimal.cardStyle, CardStyle.flatMinimal);
      expect(
        AppThemeConfig.monolithMinimal.progressBarType,
        ProgressBarType.waveform,
      );
      expect(
        AppThemeConfig.monolithMinimal.background,
        const Color(0xFF121212),
      );
      expect(AppThemeConfig.monolithMinimal.artworkRadius, 16);
      expect(AppThemeConfig.monolithMinimal.accent, const Color(0xFF39FF14));

      expect(AppThemeConfig.bronzeVinyl.cardStyle, CardStyle.neumorphic);
      expect(
        AppThemeConfig.bronzeVinyl.progressBarType,
        ProgressBarType.circularAroundArtwork,
      );
      expect(AppThemeConfig.bronzeVinyl.background, const Color(0xFF1F1F1F));
      expect(
        AppThemeConfig.bronzeVinyl.neumorphicLight,
        const Color(0xFF2A2A2A),
      );
      expect(
        AppThemeConfig.bronzeVinyl.neumorphicDark,
        const Color(0xFF000000),
      );
      expect(AppThemeConfig.bronzeVinyl.accent, const Color(0xFFD4A76A));
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
      expect(flat.panelShadows(), hasLength(2));
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

    test('los nuevos colores y opacidades sobreviven al viaje JSON', () {
      final AppThemeConfig original = AppThemeConfig.polarisVioletGlass
          .copyWith(
            progressColor: const Color(0xFF00E5FF),
            volumeColor: const Color(0xFFFF5252),
            karaokeColor: const Color(0xFFFFD740),
            glassOpacity: 0.42,
            glassBlur: 12,
          );

      final AppThemeConfig restored = AppThemeConfig.fromJson(
        original.toJson(),
      );

      expect(restored, original);
      expect(restored.progressColor, const Color(0xFF00E5FF));
      expect(restored.volumeColor, const Color(0xFFFF5252));
      expect(restored.karaokeColor, const Color(0xFFFFD740));
      expect(restored.glassOpacity, 0.42);
      expect(
        restored.colorFor(ThemeColorTarget.progress),
        restored.progressColor,
      );
    });

    test('JSON con valores fuera de rango se normaliza', () {
      final AppThemeConfig restored = AppThemeConfig.fromJson(<String, Object?>{
        'preset': 'polarisVioletGlass',
        'glassOpacity': -3,
        'glassBlur': 999,
      });

      expect(restored.glassOpacity, 0.0);
      expect(restored.glassBlur, 32.0);
    });
  });

  group('Motor RGB / HSV / HEX', () {
    test('HSV hace round-trip con RGB', () {
      for (final Color color in <Color>[
        const Color(0xFFFF0000),
        const Color(0xFF00FF00),
        const Color(0xFF0000FF),
        const Color(0xFFFFFFFF),
        const Color(0xFF000000),
        const Color(0xFF8B5CF6),
      ]) {
        expect(
          HsvColor.fromColor(color).toColor().toARGB32(),
          color.toARGB32(),
        );
      }
    });

    test('los deslizadores HSV son independientes', () {
      final HsvColor original = HsvColor.fromColor(const Color(0xFF8B5CF6));
      final HsvColor cambiado = original.copyWith(s: 0.0);
      final Color gris = cambiado.toColor();

      expect(gris.r, gris.g);
      expect(gris.g, gris.b);
      expect(cambiado.h, original.h);
    });

    test('HEX acepta 3, 6 y 8 dígitos y siempre se formatea igual', () {
      expect(ColorMath.tryParseHex('#fff'), const Color(0xFFFFFFFF));
      expect(ColorMath.tryParseHex('#8B5CF6'), const Color(0xFF8B5CF6));
      expect(ColorMath.tryParseHex('#FF8B5CF6'), const Color(0xFF8B5CF6));
      expect(ColorMath.tryParseHex('zzz'), isNull);
      expect(
        ColorMath.toHex(const Color(0xFF8B5CF6), withAlpha: true),
        '#FF8B5CF6',
      );
    });

    test('onColor elige texto legible sobre el fondo', () {
      expect(
        ColorMath.onColor(const Color(0xFFFFFFFF)),
        const Color(0xFF0B0B12),
      );
      expect(
        ColorMath.onColor(const Color(0xFF000000)),
        const Color(0xFFFFFFFF),
      );
    });
  });

  group('Objetivos de color editables', () {
    test('withColor expande el degradado hasta la parada solicitada', () {
      final AppThemeConfig base = AppThemeConfig.polarisVioletGlass;
      expect(base.backdrop.length, 2);

      final AppThemeConfig editado = base.withColor(
        ThemeColorTarget.backdropEnd,
        const Color(0xFF123456),
      );

      expect(editado.backdrop.length, 3);
      expect(editado.backdrop.last, const Color(0xFF123456));
      expect(editado.backdrop.first, base.backdrop.first);
    });

    test('cada objetivo lee su color propio', () {
      final AppThemeConfig config = AppThemeConfig.monolithMinimal.copyWith(
        progressColor: const Color(0xFF112233),
        volumeColor: const Color(0xFF445566),
        karaokeColor: const Color(0xFF778899),
      );

      expect(config.colorFor(ThemeColorTarget.background), config.background);
      expect(config.colorFor(ThemeColorTarget.progress), config.progressColor);
      expect(config.colorFor(ThemeColorTarget.volume), config.volumeColor);
      expect(config.colorFor(ThemeColorTarget.karaoke), config.karaokeColor);
      expect(
        config.colorFor(ThemeColorTarget.backdropMiddle),
        config.backdrop[1],
      );
    });
  });
}
