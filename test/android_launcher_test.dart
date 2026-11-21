import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El icono de Flutter por defecto pesa menos de 1 KB por densidad. Los
/// recursos de Polaris se generaron desde `assets/icons/polaris_music_logo.png`
/// y son varias veces más grandes; este test evita que un `flutter create`
/// accidental los revierta sin que se note en el código Dart.
void main() {
  test('el launcher de Android apunta a los mipmap de Polaris', () {
    const String res = 'android/app/src/main/res';
    final File manifest = File('android/app/src/main/AndroidManifest.xml');
    expect(manifest.existsSync(), isTrue);
    final String source = manifest.readAsStringSync();
    expect(source, contains('android:label="Polaris Music"'));
    expect(source, contains('android:icon="@mipmap/ic_launcher"'));
    expect(source, contains('android:roundIcon="@mipmap/ic_launcher_round"'));

    for (final String density in <String>[
      'mdpi',
      'hdpi',
      'xhdpi',
      'xxhdpi',
      'xxxhdpi',
    ]) {
      for (final String name in <String>[
        'ic_launcher.png',
        'ic_launcher_round.png',
        'ic_launcher_foreground.png',
      ]) {
        final File icon = File('$res/mipmap-$density/$name');
        expect(icon.existsSync(), isTrue, reason: '$density/$name falta');
        expect(
          icon.lengthSync(),
          greaterThan(1500),
          reason: '$density/$name parece el icono por defecto de Flutter',
        );
      }
    }

    for (final String name in <String>[
      'ic_launcher.xml',
      'ic_launcher_round.xml',
    ]) {
      final File adaptive = File('$res/mipmap-anydpi-v26/$name');
      expect(adaptive.existsSync(), isTrue);
      expect(
        adaptive.readAsStringSync(),
        contains('@mipmap/ic_launcher_foreground'),
      );
    }
  });
}
