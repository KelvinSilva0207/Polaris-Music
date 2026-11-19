import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/track.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/polaris_surface.dart';
import '../../player/presentation/player_providers.dart';
import '../domain/download_task.dart';
import '../domain/music_source.dart';
import '../domain/online_track.dart';
import 'online_music_providers.dart';
import 'source_settings_dialog.dart';
import 'source_status_ui.dart';

/// Exploración de música online y descargas a la biblioteca local.
///
/// Consulta varias fuentes de forma independiente: Audius y SoundCloud pueden
/// transmitir y descargar audio; Spotify aporta metadatos y Tidal expone su
/// estado. Las pistas reproducibles se comportan como locales en el
/// reproductor y las descargas se registran en la biblioteca.
class OnlineMusicScreen extends ConsumerStatefulWidget {
  const OnlineMusicScreen({super.key});

  @override
  ConsumerState<OnlineMusicScreen> createState() => _OnlineMusicScreenState();
}

class _OnlineMusicScreenState extends ConsumerState<OnlineMusicScreen> {
  final TextEditingController _search = TextEditingController();
  String? _resolvingId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _can(
    OnlineTrack track,
    bool Function(MusicSourceProvider provider) test,
  ) {
    final MusicSourceId? id = MusicSourceIdX.fromExternalId(track.externalId);
    if (id == null) return false;
    final MusicSourceProvider? provider = ref
        .read(musicSourceCatalogProvider)
        .providerFor(id);
    return provider != null && test(provider);
  }

