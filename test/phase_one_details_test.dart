import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/constants/app_constants.dart';
import 'package:polaris_music/core/services/settings_service.dart';

import 'support/fake_settings_service.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Búsquedas recientes', () {
    test('guarda sin duplicados y respeta el orden', () async {
      final SettingsService settings = FakeSettingsService();

      await settings.rememberSearch('  Chopin  ');
      await settings.rememberSearch('Debussy');
      await settings.rememberSearch('chopin');

      expect(settings.recentSearches, <String>['chopin', 'Debussy']);
    });

    test('descarta términos vacíos y conserva como máximo ocho', () async {
      final SettingsService settings = FakeSettingsService();

      await settings.rememberSearch('   ');
      for (int i = 0; i < 12; i++) {
        await settings.rememberSearch('término $i');
      }

      expect(settings.recentSearches, hasLength(8));
      expect(settings.recentSearches.first, 'término 11');
    });

    test('tolera un valor corrupto en la base de datos', () async {
      final SettingsService settings = FakeSettingsService();
      await settings.setString(AppConstants.keyRecentSearches, '{no es json');

      expect(settings.recentSearches, isEmpty);
    });

    test('limpiar deja la lista vacía', () async {
      final SettingsService settings = FakeSettingsService();
      await settings.rememberSearch('Bach');

      await settings.clearRecentSearches();

      expect(settings.recentSearches, isEmpty);
    });
  });

  group('Preferencias del temporizador', () {
    test('usa valores por defecto razonables', () {
      final SettingsService settings = FakeSettingsService();

      expect(settings.sleepTimerDefaultMinutes, 30);
      expect(settings.sleepFadeSeconds, 5);
    });

    test('lee la última elección del usuario', () async {
      final SettingsService settings = FakeSettingsService();
      await settings.setInt(AppConstants.keySleepTimerDefault, 90);
      await settings.setInt(AppConstants.keySleepFadeSeconds, 12);

      expect(settings.sleepTimerDefaultMinutes, 90);
      expect(settings.sleepFadeSeconds, 12);
    });

    test('acota valores fuera de rango', () async {
      final SettingsService settings = FakeSettingsService();
      await settings.setInt(AppConstants.keySleepTimerDefault, 9999);
      await settings.setInt(AppConstants.keySleepFadeSeconds, 0);

      expect(settings.sleepTimerDefaultMinutes, 480);
      expect(settings.sleepFadeSeconds, 1);
    });
  });
}
