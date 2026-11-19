import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_navigation.dart';
import '../../../core/models/playback_state.dart';
import '../../../core/models/track.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/compact_style_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/window_service.dart';
import '../../../core/theme/app_theme_config.dart';
import '../../../core/theme/compact_style_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/audio_progress_bar.dart';
import 'animated_favorite_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/polaris_surface.dart';
import '../../../shared/widgets/tactile_icon_button.dart';
import '../../../shared/widgets/track_properties_modal.dart';
import '../../dynamic_island/presentation/island_providers.dart';
import '../../equalizer/presentation/equalizer_screen.dart';
import '../../lyrics/presentation/in_artwork_lyrics.dart';
import '../domain/player_controller.dart';
import 'artwork_gestures.dart';
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
  bool _showLyrics = false;

  /// Deslizar abajo: en escritorio se transforma en isla o se minimiza; en
  /// móvil el reproductor pasa a la mini barra persistente de la Biblioteca.
  void _minimizePlayer() {
    if (Platform.isWindows) {
      final WindowService window = ref.read(windowServiceProvider);
      final bool island = ref.read(dynamicIslandControllerProvider).enabled;
      if (island) {
        unawaited(window.showIsland());
      } else {
        unawaited(window.minimize());
      }
      return;
    }
    ref.read(appSectionProvider.notifier).state = AppSection.library;
  }

  /// Alterna la carátula y las letras dentro del mismo hueco del reproductor.
  void _toggleLyrics() => setState(() => _showLyrics = !_showLyrics);

  @override
  Widget build(BuildContext context) {
    final Track? track = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.track),
    );
    final bool playing = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playing),
    );
    final AppThemeConfig config = ref.watch(themeConfigProvider);
    final CompactStyleConfig playerStyle = ref.watch(
      compactStyleProvider(CompactSurface.player),
    );

    final AsyncValue<Color>? paletteAsync = config.usesDynamicPalette
        ? ref.watch(artworkAccentProvider(track?.artworkPath))
        : null;
    final Color accent =
        playerStyle.accent ?? paletteAsync?.valueOrNull ?? config.accent;
    final Color background = playerStyle.background ?? config.background;
    final List<Color>? backdrop = playerStyle.background == null
        ? config.backdrop
        : null;
    // La forma de carátula es propia del reproductor: si el usuario la anuló en
    // "Diseños compactos → Principal", gana sobre la configuración global.
    final ArtworkShape shape = playerStyle.artworkShape ?? config.artworkShape;
    final AppThemeConfig effectiveConfig = shape == config.artworkShape
        ? config
        : config.copyWith(artworkShape: shape);

    if (track == null) {
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _DynamicBackdrop(
            config: effectiveConfig,
            accent: accent,
            background: background,
            backdrop: backdrop,
          ),
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
        _DynamicBackdrop(
          config: effectiveConfig,
          accent: accent,
          background: background,
          backdrop: backdrop,
        ),
        LayoutBuilder(
          key: const ValueKey<String>('player'),
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= 980;
            if (wide) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: math.max(
                                constraints.maxHeight - 44,
                                0,
                              ),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: _ArtworkStage(
                                track: track,
                                config: effectiveConfig,
                                accent: accent,
                                playing: playing,
                                showLyrics: _showLyrics,
                                onCloseLyrics: _toggleLyrics,
                                size: math.min(
                                  math.min(constraints.maxWidth * 0.30, 400),
                                  math.max(constraints.maxHeight * 0.58, 220),
                                ),
                                onSeekFraction: controller.seekFraction,
                                onPrevious: controller.previous,
                                onNext: controller.next,
                                onLyrics: _toggleLyrics,
                                onMinimize: _minimizePlayer,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 26),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Flexible(
                            flex: 4,
                            fit: FlexFit.tight,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PlayerColumn(
                                track: track,
                                config: effectiveConfig,
                                accent: accent,
                                controller: controller,
                                panelTab: _panelTab,
                                onPanelChanged: (int value) =>
                                    setState(() => _panelTab = value),
                                panelHeight: null,
                                includePanel: false,
                                onOpenLyrics: _toggleLyrics,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: _MediaPanel(
                              track: track,
                              controller: controller,
                              accent: accent,
                              tab: _panelTab,
                              onTabChanged: (int value) =>
                                  setState(() => _panelTab = value),
                              height: null,
                              onOpenLyrics: _toggleLyrics,
                            ),
                          ),
                        ],
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
                    config: effectiveConfig,
                    accent: accent,
                    playing: playing,
                    showLyrics: _showLyrics,
                    onCloseLyrics: _toggleLyrics,
                    size: math.min(
                      math.min(constraints.maxWidth - 88, 320),
                      math.max(constraints.maxHeight * 0.5, 200),
                    ),
                    onSeekFraction: controller.seekFraction,
                    onPrevious: controller.previous,
                    onNext: controller.next,
                    onLyrics: _toggleLyrics,
                    onMinimize: _minimizePlayer,
                  ),
                ),
                const SizedBox(height: 20),
                _PlayerColumn(
                  track: track,
                  config: effectiveConfig,
                  accent: accent,
                  controller: controller,
                  panelTab: _panelTab,
                  onPanelChanged: (int value) =>
                      setState(() => _panelTab = value),
                  panelHeight: math.max(
                    300,
                    math.min(460, constraints.maxHeight * 0.45),
                  ),
                  onOpenLyrics: _toggleLyrics,
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
///
/// Cada bloque observa solo la porción del estado que necesita para que el
/// _tick_ de posición (5 veces por segundo) no reconstruya la pantalla entera.
class _PlayerColumn extends ConsumerWidget {
  const _PlayerColumn({
    required this.track,
    required this.config,
    required this.accent,
    required this.controller,
    required this.panelTab,
    required this.onPanelChanged,
    this.panelHeight,
    this.includePanel = true,
    required this.onOpenLyrics,
  });

  final Track track;
  final AppThemeConfig config;
  final Color accent;
  final PlayerController controller;
  final int panelTab;
  final ValueChanged<int> onPanelChanged;
  final double? panelHeight;
  final bool includePanel;
  final VoidCallback onOpenLyrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool sleepActive = ref.watch(
      playerControllerProvider.select(
        (PlayerUiState s) => s.sleepRemaining != null || s.sleepEndsAtTrack,
      ),
    );
    final String? error = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.error),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _TrackHeader(track: track, accent: accent),
        const SizedBox(height: 14),
        _ProgressSection(
          config: config,
          accent: config.usesDynamicPalette ? accent : config.progressColor,
          onSeekFraction: controller.seekFraction,
        ),
        const SizedBox(height: 8),
        _TransportControls(controller: controller, accent: accent),
        const SizedBox(height: 10),
        _VolumeRow(
          controller: controller,
          accent: config.usesDynamicPalette ? accent : config.volumeColor,
        ),
        const SizedBox(height: 6),
        _QuickActions(accent: accent),
        if (sleepActive) _SleepBadge(controller: controller),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        if (includePanel) ...<Widget>[
          const SizedBox(height: 18),
          _MediaPanel(
            track: track,
            controller: controller,
            accent: accent,
            tab: panelTab,
            onTabChanged: onPanelChanged,
            height: panelHeight ?? 360,
            onOpenLyrics: onOpenLyrics,
          ),
        ],
      ],
    );
  }
}

