import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/models/track.dart';
import '../domain/stats_service.dart';

final Provider<StatsService> statsServiceProvider = Provider<StatsService>(
  (Ref ref) => sl<StatsService>(),
);

final FutureProvider<ListeningStats> listeningStatsProvider =
    FutureProvider<ListeningStats>((Ref ref) {
      return ref.watch(statsServiceProvider).listeningStats();
    });

final FutureProvider<WrappedStats> wrappedStatsProvider =
    FutureProvider<WrappedStats>((Ref ref) {
      return ref.watch(statsServiceProvider).wrapped();
    });

final FutureProvider<List<Track>> recommendationsProvider =
    FutureProvider<List<Track>>((Ref ref) {
      return ref.watch(statsServiceProvider).recommendations();
    });
