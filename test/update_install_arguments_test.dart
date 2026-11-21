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
}
