import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../models/update_info.dart';
import '../utils/logger.dart';
import 'update_service.dart';

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

  /// Instala un APK descargado en Android.
  ///
  /// El canal nativo comprueba `canRequestPackageInstalls()`, abre los ajustes
  /// del sistema cuando falta el permiso y usa `FileProvider` para compartir el
  /// archivo con el instalador de Android. Devuelve `false` si el usuario debe
  /// conceder el permiso antes de reintentar.
  Future<bool> installApk(String path) async {
    if (!Platform.isAndroid) return false;
    try {
      final bool? started = await _channel.invokeMethod<bool>(
        'installApk',
        <String, Object?>{'path': path},
      );
      return started ?? false;
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo abrir el instalador de Android', error, stack);
      return false;
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
