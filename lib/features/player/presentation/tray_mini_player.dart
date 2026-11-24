import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../../core/providers/compact_style_provider.dart';
import '../../../core/theme/color_math.dart';
import '../../../core/theme/compact_style_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/compact_surface.dart';
import '../../../shared/widgets/track_artwork.dart';
import '../domain/player_controller.dart';
import 'player_providers.dart';

/// Único hijo de la mini ventana que sigue el tick de posición.
class _TrayProgress extends ConsumerWidget {
  const _TrayProgress({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double progress = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.progress),
    );
    if (progress <= 0) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: 2.5,
        backgroundColor: color.withValues(alpha: 0.12),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

/// Carátula y textos: se reconstruyen solo cuando cambia la pista.
class _TrayTrackInfo extends ConsumerWidget {
  const _TrayTrackInfo({required this.style});

  final ResolvedCompactStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Track? track = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.track),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TrackArtwork(
          key: ValueKey<int>(track?.id ?? 0),
          path: track?.artworkPath,
          size: 52,
          radius: style.artworkRadius(style.radius * 0.55),
        ),
        const SizedBox(width: 10),
      ],
    );
  }
}

/// Etiquetas de la pista, aisladas de los controles y del volumen.
class _TrayTitles extends ConsumerWidget {
  const _TrayTitles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Track? track = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.track),
    );
    return Column(
      key: ValueKey<int>(track?.id ?? 0),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          track?.title ?? 'Polaris en espera',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 1),
        Text(
          track?.artist ?? 'Elige una canción desde la biblioteca',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, color: context.inkAlpha(0.60)),
        ),
      ],
    );
  }
}

/// Transporte: solo reacciona a `playing`/`buffering`, no al tick de posición
/// ni al volumen.
class _TrayTransport extends ConsumerWidget {
  const _TrayTransport({required this.style, required this.onOpen});

  final ResolvedCompactStyle style;
  final VoidCallback onOpen;

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
    final PlayerController controller = ref.read(
      playerControllerProvider.notifier,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _MiniButton(
          icon: Icons.skip_previous_rounded,
          tooltip: 'Anterior',
          onTap: controller.previous,
        ),
        SizedBox(
          width: 38,
          height: 38,
          child: FilledButton(
            onPressed: controller.togglePlay,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              backgroundColor: style.accent,
              foregroundColor: ColorMath.onColor(style.accent),
            ),
            child: buffering
                ? SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ColorMath.onColor(style.accent),
                    ),
                  )
                : Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 23,
                  ),
          ),
        ),
        _MiniButton(
          icon: Icons.skip_next_rounded,
          tooltip: 'Siguiente',
          onTap: controller.next,
        ),
        const SizedBox(width: 4),
        _MiniButton(
          icon: Icons.open_in_full_rounded,
          tooltip: 'Abrir ventana principal',
          onTap: onOpen,
        ),
      ],
    );
  }
}

/// El volumen tiene su propia suscripción: arrastrar el slider no repinta
/// carátula, textos ni transporte.
class _TrayVolume extends ConsumerWidget {
  const _TrayVolume({required this.style});

  final ResolvedCompactStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double volume = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.volume),
    );
    final PlayerController controller = ref.read(
      playerControllerProvider.notifier,
    );

    return Row(
      children: <Widget>[
        Icon(
          volume <= 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          size: 15,
          color: context.inkAlpha(0.54),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              activeTrackColor: style.volumeColor,
              thumbColor: style.volumeColor,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
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
          style: TextStyle(fontSize: 10, color: context.inkAlpha(0.38)),
        ),
      ],
    );
  }
}

/// Cuerpo de la mini ventana cuando hay pista. Cada bloque tiene su propio
/// [RepaintBoundary] para que un cambio aislado no invalide el panel completo.
class _TrayBody extends StatelessWidget {
  const _TrayBody({
    required this.style,
    required this.onOpen,
    required this.onHide,
  });

  final ResolvedCompactStyle style;
  final VoidCallback onOpen;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              RepaintBoundary(child: _TrayTrackInfo(style: style)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    RepaintBoundary(child: _TrayTitles()),
                    const SizedBox(height: 2),
                    RepaintBoundary(
                      child: _TrayTransport(style: style, onOpen: onOpen),
                    ),
                  ],
                ),
              ),
              _MiniButton(
                icon: Icons.close_rounded,
                tooltip: 'Ocultar en la bandeja',
                onTap: onHide,
              ),
            ],
          ),
          const SizedBox(height: 2),
          RepaintBoundary(child: _TrayVolume(style: style)),
        ],
      ),
    );
  }
}

/// Mini reproductor de bandeja.
///
/// Es la misma ventana en `WindowMode.mini`: compacta, siempre encima, sin
/// entrada en la barra de tareas y con el diseño guardado para esta superficie.
class TrayMiniPlayer extends ConsumerWidget {
  const TrayMiniPlayer({super.key, required this.onOpen, required this.onHide});

  final VoidCallback onOpen;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Un bool evita reaccionar a actualizaciones de metadatos de la misma pista:
    // el panel solo se rehace cuando aparece o desaparece la pista.
    final bool hasTrack = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.hasTrack),
    );
    final CompactStyleConfig style = ref.watch(
      compactStyleProvider(CompactSurface.mini),
    );
    final ResolvedCompactStyle resolved = style.resolve(context.tokens);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: CompactPanel(
          style: resolved,
          padding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              RepaintBoundary(
                child: _TrayProgress(color: resolved.progressColor),
              ),
              if (!hasTrack)
                _EmptyState(
                  accent: resolved.accent,
                  onOpen: onOpen,
                  onHide: onHide,
                )
              else
                _TrayBody(style: resolved, onOpen: onOpen, onHide: onHide),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.accent,
    required this.onOpen,
    required this.onHide,
  });

  final Color accent;
  final VoidCallback onOpen;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 10, 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.14),
                border: Border.all(color: accent.withValues(alpha: 0.45)),
              ),
              child: Icon(Icons.music_note_rounded, color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Polaris en espera',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Elige una canción desde la biblioteca',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: context.inkAlpha(0.60),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onOpen, child: const Text('Abrir')),
            _MiniButton(
              icon: Icons.close_rounded,
              tooltip: 'Ocultar en la bandeja',
              onTap: onHide,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 17, color: context.inkAlpha(0.70)),
        ),
      ),
    );
  }
}
