import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/playback_state.dart';
import '../../../core/models/track.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/polaris_surface.dart';
import '../../library/presentation/library_providers.dart';
import '../../lyrics/presentation/lyrics_panel.dart';
import '../domain/player_controller.dart';
import 'player_providers.dart';

/// Pantalla de reproducción dinámica.
///
/// Toda la composición lee la [AppThemeConfig] activa: estilo de tarjeta,
/// forma de carátula, tipo de progreso y paleta. Cambiar de tema desde
/// Ajustes → Personalización se refleja aquí al instante.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  int _panelTab = 0;

  @override
  Widget build(BuildContext context) {
    final PlayerUiState ui = ref.watch(playerControllerProvider);
    final AppThemeConfig config = ref.watch(themeConfigProvider);
    final Track? track = ui.track;

    final AsyncValue<Color>? paletteAsync = config.usesDynamicPalette
        ? ref.watch(artworkAccentProvider(track?.artworkPath))
        : null;
    final Color accent = paletteAsync?.valueOrNull ?? config.accent;

    if (track == null) {
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _DynamicBackdrop(config: config, accent: accent),
          const EmptyState(
            icon: Icons.play_circle_outline_rounded,
            title: 'Nada en reproducción',
            message:
                'Elige una canción de tu biblioteca o pulsa “Reproducir todo” '
                'en los recomendados para empezar.',
          ),
        ],
      );
    }

    final PlayerController controller = ref.read(
      playerControllerProvider.notifier,
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _DynamicBackdrop(config: config, accent: accent),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= 980;
            if (wide) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        child: _ArtworkStage(
                          track: track,
                          config: config,
                          accent: accent,
                          playing: ui.playback.playing,
                          progress: ui.playback.progress,
                          size: math.min(constraints.maxWidth * 0.30, 400),
                          onSeekFraction: controller.seekFraction,
                        ),
                      ),
                    ),
                    const SizedBox(width: 26),
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _PlayerColumn(
                          ui: ui,
                          track: track,
                          config: config,
                          accent: accent,
                          controller: controller,
                          panelTab: _panelTab,
                          onPanelChanged: (int value) =>
                              setState(() => _panelTab = value),
                          panelHeight: 360,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 140),
              children: <Widget>[
                Center(
                  child: _ArtworkStage(
                    track: track,
                    config: config,
                    accent: accent,
                    playing: ui.playback.playing,
                    progress: ui.playback.progress,
                    size: math.min(constraints.maxWidth - 88, 320),
                    onSeekFraction: controller.seekFraction,
                  ),
                ),
                const SizedBox(height: 20),
                _PlayerColumn(
                  ui: ui,
                  track: track,
                  config: config,
                  accent: accent,
                  controller: controller,
                  panelTab: _panelTab,
                  onPanelChanged: (int value) =>
                      setState(() => _panelTab = value),
                  panelHeight: 380,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Columna de información, progreso, controles y panel de cola/letras.
class _PlayerColumn extends StatelessWidget {
  const _PlayerColumn({
    required this.ui,
    required this.track,
    required this.config,
    required this.accent,
    required this.controller,
    required this.panelTab,
    required this.onPanelChanged,
    required this.panelHeight,
  });

  final PlayerUiState ui;
  final Track track;
  final AppThemeConfig config;
  final Color accent;
  final PlayerController controller;
  final int panelTab;
  final ValueChanged<int> onPanelChanged;
  final double panelHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _TrackHeader(track: track, accent: accent),
        const SizedBox(height: 14),
        _ProgressSection(
          config: config,
          accent: accent,
          position: ui.playback.position,
          duration: ui.playback.duration,
          onSeek: controller.seek,
          onSeekFraction: controller.seekFraction,
        ),
        const SizedBox(height: 8),
        _TransportControls(ui: ui, controller: controller, accent: accent),
        const SizedBox(height: 10),
        _VolumeRow(ui: ui, controller: controller),
        if (ui.sleepRemaining != null || ui.sleepEndsAtTrack)
          _SleepBadge(ui: ui, controller: controller),
        if (ui.playback.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              ui.playback.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        const SizedBox(height: 18),
        _MediaPanel(
          track: track,
          ui: ui,
          controller: controller,
          accent: accent,
          tab: panelTab,
          onTabChanged: onPanelChanged,
          height: panelHeight,
        ),
      ],
    );
  }
}

