import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/theme/compact_style_config.dart';
import 'package:polaris_music/core/theme/font_catalog.dart';
import 'package:polaris_music/core/theme/theme_tokens.dart';
import 'package:polaris_music/core/theme/typography_config.dart';

void main() {
  group('Tipografía de Polaris', () {
    test(
      'la configuración por defecto tiene familia, escala y pesos propios',
      () {
        const TypographyConfig config = TypographyConfig.defaults;
        expect(config.familyId, fontIdPolarisSans);
        expect(config.scale, 1);
        expect(config.headline, FontWeight.w700);
        expect(config.metadata, FontWeight.w500);
        expect(config.lyrics, FontWeight.w600);
      },
    );

    test('serialización conserva fuente, escala y pesos', () {
      const TypographyConfig config = TypographyConfig(
        familyId: fontIdPolarisDisplay,
        scale: 1.15,
        headlineWeight: 800,
        metadataWeight: 400,
        lyricsWeight: 700,
      );
      final TypographyConfig restored = TypographyConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, Object?>,
      );
      expect(restored, config);
    });

    test('valores corruptos o fuera de rango caen en límites seguros', () {
      final TypographyConfig config = TypographyConfig.fromJson(
        <String, Object?>{
          'familyId': 42,
          'scale': 9,
          'headlineWeight': -100,
          'metadataWeight': 'x',
          'lyricsWeight': 2000,
        },
      );
      expect(config.familyId, fontIdPolarisSans);
      expect(config.scale, 1.4);
      expect(config.headlineWeight, 100);
      expect(config.metadataWeight, TypographyConfig.defaults.metadataWeight);
      expect(config.lyricsWeight, 900);
    });
  });

  group('Fuentes importadas', () {
    test('el registro sobrevive al viaje JSON', () {
      const ImportedFont font = ImportedFont(
        id: 'font_1',
        name: 'Mi Fuente',
        fileName: 'font_1.ttf',
        family: 'PolarisUser_font_1',
      );
      final List<ImportedFont> restored = ImportedFont.decode(
        ImportedFont.encode(<ImportedFont>[font]),
      );
      expect(restored, <ImportedFont>[font]);
      expect(resolveFontFamily(font.configId, restored), font.family);
    });

    test('el sistema y una fuente desconocida tienen respuestas distintas', () {
      expect(resolveFontFamily(fontIdSystem), isNull);
      expect(resolveFontFamily('no-existe'), 'Polaris Sans');
    });

    test('el registro interno permite resolver fuentes del usuario', () {
      registerCustomFontFamily('font_2', 'PolarisUser_font_2');
      addTearDown(() => unregisterCustomFontFamily('font_2'));
      expect(
        resolveFontFamily('$fontIdCustomPrefix font_2'.replaceAll(' ', '')),
        'PolarisUser_font_2',
      );
    });
  });

  group('Tipografía por superficie compacta', () {
    test('hereda global y permite anular familia y escala', () {
      final PolarisTokens tokens = PolarisTokens.fallback.copyWith(
        typography: const TypographyConfig(
          familyId: fontIdPolarisDisplay,
          scale: 1.1,
        ),
      );
      final CompactStyleConfig inherited = CompactStyleConfig.mini;
      final ResolvedCompactStyle inheritedResolved = inherited.resolve(tokens);
      expect(inheritedResolved.fontFamily, 'Polaris Display');
      expect(inheritedResolved.typography.scale, 1.1);

      registerCustomFontFamily('font_3', 'PolarisUser_font_3');
      addTearDown(() => unregisterCustomFontFamily('font_3'));
      final CompactStyleConfig custom = inherited.copyWith(
        fontFamilyId: '${fontIdCustomPrefix}font_3',
        fontScale: 1.25,
      );
      final ResolvedCompactStyle customResolved = custom.resolve(tokens);
      expect(customResolved.fontFamily, 'PolarisUser_font_3');
      expect(customResolved.typography.scale, 1.25);
    });

    test('el JSON conserva la anulación tipográfica', () {
      const CompactStyleConfig style = CompactStyleConfig(
        fontFamilyId: fontIdSystem,
        fontScale: 0.9,
      );
      final CompactStyleConfig restored = CompactStyleConfig.fromJson(
        jsonDecode(jsonEncode(style.toJson())) as Map<String, Object?>,
      );
      expect(restored.fontFamilyId, fontIdSystem);
      expect(restored.fontScale, 0.9);
      expect(restored.resolve(PolarisTokens.fallback).fontFamily, isNull);
    });

    test('el borde de la franja de la isla sobrevive al JSON', () {
      final CompactStyleConfig style = CompactStyleConfig.island.copyWith(
        islandPeekEdge: IslandPeekEdge.left,
      );
      final CompactStyleConfig restored = CompactStyleConfig.fromJson(
        jsonDecode(jsonEncode(style.toJson())) as Map<String, Object?>,
        surface: CompactSurface.island,
      );
      expect(restored.islandPeekEdge, IslandPeekEdge.left);

      final CompactStyleConfig backwards = CompactStyleConfig.fromJson(
        <String, Object?>{'autoHide': true},
        surface: CompactSurface.island,
      );
      expect(backwards.islandPeekEdge, IslandPeekEdge.top);
    });

    test(
      'colores de barra y forma de carátula por superficie sobreviven al JSON',
      () {
        final CompactStyleConfig style = CompactStyleConfig.mini.copyWith(
          progressColor: const Color(0xFF00E5FF),
          volumeColor: const Color(0xFFFF5252),
          artworkShape: ArtworkShape.squareRounded,
        );
        final CompactStyleConfig restored = CompactStyleConfig.fromJson(
          jsonDecode(jsonEncode(style.toJson())) as Map<String, Object?>,
          surface: CompactSurface.mini,
        );
        expect(restored.progressColor, const Color(0xFF00E5FF));
        expect(restored.volumeColor, const Color(0xFFFF5252));
        expect(restored.artworkShape, ArtworkShape.squareRounded);

        final ResolvedCompactStyle resolved = restored.resolve(
          PolarisTokens.fallback,
        );
        expect(resolved.progressColor, const Color(0xFF00E5FF));
        expect(resolved.volumeColor, const Color(0xFFFF5252));
        expect(resolved.artworkRadius(40), 40);
        expect(
          restored.copyWith(artworkShape: null).artworkShape,
          isNull,
          reason: 'null anula la forma para heredar la global',
        );
      },
    );

    test('superficie sin anulación hereda la forma global', () {
      const CompactStyleConfig style = CompactStyleConfig();
      expect(style.artworkShape, isNull);
      final ResolvedCompactStyle resolved = style.resolve(
        PolarisTokens.fallback.copyWith(artworkShape: ArtworkShape.circleVinyl),
      );
      expect(resolved.isVinyl, isTrue);
      expect(resolved.artworkRadius(40), greaterThan(1000));
    });
  });
}
