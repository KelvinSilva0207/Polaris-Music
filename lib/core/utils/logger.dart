import 'dart:io';

import 'package:flutter/foundation.dart';

/// Logger mínimo con etiqueta, sin dependencias externas.
///
/// En release `debugPrint` sigue funcionando en consola en escritorio y se
/// filtra en Android. Además, tras llamar a [initialize], cada línea se guarda
/// en un archivo dentro de la carpeta de datos del usuario para poder
/// diagnosticar fallos que ocurren antes de que la interfaz esté lista.
class AppLog {
  AppLog._();

  static const String _fileName = 'polaris.log';
  static const int _maxBytes = 2 * 1024 * 1024;

  static String? _filePath;
  static bool _fileEnabled = false;

  /// Ruta del archivo de registro, o `null` si no se pudo crear.
  static String? get filePath => _filePath;

  /// Prepara el registro en disco. Nunca lanza: si falla, la app sigue igual.
  static Future<void> initialize({String? directory}) async {
    if (_fileEnabled) return;

    try {
      final String base = directory ?? _defaultDirectory();
      final Directory dir = Directory(base);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final File file = File('${dir.path}${Platform.pathSeparator}$_fileName');
      if (await file.exists() && await file.length() > _maxBytes) {
        final File previous = File(
          '${dir.path}${Platform.pathSeparator}polaris.previous.log',
        );
        if (await previous.exists()) await previous.delete();
        await file.rename(previous.path);
      }

      _filePath = file.path;
      _fileEnabled = true;
      _emit('I', 'Log', 'Registro iniciado en ${file.path}');
    } catch (error) {
      debugPrint('[W][Log] No se pudo iniciar el registro en disco: $error');
    }
  }

  static String _defaultDirectory() {
    if (Platform.isWindows) {
      final String? appData =
          Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return '$appData${Platform.pathSeparator}Polaris Music'
            '${Platform.pathSeparator}logs';
      }
    }
    return '${Directory.systemTemp.path}${Platform.pathSeparator}polaris';
  }

  static void d(String tag, Object? message) => _emit('D', tag, message);
  static void i(String tag, Object? message) => _emit('I', tag, message);

  /// Registro para rutas calientes (por ejemplo, cada cambio de `af`).
  /// Mantiene la línea en consola pero no bloquea el hilo de UI con disco.
  static void iFast(String tag, Object? message) =>
      _emit('I', tag, message, null, null, false);

  static void w(String tag, Object? message, [Object? error, StackTrace? st]) =>
      _emit('W', tag, message, error, st);

  static void e(String tag, Object? message, [Object? error, StackTrace? st]) =>
      _emit('E', tag, message, error, st);

  static void _emit(
    String level,
    String tag,
    Object? message, [
    Object? error,
    StackTrace? stack,
    bool file = true,
  ]) {
    final String line =
        '[${DateTime.now().toIso8601String()}][$level][$tag] '
        '$message';
    debugPrint(line);
    if (error != null) debugPrint('[$level][$tag] error: $error');
    if (stack != null) debugPrint(stack.toString());

    if (!file || !_fileEnabled) return;
    final String? path = _filePath;
    if (path == null) return;

    final StringBuffer buffer = StringBuffer(line)..writeln();
    if (error != null) buffer.writeln('[$level][$tag] error: $error');
    if (stack != null) buffer.writeln(stack);

    try {
      // Volumen bajo y escritura síncrona: así el último error queda en disco
      // incluso si el proceso se cierra de inmediato.
      File(path).writeAsStringSync(
        buffer.toString(),
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Un fallo del registro nunca debe tumbar la app.
    }
  }
}