class _TrackHeader extends ConsumerWidget {
  const _TrackHeader({required this.track, required this.accent});

  final Track track;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                const SizedBox(height: 7),
                _TrackOriginBadge(track: track, accent: accent),
              ],
            ),
          ),

          // Botón de propiedades (accesible con clic derecho en toda la UI)
          Container(
            margin: const EdgeInsets.only(left: 8),
            child: IconButton(
              onPressed: () => TrackPropertiesModal.show(
                context: context,
                track: track,
                accent: accent,
              ),
              iconSize: 20,
              tooltip: 'Propiedades de la pista',
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      accent.withValues(alpha: 0.2),
                      accent.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: accent,
                  size: 18,
                ),
              ),
            ),
          ),

          AnimatedFavoriteButton(
            key: ValueKey<int>(track.id),
            isFavorite: track.isFavorite,
            enabled: track.isPersisted,
            accent: accent,
            tooltip: !track.isPersisted
                ? 'Descarga la pista para guardarla'
                : track.isFavorite
                ? 'Quitar de favoritos'
                : 'Añadir a favoritos',
            onPressed: () => ref
                .read(playerControllerProvider.notifier)
                .setFavorite(!track.isFavorite),
          ),
        ],
      ),
    );
  }
}

/// Badge discreto que distingue streaming, descarga y archivo local.
class _TrackOriginBadge extends StatelessWidget {
  const _TrackOriginBadge({required this.track, required this.accent});

