import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// La app debe ser totalmente usable sin cuenta: ni dependencias de correo,
/// ni permisos de contactos/cuentas del sistema, ni inicio de sesión obligatorio.
void main() {
  test('no hay dependencias de correo ni de autenticación obligatoria', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final String lower = pubspec.toLowerCase();

    const List<String> forbiddenPackages = <String>[
      'google_sign_in',
      'firebase_auth',
      'firebase_core',
      'sign_in_with_apple',
      'mailer',
      'smtp',
      'imap',
      'flutter_mail',
      'gmail',
    ];
    for (final String package in forbiddenPackages) {
      expect(
        lower.contains(package),
        isFalse,
        reason: 'La app no debe depender de $package',
      );
    }
  });

  test('Android no pide permisos de correo, contactos ni cuentas', () {
    final String manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final String lower = manifest.toLowerCase();

    const List<String> forbiddenPermissions = <String>[
      'android.permission.read_contacts',
      'android.permission.get_accounts',
      'android.permission.read_email',
      'android.permission.read_sms',
      'android.permission.send_sms',
    ];
    for (final String permission in forbiddenPermissions) {
      expect(
        lower.contains(permission),
        isFalse,
        reason: 'Permiso innecesario: $permission',
      );
    }
  });

  test(
    'el inicio de sesión de Last.fm es opcional y no bloquea la reproducción',
    () {
      final String service = File('lib/core/services/scrobble_service.dart')
          .readAsStringSync();

      expect(service, contains('if (!current.ready) return;'));
      expect(service, contains('connectTimeout: connectTimeout'));
      expect(service, contains('receiveTimeout: receiveTimeout'));
      expect(service, contains('sendTimeout: sendTimeout'));
      expect(service, contains('Ya hay una autorización en curso'));
    },
  );
}
