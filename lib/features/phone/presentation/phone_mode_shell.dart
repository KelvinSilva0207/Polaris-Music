import 'dart:math' as math;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/playback_state.dart';
import '../../../core/models/track.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/compact_style_provider.dart';
import '../../../core/services/window_service.dart';
import '../../../core/theme/compact_style_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/compact_surface.dart';
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
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

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
        final bool active = playing && !state.backgrounded;
        if (active && !_spin.isAnimating) {
          _spin.repeat();
        } else if (!active && _spin.isAnimating) {
          _spin.stop();
        }
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
                          track: track,
                          accent: accent,
                          rotation: _spin,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        track?.title ?? 'Polaris Music',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track?.artist ?? 'Tu universo sonoro',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _PhoneProgress(),
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
                              color: Colors.white60,
                            ),
                            Expanded(
                              child: Slider(
                                value: volume.clamp(0.0, 100.0).toDouble(),
                                max: 100,
                                onChanged: controller.setVolume,
                              ),
                            ),
                            Text(
                              '${volume.round()}%',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white38,
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
              icon: const Icon(Icons.expand_more_rounded, size: 20),
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
    required this.track,
    required this.accent,
    required this.rotation,
  });

  final Track? track;
  final Color accent;
  final Animation<double> rotation;

  @override
  Widget build(BuildContext context) {
    final double size = math.min(MediaQuery.sizeOf(context).width - 92, 230);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
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
            child: ClipOval(
              child: track == null
                  ? Container(
                      width: size,
                      height: size,
                      color: Colors.white.withValues(alpha: 0.06),
                      child: Icon(
                        Icons.music_note_rounded,
                        size: size * 0.34,
                        color: Colors.white54,
                      ),
                    )
                  : TrackArtwork(
                      path: track!.artworkPath,
                      size: size,
                      radius: size / 2,
                    ),
            ),
          ),
          Container(
            width: size * 0.11,
            height: size * 0.11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: configSurface(context),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
          ),
        ],
      ),
    );
  }

  Color configSurface(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
}

class _PhoneProgress extends ConsumerWidget {
  const _PhoneProgress();

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
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
              Text(
                Formatters.duration(duration),
                style: const TextStyle(fontSize: 10, color: Colors.white38),
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
              foregroundColor: Colors.black,
              elevation: 0,
            ),
            child: buffering
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.black,
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
        duration: const Duration(milliseconds: 220),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? accent.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: active
                ? accent.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Icon(
          icon,
          size: size * 0.46,
          color: active ? accent : Colors.white70,
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
          color: Colors.white.withValues(alpha: 0.07),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 22, color: accent),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 10.5, color: Colors.white60),
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
