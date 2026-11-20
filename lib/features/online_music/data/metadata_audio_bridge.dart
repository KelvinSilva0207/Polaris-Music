import 'package:flutter/foundation.dart';

import '../domain/music_source.dart';
import '../domain/music_source_catalog.dart';
import '../domain/online_track.dart';
import 'source_helpers.dart';

/// Puente de metadatos a audio reproducible.
///
/// Spotify y Tidal (y eventualmente cualquier fuente sin stream directo)
/// entregan metadatos y enlaces, pero no audio abierto. En lugar de fingir una
/// URL propia, este puente busca un equivalente en catálogos que sí pueden
/// reproducirse y devuelve esa URL con una etiqueta que dice claramente de dónde
/// salió el audio. Si no hay equivalente razonable, falla con un error de
/// dominio y la interfaz ofrece el enlace original.
class MetadataAudioBridge {
  const MetadataAudioBridge(this._catalog);

  final MusicSourceCatalog _catalog;

  /// Orden de resolución: fuentes anónimas y con URLs directas primero.
  static const List<MusicSourceId> _resolvers = <MusicSourceId>[
    MusicSourceId.youtube,
    MusicSourceId.audius,
    MusicSourceId.soundcloud,
  ];

  Future<ResolvedStream> resolve(OnlineTrack metadata) async {
    final MusicSourceId? source = MusicSourceIdX.fromExternalId(
      metadata.externalId,
    );
    if (source == null) {
      throw const MusicSourceException(
        'No se reconoce el origen de esta pista.',
        source: MusicSourceId.spotify,
        issue: MusicSourceIssue.unsupported,
      );
    }

    for (final MusicSourceId id in _resolvers) {
      final MusicSourceProvider? provider = _catalog.providerFor(id);
      if (provider == null || !provider.canSearch || !provider.canStream) {
        continue;
      }
      try {
        final SourceResult result = await provider.search(
          '"${metadata.title}" ${metadata.artist}',
          limit: 8,
        );
        if (!result.ok || result.items.isEmpty) continue;
        final OnlineTrack? match = _bestMatch(metadata, result.items);
        if (match == null) continue;
        final ResolvedStream stream = await provider.resolveStream(match);
        return ResolvedStream(
          url: stream.url,
          extension: stream.extension,
          mimeType: stream.mimeType,
          httpHeaders: stream.httpHeaders,
          resolvedVia: '${metadata.sourceLabel} → ${id.label}',
          clientLabel: stream.clientLabel,
          alternatives: stream.alternatives,
        );
      } on Object {
        // Un proveedor caído no impide probar el siguiente.
        continue;
      }
    }

    throw MusicSourceException(
      'No encontramos una versión reproducible de “${metadata.title}”. '
      'Esta pista solo está disponible en ${metadata.sourceLabel}.',
      source: source,
      issue: MusicSourceIssue.unsupported,
    );
  }

  /// Elige el candidato con mejor parecido y devuelve `null` si ninguno parece
  /// la misma canción (evita reproducir versiones arbitrarias con el mismo
  /// título genérico).
  @visibleForTesting
  OnlineTrack? bestMatch(OnlineTrack metadata, List<OnlineTrack> candidates) =>
      _bestMatch(metadata, candidates);

  OnlineTrack? _bestMatch(OnlineTrack metadata, List<OnlineTrack> candidates) {
    OnlineTrack? best;
    double bestScore = 0;
    for (final OnlineTrack candidate in candidates) {
      final double title = _similarity(metadata.title, candidate.title);
      final double artist = _similarity(metadata.artist, candidate.artist);
      double duration = 0;
      if (metadata.durationMs > 0 && candidate.durationMs > 0) {
        final double delta = (metadata.durationMs - candidate.durationMs)
            .abs()
            .toDouble();
        duration = (1 - (delta / metadata.durationMs)).clamp(0.0, 1.0);
      } else {
        duration = 0.5;
      }
      final double score = (title * 0.65) + (artist * 0.3) + (duration * 0.05);
      if (score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    return bestScore >= 0.55 ? best : null;
  }

  static double _similarity(String a, String b) {
    final String left = _normalize(a);
    final String right = _normalize(b);
    if (left.isEmpty || right.isEmpty) return 0;
    if (left == right) return 1;
    if (left.contains(right) || right.contains(left)) return 0.85;
    final Set<String> leftWords = left.split(' ').toSet();
    final Set<String> rightWords = right.split(' ').toSet();
    final int intersection = leftWords.intersection(rightWords).length;
    final int union = leftWords.union(rightWords).length;
    return union == 0 ? 0 : intersection / union;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
