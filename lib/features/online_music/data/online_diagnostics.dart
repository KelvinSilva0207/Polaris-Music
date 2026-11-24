import '../../../core/utils/logger.dart';

/// Reportera opcional para conectar después el logger Beta.
///
/// Firma pública: `void Function(String tag, String message,
/// {Object? error, StackTrace? stack})`. Los mensajes y errores ya llegan
/// sanitizados; quien reporte no debe volver a exponerlos tal cual.
typedef OnlineDiagnosticsReporter = void Function(
  String tag,
  String message, {
  Object? error,
  StackTrace? stack,
});

/// Punto único de diagnóstico del módulo online.
///
/// Siempre escribe en `AppLog` y, si se ha conectado un reporter externo, también
/// le avisa. Nunca lanza: un fallo del logger no puede romper una búsqueda.
class OnlineDiagnostics {
  OnlineDiagnostics._();

  static OnlineDiagnosticsReporter? _reporter;

  /// `null` desconecta el reporter externo y deja solo `AppLog`.
  static void setReporter(OnlineDiagnosticsReporter? reporter) =>
      _reporter = reporter;

  static void report(
    String tag,
    String message, {
    Object? error,
    StackTrace? stack,
  }) {
    final String safeMessage = sanitize(message);
    final Object? safeError = error == null ? null : sanitize(error);
    final OnlineDiagnosticsReporter? reporter = _reporter;
    if (reporter != null) {
      try {
        reporter(tag, safeMessage, error: safeError, stack: stack);
      } on Object {
        // El reporter Beta es best-effort: AppLog sigue siendo la red de seguridad.
      }
    }
    if (error != null || stack != null) {
      AppLog.w(tag, safeMessage, safeError, stack);
    } else {
      AppLog.i(tag, safeMessage);
    }
  }

  /// Quita URLs de googlevideo, tokens, `visitorData` y cabeceras Bearer.
  static String sanitize(Object? value) {
    if (value == null) return '';
    String text = value is StackTrace ? value.toString() : '$value';
    text = text.replaceAll(
      RegExp(
        r'https?://[^\s<>)\]]*googlevideo[^\s<>)\]]*',
        caseSensitive: false,
      ),
      '[url-de-googlevideo-redactada]',
    );
    text = text.replaceAll(
      RegExp(
        r'(visitorData|X-Goog-Visitor-Id)\s*[:=]\s*[^\s&,]+',
        caseSensitive: false,
      ),
      r'$1=[redactado]',
    );
    text = text.replaceAll(
      RegExp(
        r'(authorization|bearer|access[_-]?token|refresh[_-]?token|'
        r'api[_-]?key|token)\s*[:=]\s*[^\s&,]+',
        caseSensitive: false,
      ),
      r'$1=[redactado]',
    );
    text = text.replaceAll(
      RegExp(r'\bBearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
      'Bearer [redactado]',
    );
    text = text.replaceAll(
      RegExp(
        r'([?&](?:pot|signature|sig|lsig|token|access_token|expire|key|xt|n|s)=)'
        r'[^&\s]+',
        caseSensitive: false,
      ),
      r'$1[redactado]',
    );
    return text.length > 400 ? '${text.substring(0, 397)}…' : text;
  }

  /// Referencias seguras de persistir: sin parámetros firmados.
  static String? safeReferenceUrl(String? url) {
    final String clean = sanitize(url).trim();
    if (clean.isEmpty) return null;
    final Uri? uri = Uri.tryParse(clean);
    if (uri == null) return null;
    if (!uri.hasQuery) return uri.toString();
    final Map<String, String> query = <String, String>{
      for (final MapEntry<String, String> entry in uri.queryParameters.entries)
        if (!_sensitiveParam(entry.key)) entry.key: entry.value,
    };
    return uri
        .replace(queryParameters: query.isEmpty ? null : query)
        .toString();
  }

  static bool _sensitiveParam(String key) => RegExp(
    r'^(pot|signature|sig|lsig|token|access_token|refresh_token|'
    r'expire|key|xt|n|s|visitorData)$',
    caseSensitive: false,
  ).hasMatch(key);
}
