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
  });
}
