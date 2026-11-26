import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_navigation.dart';
import '../../../core/models/playback_state.dart';
import '../../../core/models/track.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/compact_style_provider.dart';
import '../../../core/providers/motion_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/window_service.dart';
import '../../../core/theme/app_theme_config.dart';
import '../../../core/theme/color_math.dart';
import '../../../core/theme/compact_style_config.dart';
import '../../../core/theme/motion_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/audio_progress_bar.dart';
import 'animated_favorite_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/light_motion.dart';
import '../../../shared/widgets/motion_scope.dart';
import '../../../shared/widgets/polaris_surface.dart';
import '../../../shared/widgets/tactile_icon_button.dart';
import '../../../shared/widgets/track_properties_modal.dart';
import '../../dynamic_island/presentation/island_providers.dart';
import '../../equalizer/presentation/equalizer_providers.dart';
import '../../equalizer/presentation/equalizer_screen.dart';
import '../../lyrics/presentation/expanded_lyrics_view.dart';
import '../domain/player_controller.dart';
import 'artwork_gestures.dart';
import 'audio_output_providers.dart';
import 'audio_output_sheet.dart';
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

  /// En móvil la cola no ocupa espacio: se abre como hoja bajo demanda.
  void _openQueueSheet(Color accent) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _QueueSheet(
        controller: ref.read(playerControllerProvider.notifier),
        accent: accent,
        onClose: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

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
                      flex: _showLyrics ? 6 : 5,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _showLyrics
                            ? _PlayerStage(
                                track: track,
                                config: effectiveConfig,
                                accent: accent,
                                playing: playing,
                                showLyrics: true,
                                expanded: true,
                                size: math.min(
                                  math.min(constraints.maxWidth * 0.42, 520),
                                  math.max(constraints.maxHeight * 0.72, 280),
                                ),
                                onSeekFraction: controller.seekFraction,
                                onPrevious: controller.previous,
                                onNext: controller.next,
                                onLyrics: _toggleLyrics,
                                onCloseLyrics: _toggleLyrics,
                                onMinimize: _minimizePlayer,
                              )
                            : SingleChildScrollView(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: math.max(
                                      constraints.maxHeight - 44,
                                      0,
                                    ),
                                  ),
                                  child: Center(
                                    child: _PlayerStage(
                                      track: track,
                                      config: effectiveConfig,
                                      accent: accent,
                                      playing: playing,
                                      showLyrics: false,
                                      size: math.min(
                                        math.min(
                                          constraints.maxWidth * 0.30,
                                          400,
                                        ),
                                        math.max(
                                          constraints.maxHeight * 0.58,
                                          220,
                                        ),
                                      ),
                                      onSeekFraction: controller.seekFraction,
                                      onPrevious: controller.previous,
                                      onNext: controller.next,
                                      onLyrics: _toggleLyrics,
                                      onCloseLyrics: _toggleLyrics,
                                      onMinimize: _minimizePlayer,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    SizedBox(width: _showLyrics ? 18 : 26),
                    Expanded(
                      flex: _showLyrics ? 4 : 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Flexible(
                            flex: _showLyrics ? 10 : 4,
                            fit: FlexFit.tight,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PlayerColumn(
                                track: track,
                                config: effectiveConfig,
                                accent: accent,
                                controller: controller,
                              ),
                            ),
                          ),
                          if (!_showLyrics)
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
                                lyricsVisible: _showLyrics,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            final double maxHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : 900;
            // En pantallas estrechas la cola vive en una hoja bajo demanda: el
            // reproductor recupera ese alto para carátula y controles.
            final double stageSize = _showLyrics
                ? math.max(240, maxHeight * 0.55)
                : math.min(
                    math.min(constraints.maxWidth - 88, 320),
                    math.max(maxHeight * 0.5, 200),
                  );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: _showLyrics
                        ? _PlayerStage(
                            track: track,
                            config: effectiveConfig,
                            accent: accent,
                            playing: playing,
                            showLyrics: true,
                            expanded: true,
                            size: stageSize,
                            onSeekFraction: controller.seekFraction,
                            onPrevious: controller.previous,
                            onNext: controller.next,
                            onLyrics: _toggleLyrics,
                            onCloseLyrics: _toggleLyrics,
                            onMinimize: _minimizePlayer,
                          )
                        : Center(
                            child: _PlayerStage(
                              track: track,
                              config: effectiveConfig,
                              accent: accent,
                              playing: playing,
                              showLyrics: false,
                              size: stageSize,
                              onSeekFraction: controller.seekFraction,
                              onPrevious: controller.previous,
                              onNext: controller.next,
                              onLyrics: _toggleLyrics,
                              onCloseLyrics: _toggleLyrics,
                              onMinimize: _minimizePlayer,
                            ),
                          ),
                  ),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _PlayerColumn(
                        track: track,
                        config: effectiveConfig,
                        accent: accent,
                        controller: controller,
                        onOpenQueue: () => _openQueueSheet(accent),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Columna de información, progreso y controles. El panel de cola/letras es
/// un hermano flex para poder medirlo contra el alto disponible.
///
/// Cada bloque observa solo la porción del estado que necesita para que el
/// _tick_ de posición (5 veces por segundo) no reconstruya la pantalla entera.
class _PlayerColumn extends ConsumerWidget {
  const _PlayerColumn({
    required this.track,
    required this.config,
    required this.accent,
    required this.controller,
    this.onOpenQueue,
  });

  final Track track;
  final AppThemeConfig config;
  final Color accent;
  final PlayerController controller;

  /// Solo se entrega en pantallas estrechas, donde la cola no tiene panel fijo.
  final VoidCallback? onOpenQueue;

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
        _QuickActions(
          accent: accent,
          playing: ref.watch(
            playerControllerProvider.select((PlayerUiState s) => s.playing),
          ),
        ),
        if (onOpenQueue != null) ...<Widget>[
          const SizedBox(height: 10),
          _QueueButton(accent: accent, onPressed: onOpenQueue!),
        ],
        if (sleepActive) _SleepBadge(controller: controller),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xB3260F12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFF6B6B), width: 1),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFFFB4AB),
                    size: 18,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      error,
                      style: TextStyle(
                        color: context.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Acceso explícito a la cola en pantallas donde no hay panel fijo.
class _QueueButton extends ConsumerWidget {
  const _QueueButton({required this.accent, required this.onPressed});

  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int count = ref.watch(
      playerControllerProvider.select(
        (PlayerUiState s) => s.playback.activeQueue.length,
      ),
    );
    return Semantics(
      button: true,
      label: 'Cola / Lista de reproducción, $count pistas',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
          color: accent.withValues(alpha: 0.08),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: <Widget>[
                  Icon(Icons.queue_music_rounded, color: accent, size: 21),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Cola / Lista de reproducción',
                          style: TextStyle(
                            color: context.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          count == 1
                              ? '1 pista en la cola'
                              : '$count pistas en la cola',
                          style: TextStyle(
                            color: context.inkAlpha(0.54),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.inkAlpha(0.50),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja deslizante con la cola completa, usada solo en móvil.
class _QueueSheet extends ConsumerWidget {
  const _QueueSheet({
    required this.controller,
    required this.accent,
    required this.onClose,
  });

  final PlayerController controller;
  final Color accent;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final Color ink = context.onPanel;

    return Padding(
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: PolarisSurface(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          borderRadius: 24,
          glowColor: accent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Icon(Icons.queue_music_rounded, color: accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cola / Lista de reproducción',
                      style: TextStyle(
                        color: ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Vaciar cola',
                    color: ink.withValues(alpha: 0.70),
                    onPressed: queue.isEmpty ? null : controller.clearQueue,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    color: ink.withValues(alpha: 0.70),
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: _QueueList(
                  queue: queue,
                  index: index,
                  playing: playing,
                  controller: controller,
                  accent: accent,
                  padBottom: 4,
                ),
              ),
            ],
          ),
        ),
      ),
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
      duration: context.motion.duration(const Duration(milliseconds: 420)),
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
                      ?.copyWith(color: context.inkAlpha(0.70)),
                ),
                if (track.album.isNotEmpty && track.album != 'Desconocido')
                  Text(
                    track.album,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: context.inkAlpha(0.38)),
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
                // Lectura única al abrir el diálogo: sin streams ni polling.
                technicalInfo: ref
                    .read(audioEngineProvider)
                    .readTechnicalInfo(),
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
    final Color color = online ? accent : context.inkAlpha(0.60);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: (online ? accent : context.ink).withValues(
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
          smooth: config.isVinylWave,
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
            style: TextStyle(fontSize: 11, color: context.inkAlpha(0.54)),
          ),
          Text(
            Formatters.duration(duration),
            style: TextStyle(fontSize: 11, color: context.inkAlpha(0.54)),
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
    this.smooth = false,
  });

  final Duration position;
  final Duration duration;
  final Color accent;
  final ValueChanged<double> onSeekFraction;

  /// Vinyl Wave usa una curva continua; los demás temas conservan las barras.
  final bool smooth;

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
              child: RepaintBoundary(
                child: SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _WaveformPainter(
                      progress: progress,
                      accent: accent,
                      smooth: smooth,
                    ),
                  ),
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
  _WaveformPainter({
    required this.progress,
    required this.accent,
    this.smooth = false,
  }) {
    // Dos únicos objetos Paint por repintado en vez de ~64 `Color` nuevos.
    _playedPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..color = accent;
    _pendingPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.18);
    _thumbPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accent;
    _thumbCorePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.92);
  }

  final double progress;
  final Color accent;

  /// Curva continua de Vinyl Wave; `false` mantiene la onda de barras histórica.
  final bool smooth;
  late final Paint _playedPaint;
  late final Paint _pendingPaint;
  late final Paint _thumbPaint;
  late final Paint _thumbCorePaint;

  static const int _smoothSamples = 96;

  /// Onda determinista: no hay timers ni estados por fotograma.
  static double _smoothY(double t, double height) {
    final double envelope = 0.30 + 0.70 * math.sin(math.pi * t);
    final double wobble =
        math.sin(t * math.pi * 8) * 0.55 +
        math.sin(t * math.pi * 3 + 0.6) * 0.45;
    return height / 2 + wobble * envelope * height * 0.32;
  }

  void _paintSmoothWave(Canvas canvas, Size size) {
    final Path path = Path();
    for (int i = 0; i <= _smoothSamples; i++) {
      final double t = i / _smoothSamples;
      final double x = t * size.width;
      final double y = _smoothY(t, size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    _pendingPaint.strokeWidth = 2.5;
    canvas.drawPath(path, _pendingPaint);

    final double playedX = size.width * progress;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, playedX, size.height));
    _playedPaint.strokeWidth = 3.5;
    canvas.drawPath(path, _playedPaint);
    canvas.restore();

    final Offset thumb = Offset(playedX, _smoothY(progress, size.height));
    canvas.drawCircle(thumb, 6, _thumbPaint);
    canvas.drawCircle(thumb, 2.5, _thumbCorePaint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (smooth) {
      _paintSmoothWave(canvas, size);
      return;
    }

    const int bars = 64;
    const double gap = 2;
    final double barWidth = math.max(
      1.5,
      (size.width - gap * (bars - 1)) / bars,
    );
    final double playedX = size.width * progress;
    _playedPaint.strokeWidth = barWidth;
    _pendingPaint.strokeWidth = barWidth;

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

      final Paint paint = x + barWidth <= playedX
          ? _playedPaint
          : _pendingPaint;
      canvas.drawLine(
        Offset(x + barWidth / 2, top),
        Offset(x + barWidth / 2, top + height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.smooth != smooth;
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
          color: shuffle ? accent : context.inkAlpha(0.54),
          echoColor: accent,
        ),
        TactileIconButton(
          tooltip: 'Anterior',
          iconSize: 32,
          echoColor: accent,
          haptic: true,
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
          haptic: true,
          onPressed: controller.next,
          icon: Icons.skip_next_rounded,
        ),
        TactileIconButton(
          tooltip: _repeatLabel(repeat),
          onPressed: controller.cycleRepeat,
          icon: repeat == RepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          color: repeat == RepeatMode.off ? context.inkAlpha(0.54) : accent,
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
      child: MotionScale(
        scale: _pressed ? 1 - (0.03 + 0.07 * context.motion.intensity) : 1,
        category: MotionCategory.gestures,
        duration: const Duration(milliseconds: 130),
        child: GestureDetector(
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            widget.onPressed();
          },
          // La sombra ya no se interpola: un halo con Opacity y la escala del
          // botón bastan para la respuesta táctil sin repintar el blur.
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              IgnorePointer(
                child: MotionFade(
                  opacity: _pressed ? 0.55 : 1,
                  category: MotionCategory.gestures,
                  duration: const Duration(milliseconds: 240),
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.accent.withValues(alpha: 0.20),
                    ),
                  ),
                ),
              ),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color.lerp(widget.accent, context.ink, 0.22) ??
                          widget.accent,
                      widget.accent,
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.40),
                      blurRadius: 22,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: context.motion.duration(
                      const Duration(milliseconds: 200),
                    ),
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
                        ? SizedBox(
                            key: ValueKey<String>('buffering'),
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: ColorMath.onColor(widget.accent),
                            ),
                          )
                        : Icon(
                            widget.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            key: ValueKey<bool>(widget.playing),
                            size: 38,
                            color: ColorMath.onColor(widget.accent),
                          ),
                  ),
                ),
              ),
            ],
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

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        // Con ventana ancha se mantiene la composición original. Al reducirla
        // se compactan los huecos y, si apenas queda sitio, los controles
        // secundarios bajan a una segunda línea en lugar de asfixiar el riel.
        const double comfortableWidth = 560;
        const double compactWidth = 300;
        final bool stacked = width.isFinite && width < compactWidth;
        final bool compact =
            width.isFinite && width < comfortableWidth && !stacked;
        final double outerGap = compact ? 8 : 12;
        final double innerGap = compact || stacked ? 5 : 8;

        List<Widget> trailing() => <Widget>[
          if (!stacked) SizedBox(width: outerGap),
          _SpeedMenu(speed: speed, onChanged: controller.setSpeed),
          SizedBox(width: innerGap),
          _ABLoopButton(controller: controller, accent: accent),
          SizedBox(width: innerGap),
          _SleepMenu(controller: controller),
        ];

        Widget slider() => VolumeSlider(
          controller: controller,
          accent: accent,
          compact: compact || stacked,
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              slider(),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: trailing(),
              ),
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: slider()),
            ...trailing(),
          ],
        );
      },
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
    // El botón tiene el volumen a la izquierda y el ecualizador justo debajo.
    // 'over' + desplazamiento negativo abre el menú por encima de la fila.
    final int itemCount = 2 + ((a != null || b != null) ? 1 : 0);

    return PopupMenuButton<String>(
      tooltip: 'Repetidor A-B',
      position: PopupMenuPosition.over,
      offset: Offset(0, -(itemCount * kMinInteractiveDimension + 24)),
      icon: Icon(
        Icons.repeat_on_rounded,
        size: 20,
        color: active ? accent : context.inkAlpha(0.54),
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
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SleepPreference {
  const _SleepPreference(this.minutes, this.fadeSeconds);

  final int minutes;
  final int fadeSeconds;
}

class _SleepMenu extends ConsumerWidget {
  const _SleepMenu({required this.controller});

  final PlayerController controller;

  Future<_SleepPreference?> _askCustomSleep(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final SettingsService settings = ref.read(settingsServiceProvider);
    final TextEditingController minutes = TextEditingController(
      text: '${settings.sleepTimerDefaultMinutes}',
    );
    final TextEditingController fade = TextEditingController(
      text: '${settings.sleepFadeSeconds}',
    );
    try {
      return await showDialog<_SleepPreference>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text('Temporizador personalizado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: minutes,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: 'Minutos',
                  helperText: 'Entre 1 y 480',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fade,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: 'Fundido final (segundos)',
                  helperText: 'Entre 1 y 30',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final int value = int.tryParse(minutes.text.trim()) ?? 0;
                final int seconds = int.tryParse(fade.text.trim()) ?? 0;
                if (value < 1 || seconds < 1) return;
                Navigator.of(context).pop(
                  _SleepPreference(value.clamp(1, 480), seconds.clamp(1, 30)),
                );
              },
              child: Text('Aplicar'),
            ),
          ],
        ),
      );
    } finally {
      minutes.dispose();
      fade.dispose();
    }
  }

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
          case 'custom':
            unawaited(() async {
              final _SleepPreference? pref = await _askCustomSleep(
                context,
                ref,
              );
              if (pref == null || !context.mounted) return;
              await controller.setSleepPreferences(
                minutes: pref.minutes,
                fadeSeconds: pref.fadeSeconds,
              );
              controller.startSleepTimer(
                Duration(minutes: pref.minutes),
                fade: Duration(seconds: pref.fadeSeconds),
              );
            }());
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
        PopupMenuItem<String>(value: 'custom', child: Text('Personalizado…')),
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
          color: active ? context.accent : context.inkAlpha(0.54),
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
          Icon(Icons.bedtime_rounded, size: 14, color: context.inkAlpha(0.54)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              endsAtTrack || remaining == null
                  ? 'Se pausará al terminar la pista'
                  : 'Se pausará en ${Formatters.duration(remaining)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.inkAlpha(0.54)),
            ),
          ),
          TextButton(
            onPressed: controller.cancelSleepTimer,
            child: Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

/// Acceso rápido al ecualizador junto a los controles.
/// Las letras se abren desde la pestaña del panel inferior para no duplicar
/// el mismo botón dos veces en la pantalla. Las barras solo se mueven mientras
/// reproduce y el perfil de movimiento lo permite.
class _QuickActions extends ConsumerStatefulWidget {
  const _QuickActions({required this.accent, required this.playing});

  final Color accent;
  final bool playing;

  @override
  ConsumerState<_QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends ConsumerState<_QuickActions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bars = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// Se cachea fuera del builder: `context.motion` es barato, pero crear la
  /// dependencia 60 veces/s es innecesario.
  double _intensity = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _intensity = context.motion.intensity;
    final Duration duration = context.motion.duration(
      const Duration(milliseconds: 900),
      category: MotionCategory.ambient,
    );
    _bars.duration = duration == Duration.zero
        ? const Duration(milliseconds: 1)
        : duration;
    _sync();
  }

  @override
  void didUpdateWidget(covariant _QuickActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) _sync();
  }

  void _sync() {
    final bool animate = context.ambientMotionAllowed(playing: widget.playing);
    if (animate && !_bars.isAnimating) {
      _bars.repeat();
    } else if (!animate && _bars.isAnimating) {
      _bars.stop();
    }
  }

  @override
  void dispose() {
    _bars.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.accent;
    final bool pure = ref.watch(
      equalizerControllerProvider.select((s) => s.pure),
    );
    final output = ref.watch(
      audioOutputSelectionProvider.select((s) => s.state),
    );
    final ButtonStyle style = OutlinedButton.styleFrom(
      foregroundColor: accent,
      side: BorderSide(color: accent.withValues(alpha: 0.35)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
    final ButtonStyle pureStyle = OutlinedButton.styleFrom(
      foregroundColor: accent,
      side: BorderSide(color: accent.withValues(alpha: 0.9), width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: <Widget>[
        Tooltip(
          message: 'Salida actual: ${output.selected.label}',
          child: OutlinedButton.icon(
            onPressed: () => unawaited(AudioOutputSheet.show(context)),
            icon: const Icon(Icons.speaker_outlined, size: 18),
            label: const Text('Salida'),
            style: style,
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => Scaffold(
                appBar: AppBar(title: Text('Ecualizador')),
                body: const EqualizerScreen(),
              ),
            ),
          ),
          icon: SizedBox(
            width: 18,
            height: 18,
            child: AnimatedBuilder(
              animation: _bars,
              child: Icon(Icons.graphic_eq_rounded, size: 18),
              builder: (BuildContext context, Widget? child) {
                if (!_bars.isAnimating) return child ?? const SizedBox.shrink();
                final double phase = _bars.value;
                return CustomPaint(
                  painter: _EqualizerBarsPainter(
                    phase: phase,
                    color: accent,
                    intensity: _intensity,
                  ),
                );
              },
            ),
          ),
          label: Text('Ecualizador'),
          style: style,
        ),
        Tooltip(
          message: pure
              ? 'Bypass activo: sin ecualizador, sub-armónico ni limitador.'
              : 'Deja pasar el audio sin filtros; tu curva se conserva.',
          child: OutlinedButton.icon(
            onPressed: () =>
                ref.read(equalizerControllerProvider.notifier).togglePure(),
            icon: Icon(
              pure ? Icons.filter_alt_off : Icons.filter_alt_outlined,
              size: 18,
            ),
            label: Text(pure ? 'Puro activo' : 'Modo puro'),
            style: pure ? pureStyle : style,
          ),
        ),
      ],
    );
  }
}

class _EqualizerBarsPainter extends CustomPainter {
  const _EqualizerBarsPainter({
    required this.phase,
    required this.color,
    required this.intensity,
  });

  final double phase;
  final Color color;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    const int count = 3;
    final double width = size.width / (count * 2 - 1);
    final Paint paint = Paint()..color = color;
    for (int i = 0; i < count; i++) {
      final double wave = 0.5 + 0.5 * math.sin((phase * 2 * math.pi) + i * 1.7);
      final double height = size.height * (0.25 + 0.65 * wave * intensity);
      final double x = i * width * 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - height, width, height),
          Radius.circular(width / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EqualizerBarsPainter old) =>
      old.phase != phase || old.color != color || old.intensity != intensity;
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
    required this.lyricsVisible,
  });

  final Track track;
  final PlayerController controller;
  final Color accent;
  final int tab;
  final ValueChanged<int> onTabChanged;

  /// `null` hace que el panel ocupe todo el espacio disponible (modo ancho).
  final double? height;
  final VoidCallback onOpenLyrics;
  final bool lyricsVisible;

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

    // El panel hereda los tokens de la superficie compacta activa. `onPanel`
    // calcula tinta legible sobre ese fondo (oscuro o claro) en lugar de
    // asumir `context.ink`, que era ilegible cuando el velo era claro.
    final Color panelInk = context.onPanel;
    final Color idleInk = panelInk.withValues(alpha: 0.88);
    final Color segmentIdle = context.tokens.surface.withValues(alpha: 0.62);
    final Color segmentActive = accent.withValues(alpha: 0.26);
    final ThemeData theme = Theme.of(context);

    final Widget panel = PolarisSurface(
      padding: EdgeInsets.fromLTRB(12, 12, 12, fluid ? 0 : 8),
      borderRadius: 22,
      glowColor: accent,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Theme(
                  data: theme.copyWith(
                    segmentedButtonTheme: SegmentedButtonThemeData(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>(
                          (Set<WidgetState> states) =>
                              states.contains(WidgetState.selected)
                              ? segmentActive
                              : segmentIdle,
                        ),
                        foregroundColor: WidgetStateProperty.resolveWith<Color>(
                          (Set<WidgetState> states) =>
                              states.contains(WidgetState.selected)
                              ? panelInk
                              : idleInk,
                        ),
                        iconColor: WidgetStateProperty.resolveWith<Color>(
                          (Set<WidgetState> states) =>
                              states.contains(WidgetState.selected)
                              ? panelInk
                              : idleInk,
                        ),
                        side: WidgetStateProperty.all(
                          BorderSide(color: context.tokens.panelBorder),
                        ),
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        textStyle: WidgetStateProperty.all(
                          theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ) ??
                              TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  ),
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
                    selected: <int>{lyricsVisible ? 1 : 0},
                    showSelectedIcon: false,
                    onSelectionChanged: (Set<int> value) {
                      if (value.first == 1) {
                        if (!lyricsVisible) onOpenLyrics();
                      } else if (lyricsVisible) {
                        onOpenLyrics();
                      }
                      onTabChanged(0);
                    },
                  ),
                ),
              ),
              if (tab == 0)
                IconButton(
                  tooltip: 'Vaciar cola',
                  color: idleInk,
                  onPressed: queue.isEmpty ? null : controller.clearQueue,
                  icon: Icon(Icons.delete_sweep_outlined, size: 20),
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
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height!),
            child: panel,
          );
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
    final Color ink = context.onPanel;
    if (queue.isEmpty) {
      return Center(
        child: Text(
          'La cola está vacía',
          style: TextStyle(color: ink.withValues(alpha: 0.82)),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: EdgeInsets.only(bottom: padBottom),
      itemCount: queue.length,
      buildDefaultDragHandles: false,
      onReorderItem: (int from, int to) {
        unawaited(HapticFeedback.selectionClick());
        controller.moveInQueue(from, to);
      },
      scrollCacheExtent: const ScrollCacheExtent.pixels(300),
      proxyDecorator: (Widget child, int index, Animation<double> animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? widget) => Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: context.tokens.panelOverlay.withValues(alpha: 0.96),
            child: widget,
          ),
          child: child,
        );
      },
      itemBuilder: (BuildContext context, int i) {
        final Track track = queue[i];
        final bool current = i == index;
        final Widget tile = ListTile(
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
              color: ink,
            ),
          ),
          subtitle: Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: ink.withValues(alpha: 0.82)),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Semantics(
                label: 'Arrastrar para reordenar ${track.title}',
                child: ReorderableDragStartListener(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 18,
                      color: ink.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
              Text(
                Formatters.duration(track.duration),
                style: TextStyle(
                  fontSize: 11,
                  color: ink.withValues(alpha: 0.78),
                ),
              ),
              IconButton(
                tooltip: 'Quitar de la cola',
                color: ink.withValues(alpha: 0.88),
                icon: Icon(Icons.close_rounded, size: 16),
                onPressed: () => controller.removeFromQueue(i),
              ),
            ],
          ),
          onTap: () => controller.playAt(i),
        );

        return RepaintBoundary(
          key: ValueKey<int>(track.id),
          child: AnimatedContainer(
            duration: context.motion.duration(
              const Duration(milliseconds: 260),
            ),
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
          ),
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
  bool _ambient = true;
  Duration _scaledPeriod = _period;

  @override
  void initState() {
    super.initState();
    _window = ref.read(windowStateProvider);
    _backgrounded = _window!.value.backgrounded;
    final MotionConfig initial = ref.read(motionConfigProvider);
    _ambient = initial.ambient;
    _scaledPeriod = initial.duration(_period, category: MotionCategory.ambient);
    _window!.addListener(_onWindowChanged);
    ref.listen(motionConfigProvider, (_, MotionConfig next) {
      _scaledPeriod = next.duration(_period, category: MotionCategory.ambient);
      if (next.ambient != _ambient) {
        setState(() => _ambient = next.ambient);
      }
      _sync();
    });
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaledPeriod = context.motion.duration(
      _period,
      category: MotionCategory.ambient,
    );
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

  /// El ticker solo corre si hay sonido, ambiente activo y ventana visible.
  void _sync() {
    if (widget.playing &&
        _ambient &&
        !_backgrounded &&
        _scaledPeriod > Duration.zero) {
      // AnimationController exige una duración estrictamente positiva.
      final Duration period = _scaledPeriod == Duration.zero
          ? const Duration(microseconds: 1)
          : _scaledPeriod;
      if (_controller.duration != period) _controller.duration = period;
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
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: context.tokens.panelOverlay.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: widget.color.withValues(alpha: 0.35)),
            ),
          ),
          builder: (BuildContext context, Widget? child) => CustomPaint(
            foregroundPainter: _QueueWavePainter(
              phase: _controller.value,
              color: widget.color,
            ),
            child: child,
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
      duration: context.motion.duration(const Duration(milliseconds: 460)),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // El layout por defecto apila la pista saliente sobre la entrante; eso
      // produce el "ghost". Solo pintamos la entrante y conservamos el
      // fundido/deslazamiento/escala de la transición.
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) =>
          currentChild ?? const SizedBox.shrink(),
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
    required this.size,
    required this.onSeekFraction,
    required this.onPrevious,
    required this.onNext,
    required this.onLyrics,
    required this.onMinimize,
    this.nextTrack,
    this.previousTrack,
  });

  final Track track;
  final AppThemeConfig config;
  final Color accent;
  final bool playing;
  final double size;
  final ValueChanged<double> onSeekFraction;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLyrics;
  final VoidCallback onMinimize;

  /// Vecinos reales de la cola activa, para el preview del gesto horizontal.
  final Track? nextTrack;
  final Track? previousTrack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool ring =
        config.progressBarType == ProgressBarType.circularAroundArtwork;
    // El progreso se suscribe dentro del anillo: si se observara aquí, el tick
    // de posición (~5 Hz) reconstruiría la carátula, los gestos y el vinilo.

    // El anillo ocupa el 84 % interior: la carátula se ajusta para no
    // desbordar el círculo (el antiguo desajuste del estilo Vinilo).
    final double artSize = ring ? size * 0.84 : size;

    final ValueNotifier<WindowUiState> windowNotifier = ref.watch(
      windowStateProvider,
    );
    final bool paused = windowNotifier.value.backgrounded;
    final PlayerController controller = ref.read(
      playerControllerProvider.notifier,
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
          ArtworkShape.vinylWave => _VinylWaveArtwork(
            path: track.artworkPath,
            size: artSize,
            accent: accent,
            radius: config.artworkRadius,
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
        ? _CircularProgressRing(size: size, accent: accent, child: artwork)
        : artwork;

    // Preview plano (incluso si la carátula usa card3D): al arrastrar se ve
    // un adelanto limpio de la pista vecina sin perspectivas ni giros.
    Widget swipePreview(Track neighbor) => KeyedSubtree(
      key: ValueKey<String>('swipe-preview-${neighbor.id}'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ArtworkImage(
            path: neighbor.artworkPath,
            size: artSize * 0.72,
            shape: config.artworkShape == ArtworkShape.circleVinyl
                ? BoxShape.circle
                : BoxShape.rectangle,
            radius: BorderRadius.circular(config.artworkRadius),
            accent: accent,
          ),
          SizedBox(height: size * 0.035),
          Text(
            neighbor.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.inkAlpha(0.92),
            ),
          ),
          Text(
            neighbor.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: context.inkAlpha(0.60)),
          ),
        ],
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: ArtworkGestures(
        size: size,
        onSeekFraction: onSeekFraction,
        onPrevious: onPrevious,
        onNext: onNext,
        onLyrics: onLyrics,
        onMinimize: onMinimize,
        onVolumeDelta: (double fraction) {
          final double next = (controller.volumePercent + fraction * 100)
              .clamp(0, 100)
              .toDouble();
          unawaited(controller.setVolume(next));
        },
        accent: accent,
        seekEnabled: ring,
        playing: playing,
        paused: paused,
        nextPreview: nextTrack == null ? null : swipePreview(nextTrack!),
        previousPreview: previousTrack == null
            ? null
            : swipePreview(previousTrack!),
        child: RepaintBoundary(child: body),
      ),
    );
  }
}

