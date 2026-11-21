import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/track.dart';
import '../../../core/services/audio_engine_service.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/polaris_surface.dart';
import '../../player/presentation/player_providers.dart';
import '../data/source_helpers.dart';
import '../domain/download_task.dart';
import '../domain/music_source.dart';
import '../domain/online_catalog_items.dart';
import '../domain/online_track.dart';
import 'online_music_providers.dart';
import 'source_settings_dialog.dart';
import 'source_status_ui.dart';

/// Exploración de música online y descargas a la biblioteca local.
///
/// Consulta varias fuentes de forma independiente: Audius, SoundCloud y
/// YouTube Music pueden transmitir audio; Spotify y Tidal aportan metadatos y
/// se resuelven mediante un puente hacia fuentes con audio abierto. Las pistas
/// reproducibles se comportan como locales en el reproductor y las descargas se
/// registran en la biblioteca.
class OnlineMusicScreen extends ConsumerStatefulWidget {
  const OnlineMusicScreen({super.key});

  @override
  ConsumerState<OnlineMusicScreen> createState() => _OnlineMusicScreenState();
}

class _OnlineMusicScreenState extends ConsumerState<OnlineMusicScreen> {
  final TextEditingController _search = TextEditingController();
  String? _resolvingId;
  bool _bulkPlaying = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// El repositorio decide si una pista se puede reproducir: las fuentes de
  /// metadatos (Spotify/Tidal) cuentan con el puente hacia un catálogo con
  /// audio abierto, y ese detalle se comunica al usuario al resolver.
  bool _canPlay(OnlineTrack track) =>
      ref.read(onlineCatalogRepositoryProvider).canStreamTrack(track);

  bool _canDownload(OnlineTrack track) =>
      ref.read(onlineCatalogRepositoryProvider).canDownloadTrack(track);

  Future<bool> _openUrl(String? link) async {
    if (link == null || link.isEmpty) return false;
    try {
      return await launchUrl(
        Uri.parse(link),
        mode: LaunchMode.externalApplication,
      );
    } on FormatException {
      return false;
    }
  }

  Future<bool> _openOriginal(OnlineTrack track) => _openUrl(track.permalink);

