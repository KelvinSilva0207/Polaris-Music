import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/track.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/track_tile.dart';
import '../domain/stats_service.dart';
import 'stats_providers.dart';

/// Estadísticas de escucha, resumen anual y limpieza del historial.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ListeningStats> stats = ref.watch(listeningStatsProvider);
    final AsyncValue<WrappedStats> wrapped = ref.watch(wrappedStatsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(listeningStatsProvider);
        ref.invalidate(wrappedStatsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Estadísticas',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 30),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tu año musical, en datos',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: () {
                  ref.invalidate(listeningStatsProvider);
                  ref.invalidate(wrappedStatsProvider);
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Borrar historial',
                onPressed: () => _confirmClear(context, ref),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _WrappedCard(wrapped: wrapped),
          const SizedBox(height: 26),
          const SectionHeader(
            title: 'Últimos 30 días',
            subtitle: 'Tiempo escuchado por día',
          ),
          _DailyChart(stats: stats),
          const SizedBox(height: 26),
          const SectionHeader(
            title: 'Más escuchadas',
            subtitle: 'Las pistas que más has reproducido',
          ),
          _TopTracks(stats: stats),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Borrar historial de escucha'),
        content: const Text(
          'Se eliminarán las reproducciones registradas y las estadísticas '
          'volverán a cero. Las pistas y favoritos de la biblioteca no se '
          'modifican.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(statsServiceProvider).clearHistory();
    ref.invalidate(listeningStatsProvider);
    ref.invalidate(wrappedStatsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Historial borrado')));
    }
  }
}

class _WrappedCard extends StatelessWidget {
  const _WrappedCard({required this.wrapped});

  final AsyncValue<WrappedStats> wrapped;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final WrappedStats? value = wrapped.valueOrNull;
    final bool empty = value == null || value.isEmpty;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            tokens.accent.withValues(alpha: 0.34),
            const Color(0xFF3B1D5E).withValues(alpha: 0.55),
            const Color(0xFF151020),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.auto_awesome_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                'Polaris Wrapped ${value?.year ?? DateTime.now().year}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (wrapped.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (empty)
            const Text(
              'Aún no hay suficientes datos este año. Escucha algo de música y '
              'vuelve a mirar.',
              style: TextStyle(color: Colors.white70),
            )
          else
            Wrap(
              spacing: 26,
              runSpacing: 18,
              children: <Widget>[
                _WrappedStat(
                  label: 'Tiempo total',
                  value: Formatters.listeningTime(value.totalMs),
                ),
                _WrappedStat(
                  label: 'Reproducciones',
                  value: '${value.totalPlays}',
                ),
                _WrappedStat(
                  label: 'Pistas distintas',
                  value: '${value.uniqueTracks}',
                ),
                _WrappedStat(label: 'Artista del año', value: value.topArtist),
                if (value.topTrack != null)
                  _WrappedStat(
                    label: 'Canción del año',
                    value: value.topTrack!.title,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WrappedStat extends StatelessWidget {
  const _WrappedStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white60),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.stats});

  final AsyncValue<ListeningStats> stats;

  @override
  Widget build(BuildContext context) {
    return stats.when(
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stack) => Text(
        'No se pudieron cargar las estadísticas: $error',
        style: const TextStyle(color: Colors.redAccent),
      ),
      data: (ListeningStats value) {
        if (value.byDay.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Sin escuchas registradas todavía.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        final List<DailyListening> days = value.byDay.reversed.toList(
          growable: false,
        );
        final int maxMs = days.fold<int>(
          1,
          (int best, DailyListening d) => math.max(best, d.msPlayed),
        );
        final PolarisTokens tokens = context.tokens;

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 130,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: days
                      .map((DailyListening day) {
                        final double factor = day.msPlayed / maxMs;
                        return Expanded(
                          child: Tooltip(
                            message:
                                '${Formatters.date(day.day)}\n${Formatters.listeningTime(day.msPlayed)} · ${day.plays} reproducciones',
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1.5,
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: (factor * 126).clamp(2, 126),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: <Color>[
                                        tokens.accent,
                                        tokens.accent.withValues(alpha: 0.35),
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    Formatters.date(days.first.day),
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                  Text(
                    Formatters.date(days.last.day),
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopTracks extends StatelessWidget {
  const _TopTracks({required this.stats});

  final AsyncValue<ListeningStats> stats;

  @override
  Widget build(BuildContext context) {
    return stats.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stack) =>
          Text('No se pudieron cargar las pistas: $error'),
      data: (ListeningStats value) {
        if (value.topTracks.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Reproduce algunas canciones para llenar este ranking.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return Column(
          children: value.topTracks
              .take(10)
              .map(
                (Track track) => TrackTile(
                  track: track,
                  queue: value.topTracks,
                  trailing: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '${track.playCount}×',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}
