import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../utils/logger.dart';

/// Mutex global de Windows compartido con el instalador de Inno Setup.
///
/// El instalador declara `AppMutex=PolarisMusicMutex`, por lo que necesita que
/// la app mantenga el mutex abierto mientras esté en primer plano **o en la
/// bandeja**. Así `CloseApplications=yes` puede liberar también los procesos
/// residentes sin dejar `.dll` bloqueados.
class AppMutex {
  AppMutex._();

  static const String _tag = 'AppMutex';
  static const String name = 'PolarisMusicMutex';

  static Pointer<Void>? _handle;

  /// Adquiere el mutex. Devuelve `false` si otra instancia ya lo tiene.
  ///
  /// En plataformas que no son Windows no hace nada y devuelve `true`.
  static bool acquire() {
    if (!Platform.isWindows) return true;
    if (_handle != null) return true;

    try {
      final DynamicLibrary kernel32 = DynamicLibrary.open('kernel32.dll');
      final _CreateMutexW createMutex = kernel32
          .lookupFunction<_CreateMutexWNative, _CreateMutexW>('CreateMutexW');
      final _GetLastError getLastError = kernel32
          .lookupFunction<_GetLastErrorNative, _GetLastError>('GetLastError');

      final Pointer<Utf16> namePtr = name.toNativeUtf16();
      try {
        final Pointer<Void> handle = createMutex(nullptr, 0, namePtr);
        if (handle == nullptr) {
          AppLog.w(_tag, 'CreateMutexW devolvió un handle nulo');
          return true;
        }
        _handle = handle;
        final bool alreadyRunning = getLastError() == _errorAlreadyExists;
        if (alreadyRunning) {
          AppLog.w(
            _tag,
            'Ya hay otra instancia con el mutex $name; se cierra esta',
          );
        } else {
          AppLog.i(_tag, 'Mutex $name registrado');
        }
        return !alreadyRunning;
      } finally {
        malloc.free(namePtr);
      }
    } catch (error, stack) {
      // Un mutex indisponible no debe impedir el arranque: el instalador
      // todavía puede detectar el proceso por su ventana principal.
      AppLog.w(_tag, 'No se pudo registrar el mutex de Windows', error, stack);
      return true;
    }
  }

  /// Libera el mutex explícitamente. El sistema también lo libera al salir.
  static void release() {
    final Pointer<Void>? handle = _handle;
    if (handle == null || !Platform.isWindows) return;
    try {
      final DynamicLibrary kernel32 = DynamicLibrary.open('kernel32.dll');
      final _CloseHandle closeHandle = kernel32
          .lookupFunction<_CloseHandleNative, _CloseHandle>('CloseHandle');
      closeHandle(handle);
    } catch (_) {
      // Nada que hacer: el proceso está a punto de terminar.
    }
    _handle = null;
  }
}

const int _errorAlreadyExists = 183;

/// Firmas nativas (tipos FFI) y firmas Dart usadas por `lookupFunction`.
typedef _CreateMutexWNative = Pointer<Void> Function(
  Pointer<Void> lpMutexAttributes,
  Int32 bInitialOwner,
  Pointer<Utf16> lpName,
);

typedef _CreateMutexW = Pointer<Void> Function(
  Pointer<Void> lpMutexAttributes,
  int bInitialOwner,
  Pointer<Utf16> lpName,
);

typedef _GetLastErrorNative = Uint32 Function();

typedef _GetLastError = int Function();

typedef _CloseHandleNative = Int32 Function(Pointer<Void> hObject);

typedef _CloseHandle = int Function(Pointer<Void> hObject);
