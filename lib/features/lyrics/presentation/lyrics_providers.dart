import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/models/track.dart';
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