  Future<void> _play(OnlineTrack track) async {
    if (_resolvingId != null || _bulkPlaying) return;
    if (!_canPlay(track)) {
      if (await _openOriginal(track)) return;
      _notice('Esta fuente no ofrece audio reproducible.');
      return;
    }
    setState(() => _resolvingId = track.externalId);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final Track playable = await ref.read(streamTrackUseCaseProvider)(track);
      if (!mounted) return;
      await ref.read(playerControllerProvider.notifier).playTrack(playable);
      final String label = playable.sourceLabel ?? '';
      if (label.contains('→')) {
        _notice('Audio resuelto desde $label.');
      }
    } catch (error) {
      if (!mounted) return;
      if (error is MusicSourceException &&
          error.issue == MusicSourceIssue.unsupported) {
        if (await _openOriginal(track)) {
          _notice('$error Se abrió el enlace original.');
          return;
        }
      }
      messenger.showSnackBar(
        _errorSnack(
          'No se pudo reproducir: '
          '${AudioEngineService.sanitizePlaybackError(error)}',
        ),
      );
    } finally {
      if (mounted) setState(() => _resolvingId = null);
    }
  }

  /// Resuelve la URL de streaming y la inserta en la cola del reproductor.
  Future<void> _addToQueue(OnlineTrack track, {bool next = false}) async {
    if (_resolvingId != null || _bulkPlaying) return;
    if (!_canPlay(track)) {
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
    if (!_canDownload(track)) {
      _notice('Esta fuente no permite descargas.');
      return;
    }
    ref.read(downloadTrackUseCaseProvider)(track);
    _notice('“${track.title}” añadida a la cola de descargas.');
  }

  /// Resuelve y reproduce todas las pistas de la colección abierta en orden.
  /// Se hace en secuencia para no saturar los endpoints anónimos.
  Future<void> _playAll() async {
    if (_bulkPlaying || _resolvingId != null) return;
    final List<OnlineTrack> candidates = ref
        .read(onlineSearchProvider)
        .tracks
        .where(_canPlay)
        .toList(growable: false);
    if (candidates.isEmpty) {
      _notice('No hay pistas reproducibles en esta colección.');
      return;
    }
    setState(() => _bulkPlaying = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final List<Track> resolved = <Track>[];
      for (final OnlineTrack item in candidates) {
        resolved.add(await ref.read(streamTrackUseCaseProvider)(item));
      }
      if (!mounted) return;
      await ref
          .read(playerControllerProvider.notifier)
          .playQueue(resolved, startIndex: 0);
      if (mounted) _notice('${resolved.length} pistas en la cola.');
    } catch (error) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _bulkPlaying = false);
    }
  }

  void _downloadAll() {
    final Set<String> downloaded =
        ref.read(downloadedIdsProvider).valueOrNull ?? const <String>{};
    final downloadUseCase = ref.read(downloadTrackUseCaseProvider);
    final List<OnlineTrack> targets = ref
        .read(onlineSearchProvider)
        .tracks
        .where(
          (OnlineTrack item) =>
              _canDownload(item) && !downloaded.contains(item.externalId),
        )
        .toList(growable: false);
    if (targets.isEmpty) {
      _notice(
        downloaded.isEmpty
            ? 'No hay pistas descargables aquí.'
            : 'Todas las pistas descargables ya están en tu biblioteca.',
      );
      return;
    }
    for (final OnlineTrack item in targets) {
      downloadUseCase(item);
    }
    _notice('${targets.length} pistas añadidas a la cola de descargas.');
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  /// Aviso de fallo con alto contraste: nunca muestra la URL del stream.
  SnackBar _errorSnack(String message) => SnackBar(
    backgroundColor: const Color(0xFF8E1B24),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 4),
    content: Row(
      children: <Widget>[
        Icon(Icons.error_outline_rounded, color: context.ink, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: context.ink, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

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
    final OnlineCollectionRef? collection = state.openedCollection;
    final bool inCollection = collection != null;
    final bool showCollections =
        !inCollection && state.resultType != OnlineSearchType.songs;

    DownloadTask? taskFor(String externalId) {
      for (final DownloadTask task in downloads) {
        if (task.externalId == externalId) return task;
      }
      return null;
    }

    final List<SourceResult> issues = filter == null
        ? state.results
              .where((SourceResult item) => !item.ok)
              .take(3)
              .toList(growable: false)
        : state.results
              .where((SourceResult item) => item.source == filter && !item.ok)
              .toList(growable: false);

    // La cabecera es pequeña y estable; las pistas se construyen bajo demanda
    // para no montar (y decodificar) cientos de carátulas de una sola vez.
    final List<Widget> header = <Widget>[
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
      if (inCollection)
        _CollectionHeader(
          collection: collection,
          trackCount: state.tracks.length,
          loading: state.collectionLoading,
          bulkPlaying: _bulkPlaying,
          onBack: () {
            ref.read(onlineSearchProvider.notifier).closeCollection();
          },
          onPlayAll: _playAll,
          onDownloadAll: _downloadAll,
          onOpenOriginal: () => _openUrl(collection.permalink),
        )
      else ...<Widget>[
        _ResultTypeBar(
          selected: state.resultType,
          onChanged: (OnlineSearchType type) {
            ref.read(onlineSearchProvider.notifier).setResultType(type);
          },
        ),
        const SizedBox(height: 12),
        _SourceFilterBar(
          providers: ref.watch(musicSourceCatalogProvider).providers,
          selected: state.sourceFilter,
          statuses: state.sourceStatuses,
          onChanged: (MusicSourceId? source) {
            ref.read(onlineSearchProvider.notifier).setSourceFilter(source);
          },
        ),
        for (final SourceResult issue in issues)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _SourceIssueBanner(
              label: issue.source.label,
              status: issue.status,
              onConfigure: () =>
                  showSourcesDialog(context, initial: issue.source),
              onRetry: () {
                ref.read(onlineSearchProvider.notifier).retryCurrent();
              },
            ),
          ),
      ],
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
      if (showCollections && state.collections.isNotEmpty) ...<Widget>[
        for (final OnlineCollectionRef item in state.collections)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CollectionTile(
              collection: item,
              onOpen: () {
                ref.read(onlineSearchProvider.notifier).openCollection(item);
              },
              onOpenOriginal: () => _openUrl(item.permalink),
            ),
          ),
        const SizedBox(height: 8),
      ],
    ];

    final Widget? statusWidget = state.collectionError != null
        ? _ErrorState(
            message: state.collectionError!,
            onRetry: collection == null
                ? () => ref.read(onlineSearchProvider.notifier).retryCurrent()
                : () => ref
                      .read(onlineSearchProvider.notifier)
                      .openCollection(collection),
          )
        : state.error != null
        ? _ErrorState(
            message: state.error!,
            onRetry: () {
              ref.read(onlineSearchProvider.notifier).retryCurrent();
            },
          )
        : state.collectionLoading || (state.loading && state.tracks.isEmpty)
        ? Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(child: CircularProgressIndicator()),
          )
        : state.isEmpty
        ? EmptyState(
            icon: Icons.cloud_off_rounded,
            title: inCollection
                ? 'Colección vacía'
                : state.isTrending
                ? 'Sin tendencias por ahora'
                : 'Sin resultados',
            message: _emptyMessage(state, issues),
          )
        : null;

    Widget trackTile(OnlineTrack track) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _OnlineTrackTile(
          track: track,
          downloaded: downloaded.contains(track.externalId),
          resolving: _resolvingId == track.externalId,
          canPlay: _canPlay(track),
          canDownload: _canDownload(track),
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
      );
    }

    return SafeArea(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 150),
        itemCount:
            header.length +
            (statusWidget == null ? 0 : 1) +
            state.tracks.length,
        itemBuilder: (BuildContext context, int index) {
          if (index < header.length) return header[index];
          int offset = index - header.length;
          if (statusWidget != null) {
            if (offset == 0) return statusWidget;
            offset--;
          }
          return trackTile(state.tracks[offset]);
        },
      ),
    );
  }

  String _emptyMessage(OnlineSearchState state, List<SourceResult> issues) {
    if (state.openedCollection != null) {
      return 'Esta colección no tiene pistas disponibles ahora mismo. '
          'Prueba con otra o vuelve a intentarlo en unos segundos.';
    }
    if (state.isTrending) {
      return 'No se pudieron cargar las pistas populares. Prueba a actualizar '
          'en unos segundos.';
    }
    if (state.query.trim().isEmpty) {
      return 'Escribe un título, artista o álbum para buscar '
          '${state.resultType.label.toLowerCase()}.';
    }
    final String base = state.resultType == OnlineSearchType.songs
        ? 'No encontramos pistas para “${state.query}”. Prueba con otro título '
              'o artista.'
        : 'No encontramos ${state.resultType.label.toLowerCase()} para '
              '“${state.query}”. Prueba con otro término.';
    if (issues.isEmpty) return base;
    final String details = issues
        .map(
          (SourceResult item) => item.status.detail.isNotEmpty
              ? item.status.detail
              : SourceStatusUi.explain(item.status.issue),
        )
        .join(' ');
    return '$base $details';
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
          child: Icon(Icons.graphic_eq_rounded, color: context.ink),
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
                  color: context.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Audius y YouTube Music funcionan sin cuenta. SoundCloud, '
                'Spotify y Tidal necesitan un token en Configurar fuentes; '
                'Spotify y Tidal solo aportan metadatos y el audio se busca en '
                'fuentes abiertas.',
                style: text.bodySmall?.copyWith(color: context.inkAlpha(0.60)),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Configurar fuentes',
          onPressed: onConfigure,
          icon: Icon(Icons.tune_rounded),
        ),
        IconButton(
          tooltip: 'Actualizar',
          onPressed: onRefresh,
          icon: Icon(Icons.refresh_rounded),
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
                  ? Padding(
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
                icon: Icon(Icons.close_rounded),
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

/// Filtros Canciones / Álbumes / Artistas / Playlists.
class _ResultTypeBar extends StatelessWidget {
  const _ResultTypeBar({required this.selected, required this.onChanged});

  final OnlineSearchType selected;
  final ValueChanged<OnlineSearchType> onChanged;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final OnlineSearchType type
              in OnlineSearchType.values) ...<Widget>[
            ChoiceChip(
              avatar: Icon(
                type.icon,
                size: 14,
                color: selected == type
                    ? tokens.accent
                    : context.inkAlpha(0.54),
              ),
              label: Text(type.label),
              selected: selected == type,
              onSelected: (_) => onChanged(type),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Cabecera de una colección abierta con acciones colectivas.
class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({
    required this.collection,
    required this.trackCount,
    required this.loading,
    required this.bulkPlaying,
    required this.onBack,
    required this.onPlayAll,
    required this.onDownloadAll,
    required this.onOpenOriginal,
  });

  final OnlineCollectionRef collection;
  final int trackCount;
  final bool loading;
  final bool bulkPlaying;
  final VoidCallback onBack;
  final VoidCallback onPlayAll;
  final VoidCallback onDownloadAll;
  final VoidCallback onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final bool busy = loading || bulkPlaying;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 10, 12),
      decoration: tokens.panelDecoration(radius: 16, elevated: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Volver a los resultados',
                onPressed: onBack,
                icon: Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      collection.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      collection.subtitle.isEmpty
                          ? '${collection.source.label} · ${collection.kind.label}'
                          : '${collection.subtitle} · ${collection.source.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.inkAlpha(0.54),
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (collection.permalink != null)
                IconButton(
                  tooltip: 'Abrir en ${collection.source.label}',
                  onPressed: onOpenOriginal,
                  icon: Icon(Icons.open_in_new_rounded, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Flexible(
                child: FilledButton.icon(
                  onPressed: busy || trackCount == 0 ? null : onPlayAll,
                  icon: Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text('Reproducir todo'),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: OutlinedButton.icon(
                  onPressed: busy || trackCount == 0 ? null : onDownloadAll,
                  icon: Icon(Icons.cloud_download_outlined, size: 18),
                  label: Text('Descargar todo'),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$trackCount pistas',
                style: TextStyle(fontSize: 11, color: context.inkAlpha(0.54)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fila de álbum, artista o playlist devuelta por la búsqueda tipada.
class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.collection,
    required this.onOpen,
    required this.onOpenOriginal,
  });

  final OnlineCollectionRef collection;
  final VoidCallback onOpen;
  final VoidCallback onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final String count = collection.trackCount > 0
        ? '${collection.trackCount} pistas'
        : 'Ver contenido';
    final String subtitle = collection.subtitle.isEmpty
        ? count
        : '${collection.subtitle} · $count';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Ink(
          decoration: tokens.panelDecoration(radius: 14, elevated: false),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: <Widget>[
                _OnlineArtwork(url: collection.artworkUrl, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        collection.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.inkAlpha(0.54),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _SourceBadge(label: collection.source.label),
                        ],
                      ),
                    ],
                  ),
                ),
                if (collection.permalink != null)
                  IconButton(
                    tooltip: 'Abrir en ${collection.source.label}',
                    onPressed: onOpenOriginal,
                    icon: Icon(
                      Icons.open_in_new_rounded,
                      size: 17,
                      color: context.inkAlpha(0.38),
                    ),
                  ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.inkAlpha(0.38),
                ),
              ],
            ),
          ),
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
            label: Text('Todas'),
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
                      context,
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
    required this.label,
    required this.status,
    required this.onConfigure,
    required this.onRetry,
  });

  final String label;
  final MusicSourceStatus status;
  final VoidCallback onConfigure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Color color = SourceStatusUi.color(status, context);
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
              '$label: ${status.detail.isNotEmpty ? status.detail : SourceStatusUi.explain(status.issue)}',
              style: TextStyle(fontSize: 12, color: context.inkAlpha(0.70)),
            ),
          ),
          TextButton(onPressed: onConfigure, child: Text('Configurar fuentes')),
          IconButton(
            tooltip: 'Reintentar',
            onPressed: onRetry,
            icon: Icon(Icons.refresh_rounded, size: 18),
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
    final bool inCollection = state.openedCollection != null;
    final bool showCollections =
        !inCollection && state.resultType != OnlineSearchType.songs;
    final String title = inCollection
        ? 'Colección: ${state.openedCollection!.title}'
        : state.isTrending
        ? 'Tendencias'
        : 'Resultados para “${state.query}”';
    final int count = showCollections
        ? state.collections.length
        : state.tracks.length;
    final String unit = showCollections ? 'resultados' : 'pistas';
    return Row(
      children: <Widget>[
        Icon(
          inCollection
              ? state.openedCollection!.kind.icon
              : state.isTrending
              ? Icons.trending_up_rounded
              : Icons.search_rounded,
          size: 18,
          color: tokens.accent,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        Text(
          '$count $unit',
          style: TextStyle(fontSize: 11, color: context.inkAlpha(0.54)),
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
                        style: TextStyle(
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
                              style: TextStyle(
                                fontSize: 11,
                                color: context.inkAlpha(0.54),
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
                  style: TextStyle(fontSize: 11, color: context.inkAlpha(0.38)),
                ),
                const SizedBox(width: 4),
                if (resolving)
                  Padding(
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
                        : Icon(
                            Icons.open_in_new_rounded,
                            color: context.inkAlpha(0.38),
                            size: 24,
                          ),
                  ),
                if (canPlay)
                  PopupMenuButton<String>(
                    tooltip: 'Añadir a la cola',
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: context.inkAlpha(0.38),
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
      final bool indeterminate = task?.indeterminate ?? true;
      return IconButton(
        tooltip: task?.status == DownloadStatus.queued
            ? 'En cola · toca para cancelar'
            : indeterminate
            ? 'Descargando… toca para cancelar'
            : 'Descargando ${(progress * 100).round()} % · toca para cancelar',
        onPressed: onCancel,
        icon: SizedBox(
          width: 24,
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CircularProgressIndicator(
                value: task?.status == DownloadStatus.queued || indeterminate
                    ? null
                    : progress,
                strokeWidth: 2.4,
                color: tokens.accent,
                backgroundColor: context.inkAlpha(0.12),
              ),
              Icon(Icons.close_rounded, size: 12, color: context.inkAlpha(0.8)),
            ],
          ),
        ),
      );
    }

    if (task?.status == DownloadStatus.failed) {
      final String detail = task?.error?.trim() ?? '';
      return IconButton(
        tooltip: detail.isEmpty
            ? 'Error al descargar · reintentar'
            : 'Error al descargar: $detail · reintentar',
        onPressed: onRetry,
        icon: Icon(Icons.error_outline_rounded, color: Colors.redAccent),
      );
    }

    if (task?.status == DownloadStatus.canceled) {
      return IconButton(
        tooltip: 'Descarga cancelada · reintentar',
        onPressed: onRetry,
        icon: Icon(Icons.refresh_rounded),
      );
    }

    return IconButton(
      tooltip: 'Descargar a mi biblioteca',
      onPressed: onDownload,
      icon: Icon(Icons.cloud_download_outlined),
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
        color: context.inkAlpha(0.85),
      ),
    );

    final String? source = url;
    if (source == null || source.isEmpty) return fallback;

    final int decodeSize = (size * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(24, 160);
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Image.network(
        source,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: decodeSize,
        cacheHeight: decodeSize,
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
              TextButton(onPressed: onClear, child: Text('Limpiar')),
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
    final bool indeterminate = task.indeterminate;
    final String status = switch (task.status) {
      DownloadStatus.queued => 'En cola',
      DownloadStatus.downloading =>
        indeterminate ? 'Descargando…' : '${(task.progress * 100).round()} %',
      DownloadStatus.completed => 'Completada',
      DownloadStatus.failed => 'Error',
      DownloadStatus.canceled => 'Cancelada',
    };
    final String? error = failed ? task.error?.trim() : null;

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
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:
                        retryable ||
                            task.status == DownloadStatus.queued ||
                            indeterminate
                        ? null
                        : task.progress,
                    minHeight: 3,
                    backgroundColor: context.inkAlpha(0.12),
                    color: failed ? Colors.redAccent : tokens.accent,
                  ),
                ),
                if (error != null && error.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    error,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              fontSize: 10,
              color: failed ? Colors.redAccent : context.inkAlpha(0.54),
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
        icon: Icon(Icons.refresh_rounded),
        label: Text('Reintentar'),
      ),
    );
  }
}