  final Track track;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label) = switch (track.origin) {
      TrackOrigin.local => (Icons.offline_pin_rounded, 'Local'),
      TrackOrigin.downloaded => (Icons.cloud_done_rounded, 'Descargada'),
      TrackOrigin.online => (Icons.cloud_queue_rounded, 'Streaming'),
    };
    final bool online = track.isOnline;
    final Color color = online ? accent : Colors.white60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: (online ? accent : Colors.white).withValues(
          alpha: online ? 0.14 : 0.06,
        ),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Progreso según el tipo elegido. El anillo circular se dibuja alrededor de
/// la carátula, así que aquí solo muestra los tiempos y una ayuda.
class _ProgressSection extends ConsumerWidget {
  const _ProgressSection({
    required this.config,
    required this.accent,
    required this.onSeekFraction,
  });

  final AppThemeConfig config;
  final Color accent;
  final ValueChanged<double> onSeekFraction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (config.progressBarType) {
      case ProgressBarType.linearClassic:
        return AudioProgressBar(accent: accent, onSeekFraction: onSeekFraction);

      case ProgressBarType.waveform:
        // Keep existing waveform implementation
        final Duration position = ref.watch(
          playerControllerProvider.select(
            (PlayerUiState s) => s.playback.position,
          ),
        );
        final Duration duration = ref.watch(
          playerControllerProvider.select(
            (PlayerUiState s) => s.playback.duration,
          ),
        );
        return _WaveformProgress(
          position: position,
          duration: duration,
          accent: accent,
          onSeekFraction: onSeekFraction,
        );

      case ProgressBarType.circularAroundArtwork:
        // Keep existing circular implementation
        final Duration position = ref.watch(
          playerControllerProvider.select(
            (PlayerUiState s) => s.playback.position,
          ),
        );
        final Duration duration = ref.watch(
          playerControllerProvider.select(
            (PlayerUiState s) => s.playback.duration,
          ),
        );
        return _TimeRow(position: position, duration: duration);
    }
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

class _TransportControls extends ConsumerWidget {
  const _TransportControls({required this.controller, required this.accent});

