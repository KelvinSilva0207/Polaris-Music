import 'dart:math' as math;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/playback_state.dart';
import '../../../core/models/track.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/compact_style_provider.dart';
import '../../../core/services/window_service.dart';
import '../../../core/theme/color_math.dart';
import '../../../core/theme/compact_style_config.dart';
import '../../../core/theme/motion_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/compact_surface.dart';
import '../../../shared/widgets/motion_scope.dart';
import '../../../shared/widgets/polaris_logo.dart';
import '../../../shared/widgets/track_artwork.dart';
import '../../player/domain/player_controller.dart';
import '../../player/presentation/player_providers.dart';

/// Modo teléfono de escritorio.
///
/// Reproduce la estética vertical y compacta del móvil (tarjetas circulares,
/// vidrio y acentos) pero acoplada al lateral derecho de la pantalla. Comparte
/// el mismo motor y los mismos servicios que la ventana principal.
class PhoneModeShell extends ConsumerStatefulWidget {
  const PhoneModeShell({super.key});

  @override
  ConsumerState<PhoneModeShell> createState() => _PhoneModeShellState();
}

class _PhoneModeShellState extends ConsumerState<PhoneModeShell>
    with SingleTickerProviderStateMixin {
  static const Duration _spinPeriod = Duration(seconds: 18);

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: _spinPeriod,
  );
  bool? _spinActive;

  /// Arranca/para el vinilo FUERA de la fase de build: `repeat()` notifica a los
  /// listeners y hacerlo dentro de `build` puede provocar reconstrucciones
  /// anidadas. El `child` del builder siempre existe, así que nunca se monta el
  /// `SizedBox.shrink()` de respaldo.
  void _syncSpin(bool active) {
    if (_spinActive == active) return;
    _spinActive = active;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (active) {
        if (!_spin.isAnimating) _spin.repeat();
      } else if (_spin.isAnimating) {
        _spin.stop();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Duration duration = context.motion.duration(
      _spinPeriod,
      category: MotionCategory.ambient,
    );
    _spin.duration = duration == Duration.zero
        ? const Duration(microseconds: 1)
        : duration;
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Track? track = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.track),
    );
    final bool playing = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playing),
    );
    final bool buffering = ref.watch(
      playerControllerProvider.select(
        (PlayerUiState s) => s.playback.buffering,
      ),
    );
    final double volume = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.volume),
    );
    final CompactStyleConfig style = ref.watch(
      compactStyleProvider(CompactSurface.phone),
    );
    final PolarisTokens tokens = context.tokens;
    final ResolvedCompactStyle resolved = style.resolve(tokens);
    final Color accent = resolved.accent;

    final PlayerController controller = ref.read(
      playerControllerProvider.notifier,
    );

    // El vinilo deja de girar cuando la ventana pasa a segundo plano, pero el
    // reproductor sigue sonando: el estado de audio y el de UI son independientes.
    return ValueListenableBuilder<WindowUiState>(
      valueListenable: ref.watch(windowStateProvider),
      builder: (BuildContext context, WindowUiState state, Widget? child) {
        final bool active =
            playing &&
            context.ambientMotionAllowed(playing: true) &&
            !state.backgrounded;
        _syncSpin(active);
        return child ?? const SizedBox.shrink();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color.lerp(resolved.background, accent, 0.30) ??
                    resolved.background,
                resolved.background,
                Color.lerp(resolved.background, accent, 0.14) ??
                    resolved.background,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: <Widget>[
                _PhoneTopBar(accent: accent, style: resolved),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                    children: <Widget>[
                      const SizedBox(height: 4),
                      Center(
                        child: _PhoneArtwork(
                          key: ValueKey<int>(track?.id ?? 0),
                          track: track,
                          accent: accent,
                          background: resolved.background,
                          rotation: _spin,
                          shape: resolved.tokens.artworkShape,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        track?.title ?? 'Polaris Music',
                        key: ValueKey<String>('phone-title-${track?.id ?? 0}'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track?.artist ?? 'Tu universo sonoro',
                        key: ValueKey<String>('phone-artist-${track?.id ?? 0}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.inkAlpha(0.60),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PhoneProgress(color: resolved.progressColor),
                      const SizedBox(height: 8),
                      _PhoneControls(
                        playing: playing,
                        buffering: buffering,
                        accent: accent,
                        controller: controller,
                      ),
                      const SizedBox(height: 18),
                      _GlassCard(
                        style: resolved,
                        child: Row(
                          children: <Widget>[
                            Icon(
                              volume <= 0
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              size: 18,
                              color: context.inkAlpha(0.60),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  activeTrackColor: resolved.volumeColor,
                                  thumbColor: resolved.volumeColor,
                                  overlayColor: resolved.volumeColor.withValues(
                                    alpha: 0.18,
                                  ),
                                ),
                                child: Slider(
                                  value: volume.clamp(0.0, 100.0).toDouble(),
                                  max: 100,
                                  onChanged: controller.setVolume,
                                ),
                              ),
                            ),
                            Text(
                              '${volume.round()}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.inkAlpha(0.38),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _QuickActions(accent: accent),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneTopBar extends ConsumerWidget {
  const _PhoneTopBar({required this.accent, required this.style});

  final Color accent;
  final ResolvedCompactStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(windowServiceProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: CompactPanel(
        style: style,
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        child: Row(
          children: <Widget>[
            const PolarisLogo(size: 22, glow: true),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Polaris · Teléfono',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Minimizar a la bandeja',
              onPressed: window.minimizeToTray,
              icon: Icon(Icons.expand_more_rounded, size: 20),
            ),
            IconButton(
              tooltip: 'Abrir ventana principal',
              onPressed: window.restoreNormal,
              icon: Icon(Icons.open_in_full_rounded, size: 18, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneArtwork extends StatelessWidget {
  const _PhoneArtwork({
    super.key,
    required this.track,
    required this.accent,
    required this.background,
    required this.rotation,
    required this.shape,
  });

  final Track? track;
  final Color accent;
  final Color background;
  final Animation<double> rotation;
  final ArtworkShape shape;

  @override
  Widget build(BuildContext context) {
    final double size = math.min(MediaQuery.sizeOf(context).width - 92, 230);
    final bool vinyl = shape == ArtworkShape.circleVinyl;
    final double radius = vinyl
        ? size / 2
        : switch (shape) {
            ArtworkShape.card3D => size * 0.22,
            _ => size * 0.14,
          };
    final Widget artwork = track == null
        ? Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  accent.withValues(alpha: 0.42),
                  background.withValues(alpha: 0.92),
                ],
              ),
            ),
            child: Icon(
              Icons.music_note_rounded,
              size: size * 0.34,
              color: context.inkAlpha(0.88),
            ),
          )
        : TrackArtwork(path: track!.artworkPath, size: size, radius: radius);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              shape: vinyl ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: vinyl ? null : BorderRadius.circular(radius),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.38),
                  blurRadius: 44,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          RotationTransition(
            turns: rotation,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(vinyl ? size / 2 : radius),
              child: artwork,
            ),
          ),
          if (vinyl)
            Container(
              width: size * 0.11,
              height: size * 0.11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: background,
                border: Border.all(color: accent.withValues(alpha: 0.55)),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhoneProgress extends ConsumerWidget {
  const _PhoneProgress({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Duration position = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.position),
    );
    final Duration duration = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.duration),
    );
    final controller = ref.read(playerControllerProvider.notifier);
    final double total = duration.inMilliseconds.toDouble();
    final double current = total <= 0
        ? 0
        : position.inMilliseconds.toDouble().clamp(0, total);

    return Column(
      children: <Widget>[
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: color,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.18),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: total <= 0 ? 0 : current,
            max: total <= 0 ? 1 : total,
            onChanged: total <= 0
                ? null
                : (double value) =>
                      controller.seek(Duration(milliseconds: value.round())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                Formatters.duration(position),
                style: TextStyle(fontSize: 10, color: context.inkAlpha(0.38)),
              ),
              Text(
                Formatters.duration(duration),
                style: TextStyle(fontSize: 10, color: context.inkAlpha(0.38)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhoneControls extends ConsumerWidget {
  const _PhoneControls({
    required this.playing,
    required this.buffering,
    required this.accent,
    required this.controller,
  });

  final bool playing;
  final bool buffering;
  final Color accent;
  final PlayerController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dynamic shuffle = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.shuffle),
    );
    final dynamic repeat = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.repeat),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _RoundAction(
          icon: Icons.shuffle_rounded,
          active: shuffle == true,
          accent: accent,
          onTap: controller.toggleShuffle,
        ),
        const SizedBox(width: 12),
        _RoundAction(
          icon: Icons.skip_previous_rounded,
          accent: accent,
          size: 44,
          onTap: controller.previous,
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 66,
          height: 66,
          child: FilledButton(
            onPressed: controller.togglePlay,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              backgroundColor: accent,
              foregroundColor: ColorMath.onColor(accent),
              elevation: 0,
            ),
            child: buffering
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: ColorMath.onColor(accent),
                    ),
                  )
                : Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 36,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        _RoundAction(
          icon: Icons.skip_next_rounded,
          accent: accent,
          size: 44,
          onTap: controller.next,
        ),
        const SizedBox(width: 12),
        _RoundAction(
          icon: repeat == RepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          active: repeat != RepeatMode.off,
          accent: accent,
          onTap: controller.cycleRepeat,
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.accent,
    required this.onTap,
    this.active = false,
    this.size = 38,
  });

  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: context.motion.duration(const Duration(milliseconds: 220)),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? accent.withValues(alpha: 0.22)
              : context.inkAlpha(0.06),
          border: Border.all(
            color: active
                ? accent.withValues(alpha: 0.7)
                : context.inkAlpha(0.08),
          ),
        ),
        child: Icon(
          icon,
          size: size * 0.46,
          color: active ? accent : context.inkAlpha(0.70),
        ),
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(windowServiceProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _QuickCard(
          icon: Icons.web_asset_rounded,
          label: 'Ventana',
          accent: accent,
          onTap: window.restoreNormal,
        ),
        _QuickCard(
          icon: Icons.apps_rounded,
          label: 'Normal',
          accent: accent,
          onTap: () async {
            await window.setMode(WindowMode.normal);
            await window.restoreNormal();
          },
        ),
        _QuickCard(
          icon: Icons.expand_more_rounded,
          label: 'Bandeja',
          accent: accent,
          onTap: window.minimizeToTray,
        ),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: context.inkAlpha(0.07),
          border: Border.all(color: context.inkAlpha(0.08)),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 22, color: accent),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 10.5, color: context.inkAlpha(0.60)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.style, required this.child});

  final ResolvedCompactStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CompactPanel(
      style: style,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: child,
    );
  }
}
