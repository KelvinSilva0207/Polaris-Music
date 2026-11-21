import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/models/track.dart';
import '../../player/presentation/player_providers.dart';
import '../data/lyrics_service.dart';

final Provider<LyricsService> lyricsServiceProvider = Provider<LyricsService>(
  (Ref ref) => sl<LyricsService>(),
);

/// Letra de una pista (local, caché o LRCLIB).
final AutoDisposeFutureProviderFamily<LyricsResult?, Track>
lyricsForTrackProvider = FutureProvider.autoDispose
    .family<LyricsResult?, Track>((Ref ref, Track track) {
      return ref.watch(lyricsServiceProvider).resolve(track);
    });

/// Índice de la línea activa. Aunque la posición cambia ~5 veces/s, este
/// provider solo notifica cuando cambia el índice, así que el panel de letras
/// no reconstruye todas sus líneas en cada tick.
final ProviderFamily<int?, Track> lyricsActiveIndexProvider =
    Provider.family<int?, Track>((Ref ref, Track track) {
      final LyricsResult? result = ref
          .watch(lyricsForTrackProvider(track))
          .valueOrNull;
      if (result == null || !result.document.synced) return null;
      final int positionMs = ref.watch(
        playerControllerProvider.select(
          (s) => s.playback.position.inMilliseconds,
        ),
      );
      return result.document.activeIndexAt(Duration(milliseconds: positionMs));
    });