  final PlayerController controller;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool playing = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playing),
    );
    final bool buffering = ref.watch(
      playerControllerProvider.select(
        (PlayerUiState s) => s.playback.buffering,
      ),
    );
    final bool shuffle = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.shuffle),
    );
    final RepeatMode repeat = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.repeat),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: <Widget>[
        TactileIconButton(
          tooltip: 'Aleatorio',
          onPressed: controller.toggleShuffle,
          icon: Icons.shuffle_rounded,
          color: shuffle ? accent : Colors.white54,
          echoColor: accent,
        ),
        TactileIconButton(
          tooltip: 'Anterior',
          iconSize: 32,
          echoColor: accent,
          onPressed: controller.previous,
          icon: Icons.skip_previous_rounded,
        ),
        _PlayPauseButton(
          playing: playing,
          buffering: buffering,
          accent: accent,
          onPressed: controller.togglePlay,
        ),
        TactileIconButton(
          tooltip: 'Siguiente',
          iconSize: 32,
          echoColor: accent,
          onPressed: controller.next,
          icon: Icons.skip_next_rounded,
        ),
        TactileIconButton(
          tooltip: _repeatLabel(repeat),
          onPressed: controller.cycleRepeat,
          icon: repeat == RepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          color: repeat == RepeatMode.off ? Colors.white54 : accent,
          echoColor: accent,
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

class _PlayPauseButton extends StatefulWidget {
  const _PlayPauseButton({
    required this.playing,
    required this.buffering,
    required this.accent,
    required this.onPressed,
  });

  final bool playing;
  final bool buffering;
  final Color accent;
  final VoidCallback onPressed;

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.playing ? 'Pausar' : 'Reproducir',
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color.lerp(widget.accent, Colors.white, 0.22) ??
                      widget.accent,
                  widget.accent,
                ],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: widget.accent.withValues(
                    alpha: _pressed ? 0.30 : 0.48,
                  ),
                  blurRadius: _pressed ? 14 : 26,
                  spreadRadius: _pressed ? 0 : 3,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder:
                    (Widget child, Animation<double> animation) =>
                        ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.6,
                            end: 1,
                          ).animate(animation),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        ),
                child: widget.buffering
                    ? const SizedBox(
                        key: ValueKey<String>('buffering'),
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.black,
                        ),
                      )
                    : Icon(
                        widget.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        key: ValueKey<bool>(widget.playing),
                        size: 38,
                        color: Colors.black,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VolumeRow extends ConsumerWidget {
  const _VolumeRow({required this.controller, required this.accent});

  final PlayerController controller;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double speed = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.speed),
    );

    return Row(
      children: <Widget>[
        Expanded(
          child: VolumeSlider(controller: controller, accent: accent),
        ),
        const SizedBox(width: 4),
        _SpeedMenu(speed: speed, onChanged: controller.setSpeed),
        _ABLoopButton(controller: controller, accent: accent),
        _SleepMenu(controller: controller),
      ],
    );
  }
}

/// Repetidor A-B: marca el inicio y el final del fragmento a repetir.
class _ABLoopButton extends ConsumerWidget {
  const _ABLoopButton({required this.controller, required this.accent});

  final PlayerController controller;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Duration? a = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.loopA),
    );
    final Duration? b = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.loopB),
    );
    final bool active = a != null && b != null && b > a;

    return PopupMenuButton<String>(
      tooltip: 'Repetidor A-B',
      icon: Icon(
        Icons.repeat_on_rounded,
        size: 20,
        color: active ? accent : Colors.white54,
      ),
      onSelected: (String action) {
        switch (action) {
          case 'a':
            controller.markLoopA();
            break;
          case 'b':
            controller.markLoopB();
            break;
          case 'clear':
            controller.clearLoop();
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'a',
          child: Text(a == null ? 'Marcar A' : 'A: ${_format(a)}'),
        ),
        PopupMenuItem<String>(
          value: 'b',
          child: Text(b == null ? 'Marcar B' : 'B: ${_format(b)}'),
        ),
        if (a != null || b != null)
          const PopupMenuItem<String>(
            value: 'clear',
            child: Text('Desactivar'),
          ),
      ],
    );
  }

  static String _format(Duration value) {
    final int minutes = value.inMinutes;
    final int seconds = value.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
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

class _SleepMenu extends ConsumerWidget {
  const _SleepMenu({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool active = ref.watch(
      playerControllerProvider.select(
        (PlayerUiState s) => s.sleepRemaining != null || s.sleepEndsAtTrack,
      ),
    );
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

class _SleepBadge extends ConsumerWidget {
  const _SleepBadge({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Duration? remaining = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.sleepRemaining),
    );
    final bool endsAtTrack = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.sleepEndsAtTrack),
    );

    if (remaining == null && !endsAtTrack) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.bedtime_rounded, size: 14, color: Colors.white54),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              endsAtTrack || remaining == null
                  ? 'Se pausará al terminar la pista'
                  : 'Se pausará en ${Formatters.duration(remaining)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
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

/// Acceso rápido al ecualizador junto a los controles.
/// Las letras se abren desde la pestaña del panel inferior para no duplicar
/// el mismo botón dos veces en la pantalla.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = OutlinedButton.styleFrom(
      foregroundColor: accent,
      side: BorderSide(color: accent.withValues(alpha: 0.35)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => Scaffold(
                appBar: AppBar(title: const Text('Ecualizador')),
                body: const EqualizerScreen(),
              ),
            ),
          ),
          icon: const Icon(Icons.graphic_eq_rounded, size: 18),
          label: const Text('Ecualizador'),
          style: style,
        ),
      ],
    );
  }
}

