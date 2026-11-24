import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El widget de inicio se reparte entre recursos XML, el provider nativo y el
/// puente Dart. Comprobar los cuatro evita que una actualización de Flutter o
/// una limpieza de `res/` deje el widget invisible sin avisar.
void main() {
  const String manifestPath = 'android/app/src/main/AndroidManifest.xml';
  const String providerPath =
      'android/app/src/main/kotlin/com/polaris/polaris_music/PolarisWidgetProvider.kt';
  const String layoutPath =
      'android/app/src/main/res/layout/widget_now_playing.xml';
  const String infoPath =
      'android/app/src/main/res/xml/polaris_widget_info.xml';
  const String bridgePath = 'lib/core/services/widget_bridge_service.dart';
  const String activityPath =
      'android/app/src/main/kotlin/com/polaris/polaris_music/MainActivity.kt';

  test('el widget está declarado en el manifest con sus acciones', () {
    final String manifest = File(manifestPath).readAsStringSync();
    expect(manifest, contains('.PolarisWidgetProvider'));
    expect(manifest, contains('@xml/polaris_widget_info'));
    expect(manifest, contains('com.polaris.polaris_music.widget.PLAY'));
    expect(manifest, contains('com.polaris.polaris_music.widget.NEXT'));
    expect(manifest, contains('com.polaris.polaris_music.widget.PREVIOUS'));
  });

  test('el provider, el layout y la configuración existen', () {
    expect(File(providerPath).existsSync(), isTrue);
    final String provider = File(providerPath).readAsStringSync();
    expect(provider, contains('RemoteViews'));
    expect(provider, contains('KEYCODE_MEDIA_PLAY_PAUSE'));

    final String layout = File(layoutPath).readAsStringSync();
    expect(layout, contains('@+id/widget_title'));
    expect(layout, contains('@+id/widget_artist'));
    expect(layout, contains('@+id/widget_play'));

    final String info = File(infoPath).readAsStringSync();
    expect(info, contains('@layout/widget_now_playing'));
  });

  test('el puente Dart publica la pista sin depender de permisos extra', () {
    final String bridge = File(bridgePath).readAsStringSync();
    expect(bridge, contains("com.polaris.polaris_music/widget"));
    expect(bridge, contains("'artwork'"));
    expect(bridge, contains('MissingPluginException'));
    expect(bridge, contains("'clear'"));
    expect(bridge, contains('buildWidgetPayload'));
  });

  test('el estado del widget tiene un único escritor en Kotlin', () {
    final String provider = File(providerPath).readAsStringSync();
    final String activity = File(activityPath).readAsStringSync();

    expect(provider, contains('fun publishState('));
    expect(provider, contains('clearState('));
    expect(activity, contains('PolarisWidgetProvider.publishState'));
    expect(activity, contains('PolarisWidgetProvider.clearState'));

    // El nombre de PREFS aparece una sola vez en todo el código Kotlin.
    final int prefsDeclarations =
        '$provider$activity'.split('polaris_widget_state').length - 1;
    expect(prefsDeclarations, 1);
    // MainActivity solo traduce el MethodChannel: no toca SharedPreferences.
    expect(activity, isNot(contains('getSharedPreferences')));
    expect(activity, isNot(contains('putString')));
    expect(activity, isNot(contains('putBoolean')));
  });

  test(
    'el provider limpia la carátula, la reduce y arregla los media keys',
    () {
      final String provider = File(providerPath).readAsStringSync();
      expect(provider, contains('.putString(KEY_ARTWORK, artPath)'));
      expect(provider, contains('R.id.widget_art, R.mipmap.ic_launcher'));
      expect(provider, contains('inJustDecodeBounds'));
      expect(provider, contains('inSampleSize'));
      expect(provider, contains('Bitmap.createScaledBitmap'));
      // AndroidX MediaButtonReceiver ignora intents sin esta acción.
      expect(provider, contains('Intent.ACTION_MEDIA_BUTTON'));
      expect(provider, contains('KeyEvent.ACTION_DOWN'));
    },
  );

  test('la configuración del widget respeta tamaño y periodicidad', () {
    final String info = File(infoPath).readAsStringSync();
    expect(info, contains('android:updatePeriodMillis="1800000"'));

    final RegExp minHeight = RegExp(r'android:minHeight="(\d+)dp"');
    final Match? match = minHeight.firstMatch(info);
    expect(match, isNotNull, reason: 'falta android:minHeight');
    // La carátula del layout mide 44dp; el widget no puede ser más bajo.
    expect(int.parse(match!.group(1)!), greaterThanOrEqualTo(44));
  });
}
