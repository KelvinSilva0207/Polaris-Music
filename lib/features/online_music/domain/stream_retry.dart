import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/logger.dart';
import 'music_source.dart';
import 'online_music_repository.dart';
import 'online_track.dart';

/// Errores por los que merece la pena volver a resolver una URL de audio.
///
/// Una URL de YouTube Music (y la de cualquier puente que la use) lleva una
/// firma con validez corta. Un `403` o un fallo de red no significa que la pista
/// no exista: significa que hay que pedir una URL nueva. Los errores de región
/// o de contenido no disponible se marcan como definitivos para no machacar el
/// servicio con reintentos inútiles.
@immutable
class StreamRetryPolicy {
  const StreamRetryPolicy({
    this.attempts = 2,
    this.delay = const Duration(milliseconds: 350),
  });

  final int attempts;
  final Duration delay;

  static const StreamRetryPolicy standard = StreamRetryPolicy();

  bool isTransient(Object error) {
    if (error is MusicSourceFailure) {
      return switch (error.issue) {
        MusicSourceIssue.offline ||
        MusicSourceIssue.rateLimited ||
        MusicSourceIssue.authentication ||
        MusicSourceIssue.unavailable => true,
        MusicSourceIssue.region ||
        MusicSourceIssue.unsupported ||
        MusicSourceIssue.notConfigured ||
        MusicSourceIssue.canceled => false,
      };
    }
    final String message = error.toString().toLowerCase();
    if (message.contains('region') ||
        message.contains('not available') ||
        message.contains('unsupported')) {
      return false;
    }
    return true;
  }
}

/// Audio vigente junto a su carátula (que puede fallar sin impedir sonido).
@immutable
class ResolvedAudio {
  const ResolvedAudio(this.stream, this.artworkPath);

  final ResolvedStream stream;
  final String? artworkPath;
}

/// Resuelve el audio de una pista con reintento y sin dejar que un fallo de
/// carátula impida la reproducción.
class ResilientStreamResolver {
  const ResilientStreamResolver(
    this._repository, {
    this.policy = StreamRetryPolicy.standard,
  });

  final OnlineMusicRepository _repository;
  final StreamRetryPolicy policy;

  Future<ResolvedAudio> resolve(OnlineTrack track) async {
    Object? lastError;
    for (int attempt = 0; attempt <= policy.attempts; attempt++) {
      // La carátula se cachea en paralelo: si tarda o falla, el audio ya puede
      // seguir adelante y la pista se construye sin carátula.
      final Future<String?> artwork = _repository
          .cacheArtworkFor(track)
          .catchError((Object error, StackTrace stack) {
            AppLog.w(
              'StreamRetry',
              'Carátula no disponible para “${track.title}”',
              error,
              stack,
            );
            return null;
          });
      try {
        final ResolvedStream stream = await _repository.resolveStream(track);
        final String? artworkPath = await artwork;
        return ResolvedAudio(stream, artworkPath);
      } on Object catch (error, stack) {
        lastError = error;
        if (!policy.isTransient(error) || attempt == policy.attempts) {
          AppLog.w(
            'StreamRetry',
            'No se pudo resolver “${track.title}” tras ${attempt + 1} intento(s)',
            error,
            stack,
          );
          rethrow;
        }
        AppLog.w(
          'StreamRetry',
          'Reintentando el audio de “${track.title}” (${attempt + 1}/${policy.attempts})',
          error,
        );
        await Future<void>.delayed(policy.delay);
      }
    }
    // El bucle siempre devuelve o relanza; esto solo acalla el analizador.
    throw lastError ?? StateError('No se pudo resolver el stream');
  }
}
