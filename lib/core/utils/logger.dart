import 'package:flutter/foundation.dart';

/// Logger mínimo con etiqueta, sin dependencias externas.
///
/// En release `debugPrint` sigue funcionando en consola en escritorio y se
/// filtra en Android; para producción se puede conectar a Crashlytics/Sentry.
class AppLog {
  AppLog._();

  static void d(String tag, Object? message) => _emit('D', tag, message);

  static void i(String tag, Object? message) => _emit('I', tag, message);

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
  ]) {
    debugPrint('[$level][$tag] $message');
    if (error != null) debugPrint('[$level][$tag] error: $error');
    if (stack != null) debugPrint(stack.toString());
  }
}
