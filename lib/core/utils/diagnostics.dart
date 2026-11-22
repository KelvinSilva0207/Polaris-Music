import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import '../services/app_updater_service.dart';

/// Texto corto que el usuario puede pegar cuando reporta un problema.
///
/// Solo incluye datos visibles para el propio usuario: versión, plataforma,
/// permiso de instalación y huella de la firma. No contiene rutas de archivos
/// musicales ni información de la biblioteca.
Future<String> buildDiagnosticsReport(AppUpdaterService updater) async {
  final PackageInfo info = await PackageInfo.fromPlatform();
  final StringBuffer report = StringBuffer()
    ..writeln('Polaris Music — diagnóstico')
    ..writeln('Versión: ${info.version}+${info.buildNumber}')
    ..writeln('Plataforma: ${Platform.operatingSystem}');

  if (Platform.isAndroid) {
    final bool canInstall = await updater.canInstallApk();
    final String? fingerprint = await updater.installedSignatureFingerprint();
    report
      ..writeln(
        'Permiso de instalación: ${canInstall ? 'concedido' : 'pendiente'}',
      )
      ..writeln('Huella SHA256: ${fingerprint ?? 'no disponible'}');
  }

  return report.toString().trimRight();
}
