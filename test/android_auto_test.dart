import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Android Auto exige el descriptor `automotive_app_desc` y un servicio
/// `MediaBrowserService` exportado. El árbol de navegación vive en Dart, pero
/// estos recursos nativos son fáciles de perder en un regenerado del proyecto.
void main() {
  const String manifestPath = 'android/app/src/main/AndroidManifest.xml';
  const String descriptorPath =
      'android/app/src/main/res/xml/automotive_app_desc.xml';

  test('la app se anuncia como fuente multimedia de Android Auto', () {
    final File manifest = File(manifestPath);
    expect(manifest.existsSync(), isTrue);
    final String source = manifest.readAsStringSync();
    expect(source, contains('com.google.android.gms.car.application'));
    expect(source, contains('@xml/automotive_app_desc'));

    final File descriptor = File(descriptorPath);
    expect(descriptor.existsSync(), isTrue);
    expect(descriptor.readAsStringSync(), contains('<uses name="media"'));
  });

  test('el servicio multimedia sigue expuesto para MediaBrowser', () {
    final String source = File(manifestPath).readAsStringSync();
    expect(
      source,
      contains('android:name="com.ryanheise.audioservice.AudioService"'),
    );
    expect(source, contains('android.media.browse.MediaBrowserService'));
    expect(source, contains('android:exported="true"'));
  });
}
