import 'dart:io';

import '../di/service_locator.dart';
import '../utils/logger.dart';
import 'app_mutex.dart';

/// Cierre controlado de la aplicación.
///
/// Todas las salidas (bandeja, actualización de Windows, Ajustes y botón `X`
/// de la notificación de Android) pasan por aquí: cierra Drift, bandeja,
/// hotkeys, audio y servicio en primer plano, libera el mutex compartido con
/// Inno Setup y termina el proceso para que no queden EXE/DLL bloqueados ni
/// reinicios fantasma del servicio multimedia.
class AppShutdown {
  AppShutdown._();

  static const String _tag = 'AppShutdown';

  static bool _quitting = false;

  /// Cierre previo a que un instalador sobrescriba la app en Windows.
  static Future<void> forWindowsUpdate() async {
    if (!Platform.isWindows) return;
    await quit('actualización de Windows');
  }

  /// Cierre total solicitado desde la notificación multimedia de Android.
  static Future<void> forMediaNotification() async {
    if (!Platform.isAndroid) return;
    await quit('notificación multimedia');
  }

  /// Cierre total con protección contra solicitudes duplicadas.
  static Future<void> quit([String reason = 'solicitud manual']) async {
    if (_quitting) return;
    _quitting = true;
    AppLog.i(_tag, 'Cerrando Polaris Music ($reason)');
    try {
      await ServiceLocator.shutdown();
    } catch (error, stack) {
      AppLog.w(_tag, 'No se pudo cerrar la app limpiamente', error, stack);
    } finally {
      AppMutex.release();
      exit(0);
    }
  }
}
