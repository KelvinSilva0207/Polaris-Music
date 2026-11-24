import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../constants/app_paths.dart';
import '../utils/logger.dart';

/// Registro Beta de fallos, separado de [AppLog] pero alimentado por él.
///
/// Contrato importante: **un solo `AppLog.e` por error**. `main.dart` ya no
/// escribe directamente en los handlers globales; delega aquí. Así no se
/// duplican líneas en el registro de usuario ni se presenta dos veces el error.
///
/// Escritura: cola asíncrona con `flush: true`, para no bloquear el isolate de
/// la interfaz y a la vez conservar el último evento tras un cierre brusco.
///
/// Rotación: 5 archivos como máximo (`beta_crash.log` + `.1`..`.4`) y ~2 MB en
/// total (400 KB por archivo). Los archivos son `.log` legibles y viven en la
/// carpeta visible de documentos de Polaris (`.../Polaris Music/logs`).
///
/// No depende de GetIt ni de Riverpod: los handlers se instalan antes del
/// bootstrap. La UI puede pasar el texto de `buildDiagnosticsReport` al
/// exportar/compartir, sin acoplar este servicio al `AppUpdaterService`.
class BetaCrashLogger {
  BetaCrashLogger._();

  /// Máximo de archivos de registro conservados.
  static const int maxFiles = 5;

  /// Techo aproximado de todos los archivos juntos (2 MB).
  static const int maxTotalBytes = 2 * 1024 * 1024;

  /// Techo por archivo: `maxTotalBytes / maxFiles`.
  static int get maxFileBytes => maxTotalBytes ~/ maxFiles;

  static const String _currentName = 'beta_crash.log';
  static const String _folderName = 'logs';
  static const String _diagnosticsName = 'diagnostico.txt';

  /// Activa o desactiva el registro Beta.
  ///
  /// Aun desactivado, los errores globales siguen llegando a [AppLog] (el
  /// registro base de la app); solo se omite el archivo Beta y el contador.
  static bool isBetaLoggingEnabled = true;

  /// Contador de errores capturados (no incluye avisos).
  ///
  /// Es un [ValueNotifier] para que Ajustes pueda mostrarlo en vivo con
  /// `ValueListenableBuilder`, igual que hace la sección de atajos.
  static final ValueNotifier<int> errorCount = ValueNotifier<int>(0);

  /// Número de errores registrados desde el inicio o desde [clearLogs].
  static int get loggedErrors => errorCount.value;

  /// Directorio resuelto de los registros, o `null` si no se pudo crear.
  static String? get logDirectory => _directory;

  static String? _directory;
  static bool _initialized = false;
  static bool _installed = false;
  static void Function(FlutterErrorDetails)? _previousFlutter;
  static bool Function(Object, StackTrace)? _previousPlatform;

  static final Queue<String> _pending = Queue<String>();
  static Completer<void>? _activeDrain;
  static String? _lastFingerprint;
  static DateTime? _lastAt;
  static bool _handling = false;

  /// Prepara la carpeta de registros. Nunca lanza: un fallo aquí no puede
  /// impedir el arranque de la app.
  ///
  /// Con [directory] se usa esa ruta (tests). Sin ella se usa la carpeta
  /// visible de documentos de Polaris, que en Android es el directorio
  /// externo propio del paquete y en Windows `Documentos\Polaris Music`.
  static Future<void> initialize({String? directory}) async {
    if (_initialized) return;
    _initialized = true;
    try {
      final Directory base = directory != null
          ? Directory(directory)
          : Directory(p.join((await AppPaths.documents()).path, _folderName));
      if (!await base.exists()) {
        await base.create(recursive: true);
      }
      _directory = base.path;
    } catch (error, stack) {
      _directory = null;
      AppLog.w(
        'BetaCrash',
        'No se pudo preparar la carpeta de registros Beta',
        error,
        stack,
      );
    }
  }

