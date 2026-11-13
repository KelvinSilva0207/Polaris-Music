import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/track.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/track_tile.dart';
import '../../library/presentation/library_providers.dart';
import '../../player/presentation/player_providers.dart';
import '../../stats_sync/domain/stats_service.dart';
import '../../stats_sync/presentation/stats_providers.dart';

/// Pantalla de inicio: resumen, recomendaciones y escucha reciente.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Track>> tracks = ref.watch(libraryTracksProvider);
    final AsyncValue<List<Track>> recommendations = ref.watch(
      recommendationsProvider,
    );
    final AsyncValue<ListeningStats> stats = ref.watch(listeningStatsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(recommendationsProvider);
        ref.invalidate(listeningStatsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
        children: <Widget>[
          _Greeting(onNavigate: onNavigate),
          const SizedBox(height: 20),
          _StatsRow(stats: stats),
          const SizedBox(height: 26),
          if (tracks.valueOrNull?.isEmpty ?? false)
            EmptyState(
              icon: Icons.library_music_outlined,
              title: 'Tu biblioteca está vacía',
              message:
                  'Añade una carpeta con música para empezar. Polaris indexa '
                  'MP3, FLAC, WAV, OGG, Opus, M4A y más.',
              action: FilledButton.icon(
                onPressed: () => onNavigate(1),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Añadir música'),
              ),
            )
          else ...<Widget>[
            SectionHeader(
              title: 'Recomendado para ti',
              subtitle: 'Basado en tus favoritos y artistas más escuchados',
              trailing:
                  recommendations.valueOrNull == null ||
                      recommendations.valueOrNull!.isEmpty
                  ? null
                  : TextButton.icon(
                      onPressed: () {
                        final List<Track> list = recommendations.valueOrNull!;
                        ref
                            .read(playerControllerProvider.notifier)
                            .playQueue(list);
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Reproducir todo'),
                    ),
            ),
            _RecommendationList(recommendations: recommendations),
            const SizedBox(height: 26),
            SectionHeader(
              title: 'Escuchado recientemente',
              subtitle: 'Tus últimas reproducciones',
            ),
            _RecentList(stats: stats),
            const SizedBox(height: 26),
            SectionHeader(
              title: 'Favoritos',
              subtitle: 'Las canciones que marcaste con corazón',
            ),
            const _FavoriteList(),
          ],
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final int hour = DateTime.now().hour;
    final String greeting = hour < 6
        ? 'Buenas noches'
        : hour < 13
        ? 'Buenos días'
        : hour < 20
        ? 'Buenas tardes'
        : 'Buenas noches';
    final TextTheme text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                greeting,
                style: text.headlineMedium?.copyWith(
                  fontSize: 34,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tu universo sonoro, en orden.',
                style: text.bodyMedium?.copyWith(color: Colors.white54),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Buscar en la biblioteca',
          onPressed: () => onNavigate(1),
          icon: const Icon(Icons.search_rounded),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final AsyncValue<ListeningStats> stats;

  @override
  Widget build(BuildContext context) {
    final ListeningStats? value = stats.valueOrNull;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _StatChip(
          icon: Icons.timer_outlined,
          label: 'Tiempo total',
          value: value == null ? '—' : Formatters.listeningTime(value.totalMs),
        ),
        _StatChip(
          icon: Icons.today_outlined,
          label: 'Hoy',
          value: value == null ? '—' : Formatters.listeningTime(value.todayMs),
        ),
        _StatChip(
          icon: Icons.graphic_eq_rounded,
          label: 'Reproducciones',
          value: value == null ? '—' : '${value.totalPlays}',
        ),
        _StatChip(
          icon: Icons.album_outlined,
          label: 'Pistas escuchadas',
          value: value == null ? '—' : '${value.topTracks.length}',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: tokens.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Colors.white54),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationList extends StatelessWidget {
  const _RecommendationList({required this.recommendations});

  final AsyncValue<List<Track>> recommendations;

  @override
  Widget build(BuildContext context) {
    return recommendations.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stack) =>
          _ErrorBox(message: 'No se pudieron calcular recomendaciones: $error'),
      data: (List<Track> tracks) {
        if (tracks.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Reproduce algunas canciones para recibir recomendaciones.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return Column(
          children: tracks
              .take(6)
              .map((Track track) => TrackTile(track: track, queue: tracks))
              .toList(growable: false),
        );
      },
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.stats});

  final AsyncValue<ListeningStats> stats;

  @override
  Widget build(BuildContext context) {
    return stats.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stack) =>
          _ErrorBox(message: 'No se pudo cargar el historial: $error'),
      data: (ListeningStats value) {
        if (value.recent.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Aún no hay reproducciones registradas.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        final List<Track> queue = value.recent
            .map((RecentPlay play) => Track.fromRow(play.track))
            .toList(growable: false);
        return Column(
          children: queue
              .take(5)
              .map((Track track) => TrackTile(track: track, queue: queue))
              .toList(growable: false),
        );
      },
    );
  }
}

class _FavoriteList extends ConsumerWidget {
  const _FavoriteList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Track>> favorites = ref.watch(favoriteTracksProvider);
    return favorites.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stack) =>
          _ErrorBox(message: 'No se pudieron cargar los favoritos: $error'),
      data: (List<Track> tracks) {
        if (tracks.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Marca canciones con el corazón para verlas aquí.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return Column(
          children: tracks
              .take(5)
              .map((Track track) => TrackTile(track: track, queue: tracks))
              .toList(growable: false),
        );
      },
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: Colors.redAccent)),
    );
  }
}