class _TrackHeader extends StatelessWidget {
  const _TrackHeader({required this.track, required this.accent});

  final Track track;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Row(
        key: ValueKey<int>(track.id),
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  track.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: Colors.white70),
                ),
                if (track.album.isNotEmpty && track.album != 'Desconocido')
                  Text(
                    track.album,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: Colors.white38),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: track.isFavorite
                ? 'Quitar de favoritos'
                : 'Añadir a favoritos',
            iconSize: 26,
            onPressed: () => _toggleFavorite(context),
            icon: Icon(
              track.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: track.isFavorite ? accent : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFavorite(BuildContext context) {
    // El contexto de un Consumer se obtiene en el padre; aquí usamos el
    // repositorio a través del ProviderScope del árbol.
    ProviderScope.containerOf(context)
        .read(libraryRepositoryProvider)
        .setFavorite(track.id, !track.isFavorite);
  }
}

/// Progreso según el tipo elegido. El anillo circular se dibuja alrededor de
/// la carátula, así que aquí solo muestra los tiempos y una ayuda.
class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.config,
    required this.accent,
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.onSeekFraction,
  });

  final AppThemeConfig config;
  final Color accent;
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<double> onSeekFraction;

  @override
  Widget build(BuildContext context) {
    switch (config.progressBarType) {
      case ProgressBarType.linearClassic:
        return _LinearProgress(
          position: position,
          duration: duration,
          onSeek: onSeek,
        );

      case ProgressBarType.waveform:
        return _WaveformProgress(
          position: position,
          duration: duration,
          accent: accent,
          onSeekFraction: onSeekFraction,
        );

      case ProgressBarType.circularAroundArtwork:
        return _TimeRow(position: position, duration: duration);
    }
  }
}

