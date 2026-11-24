import 'package:flutter/foundation.dart';

/// Señal de que una petición online fue cancelada a propósito.
///
/// Es un tipo de dominio: ni la interfaz ni el controlador necesitan conocer
/// `dio` para distinguir "el usuario escribió de nuevo" de "no hay red".
@immutable
class RequestCanceledException implements Exception {
  const RequestCanceledException([this.message = 'Petición cancelada']);

  final String message;

  @override
  String toString() => message;
}

/// Token emitido para una petición concreta.
///
/// La capa de datos decides cómo translate `cancel()` a su cliente HTTP; el
/// dominio solo necesita saber si debe ignorar el resultado.
abstract interface class OnlineRequestToken {
  bool get isCancelled;

  /// Cancela la petición asociada. Varias llamadas son innocuas.
  void cancel();

  /// Lanza [RequestCanceledException] si la petición ya no interesa.
  void throwIfCancelled();
}

/// Token para pruebas o para operaciones que nunca se cancelan.
@immutable
class NoOpOnlineRequestToken implements OnlineRequestToken {
  const NoOpOnlineRequestToken();

  @override
  bool get isCancelled => false;

  @override
  void cancel() {}

  @override
  void throwIfCancelled() {}
}

/// Fábrica de tokens. Se inyecta en el controlador; la implementación real
/// vive en `data/` (adaptador Dio).
abstract interface class OnlineRequestCancellation {
  OnlineRequestToken issue();

  static const OnlineRequestCancellation none = _NoOpRequestCancellation();
}

@immutable
class _NoOpRequestCancellation implements OnlineRequestCancellation {
  const _NoOpRequestCancellation();

  @override
  OnlineRequestToken issue() => const NoOpOnlineRequestToken();
}