/// Etapa de contenido del reproductor: carátula o letras expandidas.
///
/// Las letras ya no viven dentro del cuadro cuadrado de la carátula; cuando se
/// activan sustituyen a esta etapa completa. La barra de progreso y los controles
/// están fuera de este widget, por lo que nunca se cubren ni se reconstruyen.
class _PlayerStage extends ConsumerWidget {
  const _PlayerStage({
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
    this.expanded = false,
  });

  final Track track;
  final AppThemeConfig config;
  final Color accent;
  final bool playing;
  final bool showLyrics;

  /// Tamaño de la carátula cuando las letras están cerradas.
  final double size;
  final ValueChanged<double> onSeekFraction;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLyrics;
  final VoidCallback onCloseLyrics;
  final VoidCallback onMinimize;

  /// Las letras ocupan todo el hueco que reciben del layout superior.
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Posición en el orden activo: decide si la transición entra desde la
    // derecha (siguiente) o desde la izquierda (anterior), también en shuffle.
    final int position = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.index),
    );
    final List<Track> queue = ref.watch(
      playerControllerProvider.select(
        (PlayerUiState s) => s.playback.activeQueue,
      ),
    );
    final RepeatMode repeat = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.repeat),
    );

    // La vista previa usa la cola en su orden real (ya barajado si toca) y
    // respeta "repetir toda". El motor puede saltar pistas no reproducibles,
    // pero para un adelanto visual basta con el vecino inmediato.
    Track? nextTrack;
    Track? previousTrack;
    if (queue.isNotEmpty) {
      final int at = position.clamp(0, queue.length - 1);
      if (repeat == RepeatMode.all) {
        nextTrack = queue[(at + 1) % queue.length];
        previousTrack = queue[(at - 1 + queue.length) % queue.length];
      } else {
        if (at + 1 < queue.length) nextTrack = queue[at + 1];
        if (at - 1 >= 0) previousTrack = queue[at - 1];
      }
    }

    final Widget child = showLyrics
        ? KeyedSubtree(
            // La clave incluye la pista: sin ella el State de LyricsPanel se
            // reutiliza al cambiar de canción y conserva scroll/índice viejo.
            key: ValueKey<String>('artwork-lyrics-${track.id}'),
            child: ExpandedLyricsView(
              track: track,
              accent: accent,
              onClose: onCloseLyrics,
            ),
          )
        : KeyedSubtree(
            key: ValueKey<String>(
              'artwork-${track.id}-${config.artworkShape.name}',
            ),
            child: _ArtworkStage(
              track: track,
              config: config,
              accent: accent,
              playing: playing,
              size: size,
              onSeekFraction: onSeekFraction,
              onPrevious: onPrevious,
              onNext: onNext,
              onLyrics: onLyrics,
              onMinimize: onMinimize,
              nextTrack: nextTrack,
              previousTrack: previousTrack,
            ),
          );

    final Widget stage = _CinematicSwitcher(position: position, child: child);
    return expanded ? SizedBox.expand(child: stage) : stage;
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
    // No se llama a `existsSync()`: es E/S síncrona en el hilo de UI y se
    // ejecutaba por cada fila de la cola. `errorBuilder` cubre archivos
    // movidos, borrados o corruptos sin bloquear el scroll.
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
          color: context.inkAlpha(0.85),
          size: size * 0.36,
        ),
      );
    } else {
      final double ratio = MediaQuery.devicePixelRatioOf(context);
      // La carátula principal se ve grande, pero 600 px son suficientes para
      // un tile de ~300 dp incluso a 2x; decodizar 2048 px multiplicaba la RAM
      // por cuatro sin diferencias apreciables en pantalla.
      final int decodeWidth = (size * ratio).round().clamp(48, 600);
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
                  color: context.inkAlpha(0.8),
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
              context.inkAlpha(0.05),
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.28),
              blurRadius: 40,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: context.tokens.shadowColor.withValues(alpha: 0.45),
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