class _LinearProgress extends StatefulWidget {
  const _LinearProgress({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  State<_LinearProgress> createState() => _LinearProgressState();
}

class _LinearProgressState extends State<_LinearProgress> {
  double? _dragMs;

  @override
  Widget build(BuildContext context) {
    final double total = widget.duration.inMilliseconds.toDouble();
    final double current =
        _dragMs ??
        widget.position.inMilliseconds.toDouble().clamp(
          0,
          total < 0 ? 0 : total,
        );
    final Duration shown = Duration(milliseconds: current.round());

    return Column(
      children: <Widget>[
        Slider(
          value: total <= 0 ? 0 : current.clamp(0, total),
          max: total <= 0 ? 1 : total,
          onChanged: total <= 0
              ? null
              : (double value) => setState(() => _dragMs = value),
          onChangeEnd: total <= 0
              ? null
              : (double value) {
                  setState(() => _dragMs = null);
                  widget.onSeek(Duration(milliseconds: value.round()));
                },
        ),
        _TimeRow(position: shown, duration: widget.duration),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.position, required this.duration});

  final Duration position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            Formatters.duration(position),
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
          Text(
            Formatters.duration(duration),
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

/// Onda de audio determinista y clicable: no necesita datos FFT, pero se
/// mantiene estable por pista y responde al progreso real.
class _WaveformProgress extends StatelessWidget {
  const _WaveformProgress({
    required this.position,
    required this.duration,
    required this.accent,
    required this.onSeekFraction,
  });

  final Duration position;
  final Duration duration;
  final Color accent;
  final ValueChanged<double> onSeekFraction;

  @override
  Widget build(BuildContext context) {
    final double total = duration.inMilliseconds.toDouble();
    final double progress = total <= 0
        ? 0
        : (position.inMilliseconds / total).clamp(0.0, 1.0).toDouble();

    return Column(
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            void seek(Offset localPosition) {
              if (constraints.maxWidth <= 0) return;
              onSeekFraction(
                (localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0),
              );
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (TapDownDetails details) =>
                  seek(details.localPosition),
              onHorizontalDragUpdate: (DragUpdateDetails details) =>
                  seek(details.localPosition),
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: CustomPaint(
                  painter: _WaveformPainter(progress: progress, accent: accent),
                ),
              ),
            );
          },
        ),
        _TimeRow(position: position, duration: duration),
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const int bars = 64;
    final double gap = 2;
    final double barWidth = math.max(
      1.5,
      (size.width - gap * (bars - 1)) / bars,
    );
    final double playedX = size.width * progress;
    final Paint paint = Paint()..strokeCap = StrokeCap.round;

    for (int i = 0; i < bars; i++) {
      final double t = i / (bars - 1);
      // Amplitud pseudoaleatoria estable, con más energía en los graves.
      final double noise = math.sin(i * 12.9898) * 43758.5453;
      final double random = noise - noise.floorToDouble();
      final double envelope =
          (0.30 + 0.70 * math.sin(math.pi * t)) * (0.55 + 0.45 * random);
      final double height = (size.height * envelope).clamp(4, size.height);
      final double x = i * (barWidth + gap);
      final double top = (size.height - height) / 2;

      final bool played = x + barWidth <= playedX;
      paint.color = played ? accent : accent.withValues(alpha: 0.18);
      paint.strokeWidth = barWidth;
      canvas.drawLine(
        Offset(x + barWidth / 2, top),
        Offset(x + barWidth / 2, top + height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({
    required this.ui,
    required this.controller,
    required this.accent,
  });

  final PlayerUiState ui;
  final PlayerController controller;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: <Widget>[
        IconButton(
          tooltip: 'Aleatorio',
          onPressed: controller.toggleShuffle,
          icon: Icon(
            Icons.shuffle_rounded,
            color: ui.playback.shuffle ? accent : Colors.white54,
          ),
        ),
        IconButton(
          tooltip: 'Anterior',
          iconSize: 32,
          onPressed: controller.previous,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        SizedBox(
          width: 68,
          height: 68,
          child: FilledButton(
            onPressed: controller.togglePlay,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              backgroundColor: accent,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
            child: ui.playback.buffering
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.black,
                    ),
                  )
                : Icon(
                    ui.playback.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 38,
                  ),
          ),
        ),
        IconButton(
          tooltip: 'Siguiente',
          iconSize: 32,
          onPressed: controller.next,
          icon: const Icon(Icons.skip_next_rounded),
        ),
        IconButton(
          tooltip: _repeatLabel(ui.playback.repeat),
          onPressed: controller.cycleRepeat,
          icon: Icon(
            ui.playback.repeat == RepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: ui.playback.repeat == RepeatMode.off
                ? Colors.white54
                : accent,
          ),
        ),
      ],
    );
  }

  String _repeatLabel(RepeatMode mode) => switch (mode) {
    RepeatMode.off => 'Repetir: desactivado',
    RepeatMode.all => 'Repetir: toda la cola',
    RepeatMode.one => 'Repetir: una canción',
  };
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({required this.ui, required this.controller});

  final PlayerUiState ui;
  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          ui.playback.volume <= 0
              ? Icons.volume_off_rounded
              : Icons.volume_up_rounded,
          size: 20,
          color: Colors.white54,
        ),
        Expanded(
          child: Slider(
            value: ui.playback.volume.clamp(0.0, 100.0),
            max: 100,
            onChanged: controller.setVolume,
          ),
        ),
        _SpeedMenu(speed: ui.playback.speed, onChanged: controller.setSpeed),
        _SleepMenu(ui: ui, controller: controller),
      ],
    );
  }
}

class _SpeedMenu extends StatelessWidget {
  const _SpeedMenu({required this.speed, required this.onChanged});

