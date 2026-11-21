import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../models/update_info.dart';
import '../utils/logger.dart';
import 'update_service.dart';

/// Resultado de abrir el instalador de Android.
enum ApkInstallResult {
  /// El instalador del sistema se abrió correctamente.
  started,

  /// Falta conceder "instalar aplicaciones desconocidas".
  permissionRequired,

  /// El APK no es válido o el sistema rechazó el intent.
  failed,
}

/// Fachada de actualización usada por la app.
///
/// Hereda la lógica de GitHub Releases de [UpdateService] y añade la instalación
/// de APK en Android mediante un intent nativo (que gestiona el permiso de
/// "instalar aplicaciones desconocidas" y un `FileProvider`).
class AppUpdaterService extends UpdateService {
  AppUpdaterService({super.dio});

  static const String _tag = 'AppUpdater';
  static const MethodChannel _channel = MethodChannel(
    'com.polaris.polaris_music/updater',
  );

  /// Verifica el tamaño del binario antes de darlo por bueno.
  @override
  Future<String?> download(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final String? path = await super.download(
      info,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    if (path == null) return null;

    try {
      final File file = File(path);
      final int size = file.existsSync() ? file.lengthSync() : 0;
      if (size <= 0) {
        AppLog.w(_tag, 'La descarga está vacía: $path');
        if (file.existsSync()) await file.delete();
        return null;
      }
      AppLog.i(_tag, 'Descarga verificada: $path ($size bytes)');
      return path;
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo verificar la descarga', error, stack);
      return null;
    }
  }

  /// Comprueba si Android permite instalar el APK descargado.
  ///
  /// En Android O+ depende de `REQUEST_INSTALL_PACKAGES`. Se consulta antes de
  /// abrir el instalador para no confundir un permiso ausente con un error de
  /// firma o de archivo corrupto.
  Future<bool> canInstallApk() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } catch (error, stack) {
      AppLog.w(
        _tag,
        'No se pudo consultar el permiso de instalación',
        error,
        stack,
      );
      return false;
    }
  }

  /// Instala un APK descargado en Android mediante `FileProvider`.
  ///
  /// El canal nativo copia el archivo a `cacheDir/updates`, comprueba el
  /// permiso de instalación y lanza el intent del instalador del sistema.
  Future<ApkInstallResult> installApk(String path) async {
    if (!Platform.isAndroid) return ApkInstallResult.failed;

    final File file = File(path);
    if (!file.existsSync() || file.lengthSync() <= 0) {
      AppLog.w(_tag, 'APK no válido antes de instalar: $path');
      return ApkInstallResult.failed;
    }

    try {
      if (!await canInstallApk()) {
        return ApkInstallResult.permissionRequired;
      }
      final bool? started = await _channel.invokeMethod<bool>(
        'installApk',
        <String, Object?>{'path': path},
      );
      return started == true
          ? ApkInstallResult.started
          : ApkInstallResult.failed;
    } on PlatformException catch (error) {
      if (error.code == 'PERMISSION_REQUIRED') {
        return ApkInstallResult.permissionRequired;
      }
      AppLog.w(
        _tag,
        'El instalador de Android rechazó el APK (${error.code}): '
        '${error.details ?? error.message}',
        error,
      );
      return ApkInstallResult.failed;
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo abrir el instalador de Android', error, stack);
      return ApkInstallResult.failed;
    }
  }

  /// Abre los ajustes de "instalar aplicaciones desconocidas".
  Future<bool> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool? opened = await _channel.invokeMethod<bool>(
        'openInstallSettings',
      );
      return opened ?? false;
    } catch (error, stack) {
      AppLog.w(
        _tag,
        'No se pudo abrir los ajustes de instalación',
        error,
        stack,
      );
      return false;
    }
  }
}