class _MediaPanel extends ConsumerWidget {
  const _MediaPanel({
    required this.track,
    required this.controller,
    required this.accent,
    required this.tab,
    required this.onTabChanged,
    required this.height,
    required this.onOpenLyrics,
  });

  final Track track;
  final PlayerController controller;
  final Color accent;
  final int tab;
  final ValueChanged<int> onTabChanged;

  /// `null` hace que el panel ocupe todo el espacio disponible (modo ancho).
  final double? height;
  final VoidCallback onOpenLyrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // La cola visible es el orden ACTIVO: con aleatorio, `index` pertenece a la
    // playlist barajada de mpv y resaltar `queue[index]` marcaría otra pista.
    final List<Track> queue = ref.watch(
      playerControllerProvider.select(
        (PlayerUiState s) => s.playback.activeQueue,
      ),
    );
    final int index = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.index),
    );
    final bool playing = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playing),
    );
    final bool fluid = height == null;

    final Widget panel = PolarisSurface(
      padding: EdgeInsets.fromLTRB(12, 12, 12, fluid ? 0 : 8),
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
                  selected: const <int>{0},
                  showSelectedIcon: false,
                  onSelectionChanged: (Set<int> value) {
                    if (value.first == 1) {
                      onOpenLyrics();
                    } else {
                      onTabChanged(0);
                    }
                  },
                ),
              ),
              if (tab == 0)
                IconButton(
                  tooltip: 'Vaciar cola',
                  onPressed: queue.isEmpty ? null : controller.clearQueue,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _QueueList(
              queue: queue,
              index: index,
              playing: playing,
              controller: controller,
              accent: accent,
              padBottom: fluid ? 0 : 8,
            ),
          ),
        ],
      ),
    );

    return fluid
        ? SizedBox.expand(child: panel)
        : SizedBox(height: height, child: panel);
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList({
    required this.queue,
    required this.index,
    required this.playing,
    required this.controller,
    required this.accent,
    this.padBottom = 8,
  });

  final List<Track> queue;
  final int index;
  final bool playing;
  final PlayerController controller;
  final Color accent;
  final double padBottom;

  @override
  Widget build(BuildContext context) {
    if (queue.isEmpty) {
      return const Center(
        child: Text(
          'La cola está vacía',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: padBottom),
      itemCount: queue.length,
      itemBuilder: (BuildContext context, int i) {
        final Track track = queue[i];
        final bool current = i == index;
        final Widget tile = ListTile(
          key: ValueKey<int>(track.id),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: current
              ? accent.withValues(alpha: playing ? 0.16 : 0.10)
              : null,
          leading: Stack(
            alignment: Alignment.bottomRight,
            clipBehavior: Clip.none,
            children: <Widget>[
              _ArtworkImage(
                path: track.artworkPath,
                size: 38,
                shape: BoxShape.rectangle,
                radius: BorderRadius.circular(8),
                accent: accent,
              ),
              if (current)
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: _NowPlayingWaves(color: accent, playing: playing),
                ),
            ],
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
                onPressed: () => controller.removeFromQueue(i),
              ),
            ],
          ),
          onTap: () => controller.playAt(i),
        );

        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: current && playing
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: tile,
        );
      },
    );
  }
}

/// Ondas compactas que marcan la pista activa de la cola.
///
/// El controlador solo se ejecuta mientras hay reproducción; al pausar se
/// conservan tres barras quietas para no perder la referencia visual.
class _NowPlayingWaves extends ConsumerStatefulWidget {
  const _NowPlayingWaves({required this.color, required this.playing});

  final Color color;
  final bool playing;