  Future<void> _play(OnlineTrack track) async {
    if (_resolvingId != null) return;
    if (!_can(track, (MusicSourceProvider provider) => provider.canStream)) {
      final String? link = track.permalink;
      if (link != null) {
        try {
          if (await launchUrl(
            Uri.parse(link),
            mode: LaunchMode.externalApplication,
          )) {
            return;
          }
        } on FormatException {
          // Enlace malformado: se informa igual que si no existiera.
        }
      }
      _notice(
        'Esta fuente solo ofrece metadatos y no se pudo abrir el enlace.',
      );
      return;
    }
    setState(() => _resolvingId = track.externalId);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final Track playable = await ref.read(streamTrackUseCaseProvider)(track);
      if (!mounted) return;
      await ref.read(playerControllerProvider.notifier).playTrack(playable);
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo reproducir: $error')),
      );
    } finally {
      if (mounted) setState(() => _resolvingId = null);
    }
  }

  /// Resuelve la URL de streaming y la inserta en la cola del reproductor.
  Future<void> _addToQueue(OnlineTrack track, {bool next = false}) async {
    if (_resolvingId != null) return;
    if (!_can(track, (MusicSourceProvider provider) => provider.canStream)) {
      _notice('Esta fuente no permite añadir pistas a la cola.');
      return;
    }
    setState(() => _resolvingId = track.externalId);
    try {
      final Track playable = await ref.read(streamTrackUseCaseProvider)(track);
      if (!mounted) return;
      final controller = ref.read(playerControllerProvider.notifier);
      if (next) {
        await controller.addAfterCurrent(playable);
      } else {
        await controller.addToQueue(playable);
      }
      if (mounted) {
        _notice(
          next
              ? '“${track.title}” se reproducirá a continuación.'
              : '“${track.title}” añadida a la cola.',
        );
      }
    } catch (error) {
      if (mounted) {
        _notice('No se pudo añadir a la cola: $error');
      }
    } finally {
      if (mounted) setState(() => _resolvingId = null);
    }
  }

  void _download(OnlineTrack track) {
    if (!_can(track, (MusicSourceProvider provider) => provider.canDownload)) {
      _notice('Esta fuente no permite descargas.');
      return;
    }
    ref.read(downloadTrackUseCaseProvider)(track);
    _notice('“${track.title}” añadida a la cola de descargas.');
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final OnlineSearchState state = ref.watch(onlineSearchProvider);
    final Set<String> downloaded =
        ref.watch(downloadedIdsProvider).valueOrNull ?? const <String>{};
    final List<DownloadTask> downloads =
        ref.watch(downloadTasksProvider).valueOrNull ?? const <DownloadTask>[];
    final List<DownloadTask> pending = downloads
        .where((DownloadTask task) => !task.isCompleted)
        .toList(growable: false);
    final MusicSourceId? filter = state.sourceFilter;
    final SourceResult? filteredIssue = filter == null
        ? null
        : state.resultFor(filter);

    DownloadTask? taskFor(String externalId) {
      for (final DownloadTask task in downloads) {
        if (task.externalId == externalId) return task;
      }
      return null;
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 150),
        children: <Widget>[
          _OnlineHeader(
            onRefresh: () {
              ref.read(onlineSearchProvider.notifier).retryCurrent();
            },
            onConfigure: () => showSourcesDialog(context),
          ),
          const SizedBox(height: 18),
          _SearchField(
            controller: _search,
            loading: state.loading,
            onChanged: (String value) {
              ref.read(onlineSearchProvider.notifier).onQueryChanged(value);
            },
            onClear: () {
              _search.clear();
              ref.read(onlineSearchProvider.notifier).onQueryChanged('');
            },
          ),
          const SizedBox(height: 14),
          _SourceFilterBar(
            providers: ref.watch(musicSourceCatalogProvider).providers,
            selected: state.sourceFilter,
            statuses: state.sourceStatuses,
            onChanged: (MusicSourceId? source) {
              ref.read(onlineSearchProvider.notifier).setSourceFilter(source);
            },
          ),
          if (filteredIssue != null &&
              SourceStatusUi.isActionable(filteredIssue.status.issue))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _SourceIssueBanner(
                status: filteredIssue.status,
                onConfigure: () => showSourcesDialog(context, initial: filter),
                onRetry: () {
                  ref.read(onlineSearchProvider.notifier).retryCurrent();
                },
              ),
            ),
          if (pending.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _DownloadsPanel(
              tasks: pending,
              onCancel: (String id) {
                ref.read(downloadManagerProvider).cancel(id);
              },
              onRetry: (OnlineTrack track) {
                ref.read(downloadManagerProvider).retry(track);
              },
              onClear: () {
                ref.read(downloadManagerProvider).clearFinished();
              },
            ),
          ],
          const SizedBox(height: 22),
          _ResultsHeader(state: state),
          const SizedBox(height: 10),
          if (state.error != null)
            _ErrorState(
              message: state.error!,
              onRetry: () {
                ref.read(onlineSearchProvider.notifier).retryCurrent();
              },
            )
          else if (state.loading && state.tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.isEmpty)
            EmptyState(
              icon: Icons.cloud_off_rounded,
              title: state.isTrending
                  ? 'Sin tendencias por ahora'
                  : 'Sin resultados',
              message: state.isTrending
                  ? 'No se pudieron cargar las pistas populares. Prueba a '
                        'actualizar en unos segundos.'
                  : 'No encontramos pistas para “${state.query}”. Prueba con '
                        'otro título o artista.',
            )
          else
            ...state.tracks.map(
              (OnlineTrack track) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OnlineTrackTile(
                  track: track,
                  downloaded: downloaded.contains(track.externalId),
                  resolving: _resolvingId == track.externalId,
                  canPlay: _can(track, (MusicSourceProvider p) => p.canStream),
                  canDownload: _can(
                    track,
                    (MusicSourceProvider p) => p.canDownload,
                  ),
                  task: taskFor(track.externalId),
                  onPlay: () => _play(track),
                  onAddQueue: () => _addToQueue(track),
                  onPlayNext: () => _addToQueue(track, next: true),
                  onDownload: () => _download(track),
                  onCancelDownload: () {
                    ref.read(downloadManagerProvider).cancel(track.externalId);
                  },
                  onRetryDownload: () {
                    ref.read(downloadManagerProvider).retry(track);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OnlineHeader extends StatelessWidget {
  const _OnlineHeader({required this.onRefresh, required this.onConfigure});

  final VoidCallback onRefresh;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                tokens.accent.withValues(alpha: 0.85),
                tokens.accent.withValues(alpha: 0.30),
              ],
            ),
          ),
          child: const Icon(Icons.graphic_eq_rounded, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Música online',
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Audius y SoundCloud permiten streaming; Spotify aporta '
                'metadatos. Configura tus tokens y filtra por fuente.',
                style: text.bodySmall?.copyWith(color: Colors.white60),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Configurar fuentes',
          onPressed: onConfigure,
          icon: const Icon(Icons.tune_rounded),
        ),
        IconButton(
          tooltip: 'Actualizar',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.loading,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool loading;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Busca por título, artista o género…',
        prefixIcon: Icon(Icons.search_rounded, color: tokens.accent),
        suffixIcon: controller.text.isEmpty
            ? (loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null)
            : IconButton(
                tooltip: 'Borrar búsqueda',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: tokens.panelColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.panelBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.panelBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.accent.withValues(alpha: 0.8)),
        ),
      ),
    );
  }
}

class _SourceFilterBar extends StatelessWidget {
  const _SourceFilterBar({
    required this.providers,
    required this.selected,
    required this.statuses,
    required this.onChanged,
  });

