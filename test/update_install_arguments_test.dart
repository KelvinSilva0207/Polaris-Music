import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/services/app_updater_service.dart';
import 'package:polaris_music/core/services/update_service.dart';

void main() {
  group('Argumentos del instalador de Windows', () {
    test('la actualización silenciosa cierra la app y la relanza', () {
      final List<String> args = UpdateService.installerArguments(
        allUsers: false,
      );

      expect(args, contains('/SILENT'));
      expect(args, contains('/SUPPRESSMSGBOXES'));
      expect(args, contains('/CLOSEAPPLICATIONS'));
      expect(args, contains('/FORCECLOSEAPPLICATIONS'));
      expect(args, contains('/RESTARTAPPLICATIONS'));
      expect(args, contains('/AUTOUPDATE'));
      expect(args, contains('/CURRENTUSER'));
      expect(args, isNot(contains('/ALLUSERS')));
    });

    test('respeta una instalación previa para todos los usuarios', () {
      final List<String> args = UpdateService.installerArguments(
        allUsers: true,
      );

      expect(args, contains('/ALLUSERS'));
      expect(args, isNot(contains('/CURRENTUSER')));
    });
  });

  test('installApk no intenta instalar fuera de Android', () async {
    final AppUpdaterService updater = AppUpdaterService();

    expect(await updater.installApk('no-existe.apk'), ApkInstallResult.failed);
  });

  group('Desenlace del instalador del sistema', () {
    test('interpreta éxito, cancelación y error', () {
      expect(
        ApkInstallOutcome.fromMap(<String, Object?>{'status': 'installed'}),
        ApkInstallOutcome.installed,
      );
      expect(
        ApkInstallOutcome.fromMap(<String, Object?>{'status': 'cancelled'}),
        ApkInstallOutcome.cancelled,
      );
      expect(
        ApkInstallOutcome.fromMap(<String, Object?>{'status': 'failed'}),
        ApkInstallOutcome.failed,
      );
    });

    test('ignora respuestas vacías o desconocidas', () {
      expect(ApkInstallOutcome.fromMap(null), isNull);
      expect(
        ApkInstallOutcome.fromMap(<String, Object?>{'status': 'otro'}),
        isNull,
      );
    });
  });

  group('Inspección del APK antes de instalar', () {
    test('lee paquete, firma y versiones del canal nativo', () {
      final ApkInspection inspection = ApkInspection.fromMap(<String, Object?>{
        'samePackage': true,
        'signatureMatches': true,
        'versionCode': 10009010,
        'installedVersionCode': 10008009,
      });

      expect(inspection.samePackage, isTrue);
      expect(inspection.signatureMatches, isTrue);
      expect(inspection.versionCode, 10009010);
      expect(inspection.installedVersionCode, 10008009);
    });

    test('valores ausentes caen en falsos y cero', () {
      final ApkInspection inspection = ApkInspection.fromMap(
        <String, Object?>{},
      );

      expect(inspection.samePackage, isFalse);
      expect(inspection.signatureMatches, isFalse);
      expect(inspection.versionCode, 0);
      expect(inspection.installedVersionCode, 0);
    });
  });
}