  final double speed;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<double> values = <double>[0.5, 0.75, 1, 1.25, 1.5, 1.75, 2];
    return PopupMenuButton<double>(
      tooltip: 'Velocidad de reproducción',
      onSelected: onChanged,
      itemBuilder: (BuildContext context) => values
          .map(
            (double value) => PopupMenuItem<double>(
              value: value,
              child: Text(
                value == 1 ? 'Normal (1.0×)' : '${value.toString()}×',
              ),
            ),
          )
          .toList(growable: false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Text(
          '${speed.toStringAsFixed(speed == speed.roundToDouble() ? 1 : 2)}×',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SleepMenu extends StatelessWidget {
  const _SleepMenu({required this.ui, required this.controller});

  final PlayerUiState ui;
  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final bool active = ui.sleepRemaining != null || ui.sleepEndsAtTrack;
    return PopupMenuButton<String>(
      tooltip: 'Temporizador de sueño',
      onSelected: (String value) {
        switch (value) {
          case '15':
            controller.startSleepTimer(const Duration(minutes: 15));
          case '30':
            controller.startSleepTimer(const Duration(minutes: 30));
          case '45':
            controller.startSleepTimer(const Duration(minutes: 45));
          case '60':
            controller.startSleepTimer(const Duration(minutes: 60));
          case 'track':
            controller.sleepAtEndOfTrack();
          case 'cancel':
            controller.cancelSleepTimer();
        }
      },
      itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: '15', child: Text('15 minutos')),
        PopupMenuItem<String>(value: '30', child: Text('30 minutos')),
        PopupMenuItem<String>(value: '45', child: Text('45 minutos')),
        PopupMenuItem<String>(value: '60', child: Text('60 minutos')),
        PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'track',
          child: Text('Al terminar la pista'),
        ),
        PopupMenuItem<String>(value: 'cancel', child: Text('Cancelar')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Icon(
          active ? Icons.bedtime_rounded : Icons.bedtime_outlined,
          size: 20,
          color: active ? context.accent : Colors.white54,
        ),
      ),
    );
  }
}

class _SleepBadge extends StatelessWidget {
  const _SleepBadge({required this.ui, required this.controller});

  final PlayerUiState ui;
  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.bedtime_rounded, size: 14, color: Colors.white54),
          const SizedBox(width: 6),
          Text(
            ui.sleepEndsAtTrack
                ? 'Se pausará al terminar la pista'
                : 'Se pausará en ${Formatters.duration(ui.sleepRemaining!)}',
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
          TextButton(
            onPressed: controller.cancelSleepTimer,
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

/// Panel inferior con la cola o las letras.
class _MediaPanel extends StatelessWidget {
  const _MediaPanel({
    required this.track,
    required this.ui,
    required this.controller,
    required this.accent,
    required this.tab,
    required this.onTabChanged,
    required this.height,
  });

  final Track track;
  final PlayerUiState ui;
  final PlayerController controller;
  final Color accent;
  final int tab;
  final ValueChanged<int> onTabChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: PolarisSurface(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        borderRadius: 22,
        glowColor: accent,
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: SegmentedButton<int>(
                    segments: const <ButtonSegment<int>>[
                      ButtonSegment<int>(
                        value: 0,
                        label: Text('Cola'),
                        icon: Icon(Icons.queue_music_rounded, size: 18),
                      ),
                      ButtonSegment<int>(
                        value: 1,
                        label: Text('Letras'),
                        icon: Icon(Icons.lyrics_outlined, size: 18),
                      ),
                    ],
                    selected: <int>{tab},
                    showSelectedIcon: false,
                    onSelectionChanged: (Set<int> value) =>
                        onTabChanged(value.first),
                  ),
                ),
                if (tab == 0)
                  IconButton(
                    tooltip: 'Vaciar cola',
                    onPressed: ui.playback.queue.isEmpty
                        ? null
                        : controller.clearQueue,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: tab == 0
                  ? _QueueList(ui: ui, controller: controller, accent: accent)
                  : LyricsPanel(track: track),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList({
    required this.ui,
    required this.controller,
    required this.accent,
  });

  final PlayerUiState ui;
  final PlayerController controller;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final List<Track> queue = ui.playback.queue;
    if (queue.isEmpty) {
      return const Center(
        child: Text(
          'La cola está vacía',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: queue.length,
      itemBuilder: (BuildContext context, int index) {
        final Track track = queue[index];
        final bool current = index == ui.playback.index;
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: current ? accent.withValues(alpha: 0.12) : null,
          leading: _ArtworkImage(
            path: track.artworkPath,
            size: 38,
            shape: BoxShape.rectangle,
            radius: BorderRadius.circular(8),
            accent: accent,
          ),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
              color: current ? accent : null,
            ),
          ),
          subtitle: Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                Formatters.duration(track.duration),
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
              IconButton(
                tooltip: 'Quitar de la cola',
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () => controller.removeFromQueue(index),
              ),
            ],
          ),
          onTap: () => controller.playAt(index),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Carátula adaptativa
// ---------------------------------------------------------------------------

class _ArtworkStage extends StatelessWidget {
  const _ArtworkStage({
    required this.track,
    required this.config,
    required this.accent,
    required this.playing,
    required this.progress,
    required this.size,
    required this.onSeekFraction,
  });

  final Track track;
  final AppThemeConfig config;
  final Color accent;
  final bool playing;
  final double progress;
  final double size;
  final ValueChanged<double> onSeekFraction;

  @override
  Widget build(BuildContext context) {
    final Widget artwork = switch (config.artworkShape) {
      ArtworkShape.squareRounded => _SquareArtwork(
        path: track.artworkPath,
        size: size,
        accent: accent,
        radius: config.artworkRadius,
      ),
      ArtworkShape.circleVinyl => _VinylArtwork(
        path: track.artworkPath,
        size: size,
        accent: accent,
        playing: playing,
      ),
      ArtworkShape.card3D => _Card3DArtwork(
        path: track.artworkPath,
        size: size,
        accent: accent,
        radius: config.artworkRadius,
      ),
    };

    final Widget body =
        config.progressBarType == ProgressBarType.circularAroundArtwork
        ? _CircularProgressRing(
            size: size,
            progress: progress,
            accent: accent,
            onSeekFraction: onSeekFraction,
            child: artwork,
          )
        : artwork;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 480),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<String>('${track.id}-${config.artworkShape.name}'),
        child: body,
      ),
    );
  }
}

/// Imagen de carátula con recorte y degradado de respaldo.
class _ArtworkImage extends StatelessWidget {
  const _ArtworkImage({
    required this.path,
    required this.size,
    required this.shape,
    required this.accent,
    this.radius,
  });

  final String? path;
  final double size;
  final BoxShape shape;
  final BorderRadius? radius;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final String? artwork = path;
    Widget content;
    if (artwork == null || artwork.isEmpty) {
      content = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              accent.withValues(alpha: 0.65),
              accent.withValues(alpha: 0.12),
            ],
          ),
        ),
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white.withValues(alpha: 0.85),
          size: size * 0.36,
        ),
      );
    } else {
      content = Image.file(
        File(artwork),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      accent.withValues(alpha: 0.55),
                      accent.withValues(alpha: 0.10),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: size * 0.36,
                ),
              );
            },
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: shape == BoxShape.circle
          ? ClipOval(child: content)
          : ClipRRect(
              borderRadius: radius ?? BorderRadius.circular(24),
              child: content,
            ),
    );
  }
}