  final List<MusicSourceProvider> providers;
  final MusicSourceId? selected;
  final Map<MusicSourceId, MusicSourceStatus> statuses;
  final ValueChanged<MusicSourceId?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          ChoiceChip(
            label: const Text('Todas'),
            selected: selected == null,
            onSelected: (_) => onChanged(null),
          ),
          const SizedBox(width: 8),
          for (final MusicSourceProvider provider in providers)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SourceStatusUi.color(
                      statuses[provider.id] ?? provider.status,
                    ),
                  ),
                ),
                label: Text(provider.id.label),
                selected: selected == provider.id,
                tooltip: SourceStatusUi.explain(
                  (statuses[provider.id] ?? provider.status).issue,
                ),
                onSelected: (_) => onChanged(provider.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceIssueBanner extends StatelessWidget {
  const _SourceIssueBanner({
    required this.status,
    required this.onConfigure,
    required this.onRetry,
  });

  final MusicSourceStatus status;
  final VoidCallback onConfigure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Color color = SourceStatusUi.color(status);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline_rounded, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status.detail.isNotEmpty
                  ? status.detail
                  : SourceStatusUi.explain(status.issue),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
          TextButton(onPressed: onConfigure, child: const Text('Ajustes')),
          IconButton(
            tooltip: 'Reintentar',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.state});

  final OnlineSearchState state;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final String title = state.isTrending
        ? 'Tendencias'
        : 'Resultados para “${state.query}”';
    return Row(
      children: <Widget>[
        Icon(
          state.isTrending ? Icons.trending_up_rounded : Icons.search_rounded,
          size: 18,
          color: tokens.accent,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        Text(
          '${state.tracks.length} pistas',
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
      ],
    );
  }
}

class _OnlineTrackTile extends StatelessWidget {
  const _OnlineTrackTile({
    required this.track,
    required this.downloaded,
    required this.resolving,
    required this.canPlay,
    required this.canDownload,
    required this.task,
    required this.onPlay,
    required this.onAddQueue,
    required this.onPlayNext,
    required this.onDownload,
    required this.onCancelDownload,
    required this.onRetryDownload,
  });

  final OnlineTrack track;
  final bool downloaded;
  final bool resolving;
  final bool canPlay;
  final bool canDownload;
  final DownloadTask? task;
  final VoidCallback onPlay;
  final VoidCallback onAddQueue;
  final VoidCallback onPlayNext;
  final VoidCallback onDownload;
  final VoidCallback onCancelDownload;
  final VoidCallback onRetryDownload;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final DownloadTask? current = task;
    final bool downloading =
        current?.status == DownloadStatus.downloading ||
        current?.status == DownloadStatus.queued;
    final String subtitle = track.playCount > 0
        ? '${track.artist} · ${Formatters.count(track.playCount)} reproducciones'
        : track.artist;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: resolving || !canPlay ? null : onPlay,
        child: Ink(
          decoration: tokens.panelDecoration(radius: 14, elevated: false),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: <Widget>[
                _OnlineArtwork(url: track.artworkUrl, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _SourceBadge(label: track.sourceLabel),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  Formatters.duration(track.duration),
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
                const SizedBox(width: 4),
                if (resolving)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    tooltip: canPlay
                        ? 'Reproducir en streaming'
                        : 'Abrir en la app original',
                    onPressed: onPlay,
                    icon: canPlay
                        ? Icon(
                            Icons.play_circle_fill_rounded,
                            color: tokens.accent,
                            size: 28,
                          )
                        : const Icon(
                            Icons.open_in_new_rounded,
                            color: Colors.white38,
                            size: 24,
                          ),
                  ),
                if (canPlay)
                  PopupMenuButton<String>(
                    tooltip: 'Añadir a la cola',
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white38,
                      size: 20,
                    ),
                    onSelected: (String value) {
                      switch (value) {
                        case 'queue':
                          onAddQueue();
                        case 'play-next':
                          onPlayNext();
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'queue',
                            child: Text('Añadir a la cola'),
                          ),
                          PopupMenuItem<String>(
                            value: 'play-next',
                            child: Text('Reproducir a continuación'),
                          ),
                        ],
                  ),
                if (canDownload)
                  _DownloadAction(
                    downloaded: downloaded,
                    task: current,
                    busy: downloading,
                    onDownload: onDownload,
                    onCancel: onCancelDownload,
                    onRetry: onRetryDownload,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadAction extends StatelessWidget {
  const _DownloadAction({
    required this.downloaded,
    required this.task,
    required this.busy,
    required this.onDownload,
    required this.onCancel,
    required this.onRetry,
  });

  final bool downloaded;
  final DownloadTask? task;
  final bool busy;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;

    if (downloaded || task?.status == DownloadStatus.completed) {
      return IconButton(
        tooltip: 'Ya está en tu biblioteca',
        onPressed: null,
        icon: Icon(
          Icons.cloud_done_rounded,
          color: tokens.accent.withValues(alpha: 0.9),
        ),
      );
    }

    if (busy) {
      final double progress = task?.progress ?? 0;
      return IconButton(
        tooltip: task?.status == DownloadStatus.queued
            ? 'En cola · toca para cancelar'
            : 'Descargando ${(progress * 100).round()} % · toca para cancelar',
        onPressed: onCancel,
        icon: SizedBox(
          width: 24,
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CircularProgressIndicator(
                value: task?.status == DownloadStatus.queued ? null : progress,
                strokeWidth: 2.4,
                color: tokens.accent,
                backgroundColor: Colors.white12,
              ),
              Icon(
                Icons.close_rounded,
                size: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      );
    }

    if (task?.status == DownloadStatus.failed) {
      return IconButton(
        tooltip: 'Error al descargar · reintentar',
        onPressed: onRetry,
        icon: const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
      );
    }

    if (task?.status == DownloadStatus.canceled) {
      return IconButton(
        tooltip: 'Descarga cancelada · reintentar',
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
      );
    }

    return IconButton(
      tooltip: 'Descargar a mi biblioteca',
      onPressed: onDownload,
      icon: const Icon(Icons.cloud_download_outlined),
    );
  }
}

class _OnlineArtwork extends StatelessWidget {
  const _OnlineArtwork({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final Widget fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            tokens.accent.withValues(alpha: 0.62),
            tokens.accent.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.4,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );

    final String? source = url;
    if (source == null || source.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Image.network(
        source,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) => fallback,
        loadingBuilder: (
          BuildContext context,
          Widget child,
          ImageChunkEvent? progress,
        ) => progress == null ? child : fallback,
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: tokens.accent.withValues(alpha: 0.14),
        border: Border.all(color: tokens.accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.cloud_queue_rounded,
            size: 10,
            color: tokens.accent.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: tokens.accent.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadsPanel extends StatelessWidget {
  const _DownloadsPanel({
    required this.tasks,
    required this.onCancel,
    required this.onRetry,
    required this.onClear,
  });

  final List<DownloadTask> tasks;
  final ValueChanged<String> onCancel;
  final ValueChanged<OnlineTrack> onRetry;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    return PolarisSurface(
      borderRadius: 16,
      glowColor: tokens.accent,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.downloading_rounded, size: 18, color: tokens.accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Descargas',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(onPressed: onClear, child: const Text('Limpiar')),
            ],
          ),
          const SizedBox(height: 4),
          ...tasks.map(
            (DownloadTask task) => _DownloadRow(
              task: task,
              onCancel: () => onCancel(task.externalId),
              onRetry: () => onRetry(task.track),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({
    required this.task,
    required this.onCancel,
    required this.onRetry,
  });

  final DownloadTask task;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final bool failed = task.status == DownloadStatus.failed;
    final bool canceled = task.status == DownloadStatus.canceled;
    final bool retryable = failed || canceled;
    final String status = switch (task.status) {
      DownloadStatus.queued => 'En cola',
      DownloadStatus.downloading => '${(task.progress * 100).round()} %',
      DownloadStatus.completed => 'Completada',
      DownloadStatus.failed => 'Error',
      DownloadStatus.canceled => 'Cancelada',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Icon(
            failed ? Icons.error_outline_rounded : Icons.music_note_rounded,
            size: 16,
            color: failed ? Colors.redAccent : tokens.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${task.track.artist} · ${task.track.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: retryable || task.status == DownloadStatus.queued
                        ? null
                        : task.progress,
                    minHeight: 3,
                    backgroundColor: Colors.white12,
                    color: failed ? Colors.redAccent : tokens.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              fontSize: 10,
              color: failed ? Colors.redAccent : Colors.white54,
            ),
          ),
          IconButton(
            tooltip: retryable ? 'Reintentar' : 'Cancelar descarga',
            visualDensity: VisualDensity.compact,
            onPressed: retryable ? onRetry : onCancel,
            icon: Icon(
              retryable ? Icons.refresh_rounded : Icons.close_rounded,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.wifi_off_rounded,
      title: 'Catálogo no disponible',
      message: message,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Reintentar'),
      ),
    );
  }
}
