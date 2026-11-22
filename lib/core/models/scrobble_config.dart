/// Configuración de scrobbling guardada como un único JSON en preferencias.
///
/// Sirve tanto para Last.fm como para servidores compatibles con su API 2.0:
/// [endpoint] permite apuntar a otro servidor sin tocar el código.
class ScrobbleConfig {
  const ScrobbleConfig({
    this.enabled = false,
    this.apiKey = '',
    this.apiSecret = '',
    this.sessionKey = '',
    this.username = '',
    this.endpoint = '',
    this.pendingToken = '',
  });

  static const ScrobbleConfig empty = ScrobbleConfig();

  final bool enabled;
  final String apiKey;
  final String apiSecret;
  final String sessionKey;
  final String username;
  final String endpoint;
  final String pendingToken;

  bool get connected =>
      apiKey.isNotEmpty && apiSecret.isNotEmpty && sessionKey.isNotEmpty;

  bool get ready => enabled && connected;

  ScrobbleConfig copyWith({
    bool? enabled,
    String? apiKey,
    String? apiSecret,
    String? sessionKey,
    String? username,
    String? endpoint,
    String? pendingToken,
  }) {
    return ScrobbleConfig(
      enabled: enabled ?? this.enabled,
      apiKey: apiKey ?? this.apiKey,
      apiSecret: apiSecret ?? this.apiSecret,
      sessionKey: sessionKey ?? this.sessionKey,
      username: username ?? this.username,
      endpoint: endpoint ?? this.endpoint,
      pendingToken: pendingToken ?? this.pendingToken,
    );
  }

  factory ScrobbleConfig.fromJson(Object? value) {
    if (value is! Map) return ScrobbleConfig.empty;
    final Map<dynamic, dynamic> map = value;
    String text(String key) => (map[key] ?? '').toString().trim();
    return ScrobbleConfig(
      enabled: map['enabled'] == true,
      apiKey: text('apiKey'),
      apiSecret: text('apiSecret'),
      sessionKey: text('sessionKey'),
      username: text('username'),
      endpoint: text('endpoint'),
      pendingToken: text('pendingToken'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'enabled': enabled,
    'apiKey': apiKey,
    'apiSecret': apiSecret,
    'sessionKey': sessionKey,
    'username': username,
    'endpoint': endpoint,
    'pendingToken': pendingToken,
  };

  @override
  bool operator ==(Object other) =>
      other is ScrobbleConfig &&
      other.enabled == enabled &&
      other.apiKey == apiKey &&
      other.apiSecret == apiSecret &&
      other.sessionKey == sessionKey &&
      other.username == username &&
      other.endpoint == endpoint &&
      other.pendingToken == pendingToken;

  @override
  int get hashCode => Object.hash(
    enabled,
    apiKey,
    apiSecret,
    sessionKey,
    username,
    endpoint,
    pendingToken,
  );
}