class _SquareArtwork extends StatelessWidget {
  const _SquareArtwork({
    required this.path,
    required this.size,
    required this.accent,
    required this.radius,
  });

  final String? path;
  final double size;
  final Color accent;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              accent.withValues(alpha: 0.55),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.28),
              blurRadius: 40,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: _ArtworkImage(
          path: path,
          size: size - 10,
          shape: BoxShape.rectangle,
          radius: BorderRadius.circular(math.max(radius - 5, 4)),
          accent: accent,
        ),
      ),
    );
  }
}

class _Card3DArtwork extends StatelessWidget {
  const _Card3DArtwork({
    required this.path,
    required this.size,
    required this.accent,
    required this.radius,
  });

  final String? path;
  final double size;
  final Color accent;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0014)
          ..rotateX(0.06)
          ..rotateY(-0.09),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.24),
                blurRadius: 46,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 34,
                offset: const Offset(14, 20),
              ),
            ],
          ),
          child: _ArtworkImage(
            path: path,
            size: size - 12,
            shape: BoxShape.rectangle,
            radius: BorderRadius.circular(math.max(radius - 5, 4)),
            accent: accent,
          ),
        ),
      ),
    );
  }
}

/// Vinilo con surcos y etiqueta central que gira solo al reproducir.
class _VinylArtwork extends StatefulWidget {
  const _VinylArtwork({
    required this.path,
    required this.size,
    required this.accent,
    required this.playing,
  });

  final String? path;
  final double size;
  final Color accent;
  final bool playing;

  @override
  State<_VinylArtwork> createState() => _VinylArtworkState();
}