/// Vinyl Wave: tapa redondeada al frente y disco asomando por la derecha.
/// El detalle es estático (sin `AnimationController`): no añade trabajo por
/// fotograma y, por tanto, no interfiere con los perfiles de movimiento.
class _VinylWaveArtwork extends StatelessWidget {
  const _VinylWaveArtwork({
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
    final double cover = size * 0.86;
    final double disc = size * 0.66;
    final BorderRadius coverRadius = BorderRadius.circular(radius);

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: size * 0.66 - disc / 2,
              top: (size - disc) / 2,
              child: Container(
                width: disc,
                height: disc,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.24),
                      blurRadius: 26,
                    ),
                    BoxShadow(
                      color: context.tokens.shadowColor.withValues(alpha: 0.50),
                      blurRadius: 20,
                      offset: const Offset(8, 12),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: disc,
                    height: disc,
                    child: CustomPaint(
                      painter: _VinylPeekPainter(
                        accent: accent,
                        ink: context.inkAlpha(0.85),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: (size - cover) / 2,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  borderRadius: coverRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      accent.withValues(alpha: 0.50),
                      context.inkAlpha(0.05),
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.26),
                      blurRadius: 32,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: context.tokens.shadowColor.withValues(alpha: 0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: _ArtworkImage(
                  path: path,
                  size: cover - 10,
                  shape: BoxShape.rectangle,
                  radius: BorderRadius.circular(math.max(radius - 5, 4)),
                  accent: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Surcos y etiqueta del disco que asoma. Reutiliza dos `Paint` por repintado.
class _VinylPeekPainter extends CustomPainter {
  _VinylPeekPainter({required this.accent, required this.ink}) {
    _discPaint = Paint()..color = const Color(0xFF0B0B10);
    _groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = ink.withValues(alpha: 0.16);
    _labelPaint = Paint()..color = accent;
    _holePaint = Paint()..color = const Color(0xFF0B0B10);
  }

  final Color accent;
  final Color ink;
  late final Paint _discPaint;
  late final Paint _groovePaint;
  late final Paint _labelPaint;
  late final Paint _holePaint;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double r = math.min(size.width, size.height) / 2;
    canvas.drawCircle(center, r, _discPaint);
    for (int i = 0; i < 6; i++) {
      canvas.drawCircle(center, r * (0.44 + i * 0.085), _groovePaint);
    }
    canvas.drawCircle(center, r * 0.31, _labelPaint);
    canvas.drawCircle(center, r * 0.055, _holePaint);
  }

  @override
  bool shouldRepaint(covariant _VinylPeekPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.ink != ink;
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
            color: context.inkAlpha(0.05),
            border: Border.all(color: context.inkAlpha(0.10)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.24),
                blurRadius: 46,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: context.tokens.shadowColor.withValues(alpha: 0.55),
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

/// Geometría derivada de un único centro: disco, surcos, etiqueta y brazo
/// comparten proporciones acotadas para no recortarse a ninguna resolución.
class _VinylLayout {
  const _VinylLayout({
    required this.box,
    required this.disc,
    required this.radius,
    required this.border,
    required this.label,
    required this.grooveInner,
    required this.grooveOuter,
    required this.highlightRadius,
    required this.highlightStroke,
    required this.highlightBlur,
    required this.pivot,
    required this.elbow,
    required this.stylus,
    required this.pivotRadius,
    required this.armWidth,
    required this.headLength,
    required this.headWidth,
  });

  final double box;
  final double disc;
  final double radius;
  final double border;
  final double label;
  final double grooveInner;
  final double grooveOuter;
  final double highlightRadius;
  final double highlightStroke;
  final double highlightBlur;
  final Offset pivot;
  final Offset elbow;
  final Offset stylus;
  final double pivotRadius;
  final double armWidth;
  final double headLength;
  final double headWidth;

  static _VinylLayout compute(double box) {
    final double size = box.isFinite && box > 0 ? box : 1;
    final double pad = (size * 0.02).clamp(3.0, 8.0);
    final double disc = size - 2 * pad;
    final double radius = disc / 2;
    final Offset center = Offset(size / 2, size / 2);

    final double border = (disc * 0.004).clamp(1.0, 2.0);
    final double label = disc * 0.44;
    final double labelRadius = label / 2;
    final double grooveInner = labelRadius + math.max(1.5, disc * 0.012);
    final double grooveOuter = radius - border - math.max(3, disc * 0.035);

    final double stroke = (disc * 0.02).clamp(2, 8);
    final double blur = (disc * 0.015).clamp(1.5, 6);
    final double highlight = math.min(
      disc * 0.43,
      radius - border - stroke / 2 - 2 * blur,
    );

    return _VinylLayout(
      box: size,
      disc: disc,
      radius: radius,
      border: border,
      label: label,
      grooveInner: grooveInner,
      grooveOuter: grooveOuter,
      highlightRadius: math.max(1, highlight),
      highlightStroke: stroke,
      highlightBlur: blur,
      pivot: center + Offset(0.58 * radius, -0.58 * radius),
      elbow: center + Offset(0.72 * radius, -0.18 * radius),
      stylus: center + Offset(grooveInner + disc * 0.02, 0),
      pivotRadius: (radius * 0.09).clamp(3, 10),
      armWidth: math.max(2, radius * 0.045),
      headLength: radius * 0.18,
      headWidth: radius * 0.08,
    );
  }
}

/// Vinilo con surcos, etiqueta central y brazo, centrado y sin recortes.
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
  static const Duration _period = Duration(seconds: 14);

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: _period,
  );

  /// La geometría solo depende del tamaño. Reutilizar la misma instancia evita
  /// que `shouldRepaint` compare por identidad y repinte los surcos con blur
  /// en cada reconstrucción del padre.
  _VinylLayout? _layout;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Duration duration = context.motion.duration(
      _period,
      category: MotionCategory.ambient,
    );
    _spin.duration = duration == Duration.zero
        ? const Duration(milliseconds: 1)
        : duration;
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
    final bool animate =
        context.ambientMotionAllowed(playing: widget.playing) && !widget.paused;
    if (animate && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!animate && _spin.isAnimating) {
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
    if (_layout == null || _layout!.box != widget.size) {
      _layout = _VinylLayout.compute(widget.size);
    }
    final _VinylLayout v = _layout!;
    final Color ink = context.inkAlpha(0.78);

    return Center(
      child: SizedBox(
        width: v.box,
        height: v.box,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Container(
              width: v.disc,
              height: v.disc,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: <Color>[
                    Color(0xFF232323),
                    Color(0xFF101010),
                    Color(0xFF040404),
                  ],
                  stops: <double>[0, 0.72, 1],
                ),
                border: Border.all(
                  color: ink.withValues(alpha: 0.35),
                  width: v.border,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.28),
                    blurRadius: (v.disc * 0.26).clamp(18.0, 48.0),
                    spreadRadius: (v.disc * 0.01).clamp(1.0, 4.0),
                  ),
                  BoxShadow(
                    color: context.tokens.shadowColor.withValues(alpha: 0.55),
                    blurRadius: (v.disc * 0.14).clamp(12.0, 30.0),
                    offset: Offset(0, v.disc * 0.045),
                  ),
                ],
              ),
            ),
            IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.square(v.box),
                  painter: _VinylGroovesPainter(layout: v, ink: ink),
                ),
              ),
            ),
            IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.square(v.box),
                  painter: _VinylTonearmPainter(
                    layout: v,
                    ink: ink,
                    accent: widget.accent,
                  ),
                ),
              ),
            ),
            RepaintBoundary(
              child: RotationTransition(
                turns: _spin,
                child: SizedBox(
                  width: v.label,
                  height: v.label,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      ClipOval(
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox(
                          width: v.label,
                          height: v.label,
                          child: _ArtworkImage(
                            path: widget.path,
                            size: v.label,
                            shape: BoxShape.circle,
                            accent: widget.accent,
                          ),
                        ),
                      ),
                      Container(
                        width: v.label * 0.10,
                        height: v.label * 0.10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0B0B0B),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: v.label * 0.035,
                        height: v.label * 0.035,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3A3A3A),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
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
  const _VinylGroovesPainter({required this.layout, required this.ink});

  final _VinylLayout layout;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (layout.disc * 0.0025).clamp(0.6, 1.2);

    const int count = 18;
    final double step = (layout.grooveOuter - layout.grooveInner) / (count - 1);
    for (int i = 0; i < count; i++) {
      paint.color = ink.withValues(alpha: i.isEven ? 0.12 : 0.07);
      canvas.drawCircle(center, layout.grooveInner + step * i, paint);
    }

    final Paint highlight = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        <Color>[
          ink.withValues(alpha: 0.18),
          Colors.transparent,
          ink.withValues(alpha: 0.08),
        ],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = layout.highlightStroke
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        layout.highlightBlur,
      );
    canvas.drawCircle(center, layout.highlightRadius, highlight);
  }

  @override
  bool shouldRepaint(covariant _VinylGroovesPainter old) =>
      old.layout != layout || old.ink != ink;
}

