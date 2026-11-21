import 'dart:io';

import '../di/service_locator.dart';
import '../utils/logger.dart';
import 'app_mutex.dart';

/// Cierre controlado antes de que un instalador sobrescriba la app.
///
/// Tanto el diálogo automático como el botón manual de Ajustes deben usar este
/// helper: cierra Drift, bandeja, hotkeys y audio, libera el mutex compartido
/// con Inno Setup y termina el proceso para que no queden EXE/DLL bloqueados.
class AppShutdown {
  AppShutdown._();

  static const String _tag = 'AppShutdown';

  static Future<void> forWindowsUpdate() async {
    if (!Platform.isWindows) return;
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