class _VinylArtworkState extends State<_VinylArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void initState() {
    super.initState();
    _syncPlayback();
  }

  @override
  void didUpdateWidget(covariant _VinylArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) _syncPlayback();
  }

  void _syncPlayback() {
    if (widget.playing) {
      _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double labelSize = widget.size * 0.46;
    return Center(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Cuerpo del vinilo y resplandor.
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: <Color>[
                    Color(0xFF232323),
                    Color(0xFF101010),
                    Color(0xFF040404),
                  ],
                  stops: <double>[0.0, 0.72, 1.0],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.30),
                    blurRadius: 52,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.60),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
            ),
            CustomPaint(
              size: Size.square(widget.size),
              painter: _VinylGroovesPainter(),
            ),
            // Etiqueta central giratoria con la carátula.
            RotationTransition(
              turns: _spin,
              child: SizedBox(
                width: labelSize,
                height: labelSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    ClipOval(
                      child: SizedBox(
                        width: labelSize,
                        height: labelSize,
                        child: _ArtworkImage(
                          path: widget.path,
                          size: labelSize,
                          shape: BoxShape.circle,
                          accent: widget.accent,
                        ),
                      ),
                    ),
                    Container(
                      width: labelSize * 0.10,
                      height: labelSize * 0.10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0B0B0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: labelSize * 0.035,
                      height: labelSize * 0.035,
                      decoration: const BoxDecoration(
                        color: Color(0xFF3A3A3A),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VinylGroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double maxRadius = size.shortestSide / 2;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 18; i++) {
      final double radius = maxRadius * (0.52 + i * 0.025);
      paint.color = Colors.white.withValues(alpha: i.isEven ? 0.045 : 0.025);
      canvas.drawCircle(center, radius, paint);
    }

    // Reflejo tenue para dar volumen al disco.
    final Paint highlight = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(size.width, size.height),
        <Color>[
          Colors.white.withValues(alpha: 0.10),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.04),
        ],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8);
    canvas.drawCircle(center, maxRadius * 0.86, highlight);
  }

  @override
  bool shouldRepaint(covariant _VinylGroovesPainter oldDelegate) => false;
}

/// Anillo de progreso que envuelve la carátula; se puede tocar para buscar.
class _CircularProgressRing extends StatelessWidget {
  const _CircularProgressRing({
    required this.size,
    required this.progress,
    required this.accent,
    required this.onSeekFraction,
    required this.child,
  });

  final double size;
  final double progress;
  final Color accent;
  final ValueChanged<double> onSeekFraction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (TapDownDetails details) {
          final Offset center = Offset(size / 2, size / 2);
          final Offset local = details.localPosition;
          final double angle = math.atan2(
            local.dy - center.dy,
            local.dx - center.dx,
          );
          final double fraction = ((angle + math.pi / 2) / (2 * math.pi)) % 1;
          onSeekFraction(fraction);
        },
        onPanUpdate: (DragUpdateDetails details) {
          final Offset center = Offset(size / 2, size / 2);
          final Offset local = details.localPosition;
          final double angle = math.atan2(
            local.dy - center.dy,
            local.dx - center.dx,
          );
          final double fraction = ((angle + math.pi / 2) / (2 * math.pi)) % 1;
          onSeekFraction(fraction);
        },
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(progress: progress, accent: accent),
              ),
              SizedBox(width: size * 0.84, height: size * 0.84, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2 - 7;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    const double start = -math.pi / 2;

    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawCircle(center, radius, base);

    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.45)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);
    canvas.drawArc(
      rect,
      start,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      glow,
    );

    final Paint active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.sweep(center, <Color>[
        accent.withValues(alpha: 0.55),
        accent,
        Colors.white,
      ]);
    canvas.drawArc(
      rect,
      start,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}

/// Fondo degradado con orbes de color; responde a la paleta dinámica.
class _DynamicBackdrop extends StatelessWidget {
  const _DynamicBackdrop({required this.config, required this.accent});

  final AppThemeConfig config;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = config.usesDynamicPalette
        ? <Color>[
            Color.lerp(config.background, accent, 0.32) ?? config.background,
            config.background,
            Color.lerp(config.background, accent, 0.20) ?? config.background,
          ]
        : config.backdrop;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -80,
          child: _Glow(color: accent.withValues(alpha: 0.26), size: 380),
        ),
        Positioned(
          bottom: -160,
          left: -120,
          child: _Glow(color: accent.withValues(alpha: 0.16), size: 420),
        ),
        // Viñeta para asegurar contraste del texto sobre cualquier paleta.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.1,
                colors: <Color>[
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.42),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}