class _VinylTonearmPainter extends CustomPainter {
  const _VinylTonearmPainter({
    required this.layout,
    required this.ink,
    required this.accent,
  });

  final _VinylLayout layout;
  final Color ink;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint arm = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = layout.armWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawCircle(
      layout.pivot,
      layout.pivotRadius,
      Paint()
        ..color = accent.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      layout.pivot,
      layout.pivotRadius * 0.42,
      Paint()..color = const Color(0xFF101014),
    );
    canvas.drawLine(layout.pivot, layout.elbow, arm);
    canvas.drawLine(layout.elbow, layout.stylus, arm);

    final Offset back = layout.stylus - const Offset(1, 0) * layout.headLength;
    final Paint head = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = layout.headWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(back, layout.stylus, head);
    canvas.drawCircle(
      layout.stylus,
      layout.headWidth * 0.55,
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(covariant _VinylTonearmPainter old) =>
      old.layout != layout || old.ink != ink || old.accent != accent;
}

/// Anillo de progreso que envuelve la carátula. La búsqueda y los deslizamientos
/// los gestiona [ArtworkGestures] por encima de todo el conjunto.
/// Anillo aislado: solo este widget se reconstruye con el tick de posición.
class _CircularProgressRing extends ConsumerWidget {
  const _CircularProgressRing({
    required this.size,
    required this.accent,
    required this.child,
  });

  final double size;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double progress = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.progress),
    );
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            RepaintBoundary(
              child: CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(
                  progress: progress,
                  accent: accent,
                  ink: context.ink,
                ),
              ),
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
  _RingPainter({
    required this.progress,
    required this.accent,
    required this.ink,
  });

  final double progress;
  final Color accent;
  final Color ink;

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
      ..color = ink.withValues(alpha: 0.18);
    canvas.drawCircle(center, radius, base);

    final double sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    // Resplandor sin MaskFilter: un trazo ancho translúcido da la misma
    // sensación luminosa sin pagar un filtro de desenfoque en cada tick.
    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.20);
    canvas.drawArc(rect, start, sweep, false, glow);

    final Paint active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = accent;
    canvas.drawArc(rect, start, sweep, false, active);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.ink != ink;
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
          duration: context.motion.duration(const Duration(milliseconds: 800)),
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
                  background.withValues(alpha: 0.55),
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
        duration: context.motion.duration(const Duration(milliseconds: 800)),
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