  @override
  ConsumerState<_NowPlayingWaves> createState() => _NowPlayingWavesState();
}

class _NowPlayingWavesState extends ConsumerState<_NowPlayingWaves>
    with SingleTickerProviderStateMixin {
  static const Duration _period = Duration(milliseconds: 900);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period,
  );
  ValueNotifier<WindowUiState>? _window;
  bool _backgrounded = false;

  @override
  void initState() {
    super.initState();
    _window = ref.read(windowStateProvider);
    _backgrounded = _window!.value.backgrounded;
    _window!.addListener(_onWindowChanged);
    _sync();
  }

  @override
  void didUpdateWidget(covariant _NowPlayingWaves oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _onWindowChanged() {
    final bool value = _window!.value.backgrounded;
    if (value == _backgrounded) return;
    setState(() => _backgrounded = value);
    _sync();
  }

  /// El ticker solo corre si hay sonido y la ventana es visible.
  void _sync() {
    if (widget.playing && !_backgrounded) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _window?.removeListener(_onWindowChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? _) => Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: widget.color.withValues(alpha: 0.35)),
          ),
          child: CustomPaint(
            painter: _QueueWavePainter(
              phase: _controller.value,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueWavePainter extends CustomPainter {
  const _QueueWavePainter({required this.phase, required this.color});

  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 3; i++) {
      final double wave = math.sin(phase * math.pi * 2 + i * 0.9);
      final double height = size.height * (0.42 + 0.36 * wave);
      final double x = size.width * (i + 1) / 4;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _QueueWavePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}

// ---------------------------------------------------------------------------
// Carátula adaptativa
// ---------------------------------------------------------------------------

/// Fundido cinematográfico entre carátula y letras y entre pistas.
///
/// La dirección del deslizamiento se deriva del cambio de posición en el orden
/// activo; así funciona igual con la cola secuencial que con el espejo barajado
/// y no depende de comparar ids ni carátulas.
class _CinematicSwitcher extends StatefulWidget {
  const _CinematicSwitcher({required this.position, required this.child});

  final int position;
  final Widget child;

  @override
  State<_CinematicSwitcher> createState() => _CinematicSwitcherState();
}

class _CinematicSwitcherState extends State<_CinematicSwitcher> {
  bool _forward = true;

  @override
  void didUpdateWidget(covariant _CinematicSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) {
      _forward = widget.position > oldWidget.position;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 460),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final bool toLyrics =
            child.key is ValueKey<String> &&
            (child.key as ValueKey<String>).value.startsWith('artwork-lyrics');
        final Offset begin = toLyrics
            ? const Offset(0, 0.10)
            : Offset(_forward ? 0.16 : -0.16, 0);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: begin,
              end: Offset.zero,
            ).animate(animation),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _ArtworkStage extends ConsumerWidget {
  const _ArtworkStage({
    required this.track,
    required this.config,
    required this.accent,
    required this.playing,
    required this.showLyrics,
    required this.size,
    required this.onSeekFraction,
    required this.onPrevious,
    required this.onNext,
    required this.onLyrics,
    required this.onCloseLyrics,
    required this.onMinimize,
  });

  final Track track;
  final AppThemeConfig config;
  final Color accent;
  final bool playing;
  final bool showLyrics;
  final double size;
  final ValueChanged<double> onSeekFraction;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLyrics;
  final VoidCallback onCloseLyrics;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool ring =
        config.progressBarType == ProgressBarType.circularAroundArtwork;
    final double progress = ring
        ? ref.watch(
            playerControllerProvider.select(
              (PlayerUiState s) => s.playback.progress,
            ),
          )
        : 0;
    // Posición en el orden activo: permite decidir si la transición entra desde
    // la derecha (siguiente) o desde la izquierda (anterior), también en shuffle.
    final int position = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.index),
    );

    // El anillo ocupa el 84 % interior: la carátula se ajusta para no
    // desbordar el círculo (el antiguo desajuste del estilo Vinilo).
    final double artSize = ring ? size * 0.84 : size;

    final ValueNotifier<WindowUiState> windowNotifier = ref.watch(
      windowStateProvider,
    );
    final Widget artwork = ValueListenableBuilder<WindowUiState>(
      valueListenable: windowNotifier,
      builder: (BuildContext context, WindowUiState state, Widget? _) {
        return switch (config.artworkShape) {
          ArtworkShape.squareRounded => _SquareArtwork(
            path: track.artworkPath,
            size: artSize,
            accent: accent,
            radius: config.artworkRadius,
          ),
          ArtworkShape.circleVinyl => _VinylArtwork(
            path: track.artworkPath,
            size: artSize,
            accent: accent,
            playing: playing,
            paused: state.backgrounded,
          ),
          ArtworkShape.card3D => _Card3DArtwork(
            path: track.artworkPath,
            size: artSize,
            accent: accent,
            radius: config.artworkRadius,
          ),
        };
      },
    );

    final Widget body = ring
        ? _CircularProgressRing(
            size: size,
            progress: progress,
            accent: accent,
            child: artwork,
          )
        : artwork;

    // La carátula y las letras comparten el mismo área. El AnimatedSwitcher
    // hace el crossfade; los gestos de carátula solo se montan cuando la imagen
    // está visible para no robar el scroll de la letra.
    return SizedBox(
      width: size,
      height: size,
      child: _CinematicSwitcher(
        position: position,
        child: showLyrics
            ? KeyedSubtree(
                // La clave incluye la pista: sin ella el State de LyricsPanel se
                // reutiliza al cambiar de canción y conserva scroll/índice viejo.
                key: ValueKey<String>('artwork-lyrics-${track.id}'),
                child: InArtworkLyrics(
                  track: track,
                  size: size,
                  accent: accent,
                  onClose: onCloseLyrics,
                ),
              )
            : KeyedSubtree(
                key: ValueKey<String>(
                  'artwork-${track.id}-${config.artworkShape.name}',
                ),
                child: ArtworkGestures(
                  size: size,
                  onSeekFraction: onSeekFraction,
                  onPrevious: onPrevious,
                  onNext: onNext,
                  onLyrics: onLyrics,
                  onMinimize: onMinimize,
                  accent: accent,
                  child: RepaintBoundary(child: body),
                ),
              ),
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
      final double ratio = MediaQuery.devicePixelRatioOf(context);
      final int decodeWidth = (size * ratio).round().clamp(48, 2048);
      content = Image.file(
        File(artwork),
        key: ValueKey<String>(artwork),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: decodeWidth,
        filterQuality: FilterQuality.medium,
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
    this.paused = false,
  });

  final String? path;
  final double size;
  final Color accent;
  final bool playing;
  final bool paused;

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
    if (oldWidget.playing != widget.playing ||
        oldWidget.paused != widget.paused) {
      _syncPlayback();
    }
  }

  void _syncPlayback() {
    if (widget.playing && !widget.paused) {
      if (!_spin.isAnimating) _spin.repeat();
    } else if (_spin.isAnimating) {
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

/// Anillo de progreso que envuelve la carátula. La búsqueda y los deslizamientos
/// los gestiona [ArtworkGestures] por encima de todo el conjunto.
class _CircularProgressRing extends StatelessWidget {
  const _CircularProgressRing({
    required this.size,
    required this.progress,
    required this.accent,
    required this.child,
  });

  final double size;
  final double progress;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
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
            // La carátula ya llega reducida desde _ArtworkStage (84 %):
            // volver a encogerla aquí producía el desajuste del vinilo.
            child,
          ],
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
  const _DynamicBackdrop({
    required this.config,
    required this.accent,
    required this.background,
    this.backdrop,
  });

  final AppThemeConfig config;
  final Color accent;
  final Color background;
  final List<Color>? backdrop;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors =
        backdrop ??
        (config.usesDynamicPalette
            ? <Color>[
                Color.lerp(background, accent, 0.32) ?? background,
                background,
                Color.lerp(background, accent, 0.20) ?? background,
              ]
            : config.backdrop);

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
