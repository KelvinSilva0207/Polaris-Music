import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/constants/app_constants.dart';

import 'support/fake_settings_service.dart';

void main() {
  group('Restablecer ajustes por defecto', () {
    test('limpia preferencias de configuración', () async {
      final FakeSettingsService settings = FakeSettingsService();
      for (final String key in AppConstants.resettablePreferenceKeys) {
        await settings.setString(key, 'modificado');
      }

      await settings.resetPreferences();

      for (final String key in AppConstants.resettablePreferenceKeys) {
        expect(settings.getString(key), isNull, reason: key);
      }
    });

    test(
      'conserva intro, sesión, credenciales, fuentes y perfiles de tema',
      () async {
        final FakeSettingsService settings = FakeSettingsService();
        const List<String> protectedKeys = <String>[
          AppConstants.keyOnboardingDone,
          AppConstants.keyPlaybackSession,
          AppConstants.keyLastTrackId,
          AppConstants.keyScrobbleConfig,
          AppConstants.keyImportedFonts,
          AppConstants.keyThemeProfiles,
          'online.spotify.oauth_token',
        ];
        for (final String key in protectedKeys) {
          await settings.setString(key, 'conservar');
        }

        await settings.resetPreferences();

        for (final String key in protectedKeys) {
          expect(settings.getString(key), 'conservar', reason: key);
        }
      },
    );

    test('la lista de restauración incluye temas, animación y rutas', () {
      expect(
        AppConstants.resettablePreferenceKeys,
        containsAll(<String>[
          AppConstants.keyThemeConfig,
          AppConstants.keyMotionConfig,
          AppConstants.keyTypography,
          AppConstants.keyCompactMiniStyle,
          AppConstants.keyDocumentsFolder,
          AppConstants.keyMusicFolder,
          AppConstants.keyDownloadsFolder,
        ]),
      );
    });
  });
}
