import 'package:flutter/foundation.dart';

import 'online_track.dart';

/// Identificador estable de un proveedor de catálogo online.
enum MusicSourceId { audius, soundcloud, spotify, tidal, youtube }

/// Motivo por el que una fuente no se puede consultar en este momento.
///
/// Se modela en dominio (no como excepción) para que la interfaz pueda mostrar
/// un estado específico sin lanzar errores ni bloquear la búsqueda global.
enum MusicSourceIssue {
  notConfigured,
  authentication,
  region,
  rateLimited,
  offline,
  unavailable,
  unsupported,
}

extension MusicSourceIdX on MusicSourceId {
  String get label => switch (this) {
    MusicSourceId.audius => 'Audius',
    MusicSourceId.soundcloud => 'SoundCloud',
    MusicSourceId.spotify => 'Spotify',
    MusicSourceId.tidal => 'Tidal',
    MusicSourceId.youtube => 'YouTube Music',
  };

  /// Prefijo usado en `externalId` para enrutar descargas y streams.
  String get prefix => switch (this) {
    MusicSourceId.audius => 'audius',
    MusicSourceId.soundcloud => 'soundcloud',
    MusicSourceId.spotify => 'spotify',
    MusicSourceId.tidal => 'tidal',
    MusicSourceId.youtube => 'youtube',
  };

  /// Las APIs de Spotify y Tidal entregan metadatos, no audio reproducible.
  bool get canStreamAudio => switch (this) {
    MusicSourceId.audius ||
    MusicSourceId.soundcloud ||
    MusicSourceId.youtube => true,
    MusicSourceId.spotify || MusicSourceId.tidal => false,
  };

  static MusicSourceId? fromExternalId(String externalId) {
    final int colon = externalId.indexOf(':');
    if (colon <= 0) return null;
    final String prefix = externalId.substring(0, colon);
    for (final MusicSourceId source in MusicSourceId.values) {
      if (source.prefix == prefix) return source;
    }
    return null;
  }
}

/// Disponibilidad de una fuente en el momento actual.
@immutable
class MusicSourceStatus {
  const MusicSourceStatus({
    this.available = true,
    this.issue,
    this.detail = '',
    this.checkedAt,
  });

  final bool available;
  final MusicSourceIssue? issue;
  final String detail;
  final DateTime? checkedAt;

  bool get isConfigured => issue != MusicSourceIssue.notConfigured;
  bool get needsAuth => issue == MusicSourceIssue.authentication;
  bool get isRegionBlocked => issue == MusicSourceIssue.region;

  MusicSourceStatus copyWith({
    bool? available,
    MusicSourceIssue? issue,
    bool clearIssue = false,
    String? detail,
    DateTime? checkedAt,
  }) => MusicSourceStatus(
    available: available ?? this.available,
    issue: clearIssue ? null : (issue ?? this.issue),
    detail: detail ?? this.detail,
    checkedAt: checkedAt ?? this.checkedAt,
  );

  @override
  String toString() =>
      'MusicSourceStatus(available: $available, issue: $issue, detail: $detail)';
}

/// Resultado parcial de una consulta: datos y problema de esa fuente.
@immutable
class SourceResult {
  const SourceResult({
    required this.source,
    this.items = const <OnlineTrack>[],
    this.status = const MusicSourceStatus(),
  });

  final MusicSourceId source;
  final List<OnlineTrack> items;
  final MusicSourceStatus status;

  bool get ok => status.available;
  bool get hasItems => items.isNotEmpty;

  SourceResult copyWith({
    List<OnlineTrack>? items,
    MusicSourceStatus? status,
  }) => SourceResult(
    source: source,
    items: items ?? this.items,
    status: status ?? this.status,
  );
}

/// Contrato de un proveedor de música online.
///
/// Cada proveedor es autocontenido: conoce su autenticación, sus endpoints y
/// si puede resolver audio real. El agregador solo orquesta resultados y
/// errores, de modo que una fuente caída nunca impide consultar las demás.
abstract interface class MusicSourceProvider {
  MusicSourceId get id;

  /// Capacidades declaradas, usadas por la UI para desactivar acciones.
  bool get canSearch;
  bool get canTrending;
  bool get canStream;
  bool get canDownload;

  /// Estado actual. Es síncrono para que la UI no espere red al pintar.
  MusicSourceStatus get status;

  /// Comprueba credenciales/configuración sin lanzar excepciones.
  Future<MusicSourceStatus> checkAvailability();

  /// Busca pistas. Si falla, devuelve un [SourceResult] con el estado, nunca
  /// una excepción: la búsqueda unificada debe seguir con otras fuentes.
  Future<SourceResult> search(String query, {int limit = 25});

  Future<SourceResult> trending({int limit = 25});

  /// Resuelve una URL reproducible. Solo lo implementan fuentes con [canStream].
  Future<ResolvedStream> resolveStream(OnlineTrack track);

  /// Cachea una carátula. Devuelve `null` si no hay imagen o falla.
  Future<String?> cacheArtwork(String? artworkUrl);
}