  /// Instala los dos handlers globales una sola vez, encadenando los
  /// anteriores en lugar de reemplazarlos sin más.
  static void install() {
    if (_installed) return;
    _installed = true;
    _previousFlutter = FlutterError.onError;
    _previousPlatform = PlatformDispatcher.instance.onError;
    FlutterError.onError = recordFlutterError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      recordPlatformError(error, stack);
      // Igual que el handler previo de main.dart: el error se considera
      // atendido para que Flutter no vuelca un segundo informe por consola.
      return true;
    };
  }

  /// Captura de errores del framework Flutter.
  static void recordFlutterError(FlutterErrorDetails details) {
    if (_handling) return;
    _handling = true;
    try {
      final void Function(FlutterErrorDetails)? previous = _previousFlutter;
      if (previous != null) {
        previous(details);
      } else {
        FlutterError.presentError(details);
      }
      // Único AppLog.e de este camino.
      AppLog.e(
        'Flutter',
        details.exceptionAsString(),
        details.exception,
        details.stack,
      );
      _record(
        tag: 'Flutter',
        message: details.exceptionAsString(),
        error: details.exception,
        stack: details.stack,
      );
    } catch (_) {
      // Un handler de errores nunca debe propagar una excepción.
    } finally {
      _handling = false;
    }
  }

  /// Captura de errores asíncronos fuera del árbol de Flutter.
  static void recordPlatformError(Object error, StackTrace stack) {
    if (_handling) return;
    _handling = true;
    try {
      _previousPlatform?.call(error, stack);
      // Único AppLog.e de este camino.
      AppLog.e('Platform', error, error, stack);
      _record(
        tag: 'Platform',
        message: error.toString(),
        error: error,
        stack: stack,
      );
    } catch (_) {
      // Un handler de errores nunca debe propagar una excepción.
    } finally {
      _handling = false;
    }
  }

  /// API pública estable para avisos de red / sincronización parcial.
  ///
  /// Escribe en el registro Beta si está activo, pero **no** incrementa el
  /// contador de errores: un reintento o una sincronización incompleta no es
  /// un crash. Pensado para ser llamado desde fuentes online (p. ej. YouTube
  /// Music) sin depender de GetIt ni de la UI.
  static void logWarning(
    String tag,
    Object? message, {
    Object? error,
    StackTrace? stack,
  }) {
    if (!isBetaLoggingEnabled) return;
    final StringBuffer line = StringBuffer()
      ..write('[${DateTime.now().toIso8601String()}] [W][$tag] ')
      ..write(message);
    if (error != null) line.write(' | error: $error');
    if (stack != null) {
      line
        ..writeln()
        ..write(stack);
    }
    line.writeln();
    _enqueue(line.toString());
  }

  /// API pública para errores reportados explícitamente desde un feature.
  ///
  /// A diferencia de [logWarning], sí incrementa [errorCount] y aplica la
  /// deduplicación por huella. No llama a [AppLog.e]: quien reporta ya suele
  /// haber registrado el error en el log base.
  static void logError(
    String tag,
    Object? message, {
    Object? error,
    StackTrace? stack,
  }) {
    if (!isBetaLoggingEnabled) return;
    _record(
      tag: tag,
      message: message?.toString() ?? '',
      error: error,
      stack: stack,
    );
  }

  /// Espera a que terminen las escrituras pendientes.
  static Future<void> flush() => _activeDrain?.future ?? Future<void>.value();

  /// Archivos de registro existentes, del más reciente al más antiguo.
  static List<File> logFiles() {
    final String? dir = _directory;
    if (dir == null) return const <File>[];
    final List<File> files = <File>[];
    final File current = File(p.join(dir, _currentName));
    if (current.existsSync()) files.add(current);
    for (int i = 1; i < maxFiles; i++) {
      final File file = File(p.join(dir, _rotatedName(i)));
      if (file.existsSync()) files.add(file);
    }
    return files;
  }

  /// Suma de bytes de todos los archivos de registro Beta.
  static int logBytes() => logFiles().fold<int>(
    0,
    (int total, File file) => total + file.lengthSync(),
  );

  /// Borra todos los archivos Beta y reinicia el contador. Devuelve cuántos
  /// archivos se eliminaron.
  static Future<int> clearLogs() async {
    await flush();
    int removed = 0;
    for (final File file in logFiles()) {
      try {
        if (await file.exists()) {
          await file.delete();
          removed++;
        }
      } catch (_) {
        // Un archivo bloqueado no debe impedir limpiar los demás.
      }
    }
    errorCount.value = 0;
    _lastFingerprint = null;
    _lastAt = null;
    return removed;
  }

  /// Genera un ZIP con todos los registros y el texto de diagnóstico.
  ///
  /// [diagnostics] lo facilita la UI (`buildDiagnosticsReport`) para no
  /// acoplar este servicio a `AppUpdaterService`/GetIt.
  static Future<String> exportLogs({String? diagnostics}) async {
    await flush();
    final String dir = _directory ?? await _fallbackDirectory();
    final Archive archive = Archive();
    for (final File file in logFiles()) {
      try {
        archive.addFile(
          ArchiveFile.bytes(p.basename(file.path), await file.readAsBytes()),
        );
      } catch (_) {
        // Un archivo ilegible se omite; el resto del informe se conserva.
      }
    }
    archive.addFile(
      ArchiveFile.bytes(
        _diagnosticsName,
        utf8.encode(
          diagnostics == null || diagnostics.trim().isEmpty
              ? 'Polaris Music — diagnóstico Beta'
              : diagnostics.trim(),
        ),
      ),
    );
    final List<int> bytes = ZipEncoder().encode(archive);
    final String stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final File target = File(p.join(dir, 'polaris_diagnostico_$stamp.zip'));
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  /// Exporta y abre el sheet de compartir nativo con el ZIP adjunto.
  static Future<void> shareLogs({String? diagnostics}) async {
    final String path = await exportLogs(diagnostics: diagnostics);
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(path)],
        text: 'Informe de diagnóstico Beta de Polaris Music',
        subject: 'Polaris Music — Diagnóstico Beta',
      ),
    );
  }

  /// Reinicia todo el estado estático. Solo para tests.
  @visibleForTesting
  static void resetForTesting() {
    if (_installed) {
      FlutterError.onError = _previousFlutter;
      PlatformDispatcher.instance.onError = _previousPlatform;
    }
    _installed = false;
    _previousFlutter = null;
    _previousPlatform = null;
    _initialized = false;
    _directory = null;
    _pending.clear();
    _activeDrain = null;
    _lastFingerprint = null;
    _lastAt = null;
    errorCount.value = 0;
    isBetaLoggingEnabled = true;
  }

  /// Envía una línea arbitraria a la cola. Solo para tests de rotación.
  @visibleForTesting
  static void enqueueForTesting(String line) => _enqueue(line);

  static void _record({
    required String tag,
    required String message,
    Object? error,
    StackTrace? stack,
  }) {
    if (!isBetaLoggingEnabled) return;
    final String fingerprint =
        '$tag|${error.runtimeType}|$message|${_firstFrame(stack)}';
    final DateTime now = DateTime.now();
    if (fingerprint == _lastFingerprint &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(seconds: 1)) {
      return;
    }
    _lastFingerprint = fingerprint;
    _lastAt = now;
    errorCount.value++;

    final StringBuffer line = StringBuffer()
      ..write('[${now.toIso8601String()}] [E][$tag] ')
      ..write(message);
    if (error != null && error.toString() != message) {
      line.write(' | error: $error');
    }
    if (stack != null) {
      line
        ..writeln()
        ..write(stack);
    }
    line.writeln();
    _enqueue(line.toString());
  }

  static String _firstFrame(StackTrace? stack) {
    if (stack == null) return '';
    final RegExpMatch? match = RegExp(r'#\d+\s+[^ ]+\s+([^ ]+)')
        .firstMatch(stack.toString());
    return match?.group(1) ?? '';
  }

  static void _enqueue(String line) {
    if (!isBetaLoggingEnabled) return;
    _pending.addLast(line);
    final Completer<void>? active = _activeDrain;
    if (active != null) return;
    final Completer<void> completer = Completer<void>();
    _activeDrain = completer;
    unawaited(_drain(completer));
  }

  static Future<void> _drain(Completer<void> completer) async {
    try {
      while (_pending.isNotEmpty) {
        final String line = _pending.removeFirst();
        try {
          await _writeLine(line);
        } catch (_) {
          // El registro nunca debe tumbar la app.
        }
      }
    } finally {
      _activeDrain = null;
      if (!completer.isCompleted) completer.complete();
    }
  }

  static Future<void> _writeLine(String line) async {
    final String? dir = _directory;
    if (dir == null) return;
    final File current = File(p.join(dir, _currentName));
    int length = 0;
    try {
      if (await current.exists()) length = await current.length();
    } catch (_) {
      length = 0;
    }
    if (length + utf8.encode(line).length > maxFileBytes) {
      await _rotate(dir);
    }
    await current.writeAsString(line, mode: FileMode.append, flush: true);
  }

  static Future<void> _rotate(String dir) async {
    try {
      final File oldest = File(p.join(dir, _rotatedName(maxFiles - 1)));
      if (await oldest.exists()) await oldest.delete();
      for (int i = maxFiles - 2; i >= 1; i--) {
        final File from = File(p.join(dir, _rotatedName(i)));
        final File to = File(p.join(dir, _rotatedName(i + 1)));
        if (await from.exists()) await from.rename(to.path);
      }
      final File current = File(p.join(dir, _currentName));
      if (await current.exists()) {
        await current.rename(p.join(dir, _rotatedName(1)));
      }
    } catch (error, stack) {
      AppLog.w(
        'BetaCrash',
        'No se pudo rotar los registros Beta',
        error,
        stack,
      );
    }
  }

  static String _rotatedName(int index) => 'beta_crash.$index.log';

  static Future<String> _fallbackDirectory() async {
    final String? dir = _directory;
    if (dir != null) return dir;
    final String fallback = p.join(
      Directory.systemTemp.path,
      'polaris',
      _folderName,
    );
    final Directory directory = Directory(fallback);
    if (!await directory.exists()) await directory.create(recursive: true);
    _directory = directory.path;
    return directory.path;
  }
}
