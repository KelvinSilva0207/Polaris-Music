import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

import '../utils/logger.dart';

/// Resultado de pedir acceso a la biblioteca musical.
class LibraryPermissionResult {
  const LibraryPermissionResult({
    required this.granted,
    required this.permanentlyDenied,
    this.message,
  });

  final bool granted;
  final bool permanentlyDenied;
  final String? message;

  static const LibraryPermissionResult desktop = LibraryPermissionResult(
    granted: true,
    permanentlyDenied: false,
  );
}

/// Permisos de plataforma.
///
/// En Windows el acceso al sistema de archivos no requiere permisos en tiempo
/// de ejecución; en Android se piden `READ_MEDIA_AUDIO` (API 33+) o
/// almacenamiento (API < 33) y, opcionalmente, acceso total para carpetas
/// fuera de las colecciones multimedia.
class PermissionService {
  static const String _tag = 'Permissions';

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Comprueba el permiso sin abrir diálogos. Se usa al restaurar la sesión:
  /// si el acceso sigue concedido no debe molestarse al usuario al arrancar.
  Future<bool> hasLibraryAccess() async {
    if (!isAndroid) return true;
    try {
      PermissionStatus status = await Permission.audio.status;
      if (status.isGranted || status.isLimited) return true;
      status = await Permission.storage.status;
      return status.isGranted || status.isLimited;
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo consultar el permiso de audio', error, stack);
      return false;
    }
  }

  /// Renueva el acceso a la biblioteca solo cuando ha dejado de estar disponible.
  Future<bool> refreshLibraryAccess() async {
    if (await hasLibraryAccess()) return true;
    final LibraryPermissionResult result = await requestLibraryAccess();
    return result.granted;
  }

  Future<LibraryPermissionResult> requestLibraryAccess() async {
    if (!isAndroid) return LibraryPermissionResult.desktop;

    try {
      PermissionStatus status = await Permission.audio.request();
      if (status.isGranted || status.isLimited) {
        return const LibraryPermissionResult(
          granted: true,
          permanentlyDenied: false,
        );
      }

      // Android 12 y anteriores: permiso de almacenamiento clásico.
      status = await Permission.storage.request();
      if (status.isGranted || status.isLimited) {
        return const LibraryPermissionResult(
          granted: true,
          permanentlyDenied: false,
        );
      }

      if (status.isPermanentlyDenied) {
        return const LibraryPermissionResult(
          granted: false,
          permanentlyDenied: true,
          message:
              'El acceso a archivos fue denegado permanentemente. '
              'Actívalo en los ajustes del sistema.',
        );
      }

      return const LibraryPermissionResult(
        granted: false,
        permanentlyDenied: false,
        message: 'Sin permiso de lectura de audio.',
      );
    } catch (error, stack) {
      AppLog.w(_tag, 'Error solicitando permisos', error, stack);
      return const LibraryPermissionResult(
        granted: false,
        permanentlyDenied: false,
        message: 'No se pudieron solicitar los permisos.',
      );
    }
  }

  /// Permite elegir carpetas arbitrarias en Android 11+.
  ///
  /// Es opcional: el selector de carpetas puede devolver rutas que no estén en
  /// la colección multimedia. Se ofrece desde Ajustes y nunca se pide sola.
  Future<bool> requestAllFilesAccess() async {
    if (!isAndroid) return true;
    try {
      final PermissionStatus status = await Permission.manageExternalStorage
          .request();
      return status.isGranted;
    } catch (error, stack) {
      AppLog.w(_tag, 'MANAGE_EXTERNAL_STORAGE no disponible', error, stack);
      return false;
    }
  }

  Future<bool> requestNotifications() async {
    if (!isAndroid) return true;
    try {
      final PermissionStatus status = await Permission.notification.request();
      return status.isGranted;
    } catch (error, stack) {
      AppLog.w(_tag, 'Permiso de notificaciones no disponible', error, stack);
      return false;
    }
  }

  Future<void> openSettings() => openAppSettings();
}
