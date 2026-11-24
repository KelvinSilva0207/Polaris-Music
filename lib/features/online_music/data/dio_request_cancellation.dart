import 'package:dio/dio.dart';

import '../domain/request_cancellation.dart';

/// Adaptador Dio de la abstracción de cancelación del dominio.
///
/// Cada `issue()` entrega un `CancelToken` distinto: cancelar una búsqueda no
/// afecta a una descarga ni a la apertura de otra colección.
class DioRequestCancellation implements OnlineRequestCancellation {
  const DioRequestCancellation();

  @override
  OnlineRequestToken issue() => DioRequestToken();
}

class DioRequestToken implements OnlineRequestToken {
  DioRequestToken();

  final CancelToken dio = CancelToken();

  @override
  bool get isCancelled => dio.isCancelled;

  @override
  void cancel() {
    if (!dio.isCancelled) dio.cancel('Polaris: petición reemplazada');
  }

  @override
  void throwIfCancelled() {
    if (isCancelled) throw const RequestCanceledException();
  }
}

/// Devuelve el `CancelToken` de Dio cuando el token es nuestro, o `null` para
/// cualquier otra implementación (por ejemplo, la de pruebas).
CancelToken? dioCancelTokenOf(OnlineRequestToken? token) =>
    token is DioRequestToken ? token.dio : null;
