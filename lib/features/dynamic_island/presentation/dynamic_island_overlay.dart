// La isla se mueve con el puente "legacy" de window_manager, igual que la
// barra de título. El aviso de deprecación es intencional.
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/legacy.dart';

import '../../../core/models/track.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/compact_style_provider.dart';
import '../../../core/services/window_service.dart';
import '../../../core/theme/compact_style_config.dart';
import '../../../core/theme/motion_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/compact_surface.dart';
import '../../../shared/widgets/motion_scope.dart';
import '../../../shared/widgets/polaris_logo.dart';
import '../../../shared/widgets/track_artwork.dart';
import '../domain/dynamic_island_controller.dart';
import '../../player/domain/player_controller.dart';
import '../../player/presentation/player_providers.dart';
import 'island_providers.dart';

/// Cápsula flotante siempre encima.
///
/// El fondo de la ventana es transparente y el [CompactPanel] dibuja una
/// cápsula completa, evitando el rectángulo gris/negro que aparecía cuando el
/// tema global pintaba el área de la ventana. En Windows se arrastra desde el
/// área del título; al pasar el ratón crecen la carátula y los controles.
class IslandWindow extends ConsumerStatefulWidget {
  const IslandWindow({
    super.key,
    required this.onRestore,
    required this.onHide,
    required this.peekEdge,
    required this.onPeekEdgeChanged,
    this.onCapsuleGeometryChanged,
  });

  final VoidCallback onRestore;
  final VoidCallback onHide;
  final IslandPeekEdge peekEdge;
  final Future<void> Function(IslandPeekEdge) onPeekEdgeChanged;

  /// Notifica el tamaño y radio reales de la píldora para que la ventana
  /// recorte su región al contorno visible y deje pasar los clics de alrededor.
  final void Function(Size capsuleSize, double radius)?
  onCapsuleGeometryChanged;

  @override
  ConsumerState<IslandWindow> createState() => _IslandWindowState();
}

class _IslandWindowState extends ConsumerState<IslandWindow> {
  bool _hovering = false;
  bool _dismissing = false;
  Timer? _hideTimer;
  Timer? _dismissTimer;
  Size? _capsuleSize;
  double? _capsuleRadius;
  ValueNotifier<WindowUiState>? _window;

  @override
  void initState() {
    super.initState();
    // Apartar la isla no cambia el modo: la isla sigue montada. Sin escuchar
    // el notifier, al volver del borde seguía en opacity 0 e ignoraba hover.
    _window = ref.read(windowStateProvider);
    _window!.addListener(_onWindowChanged);
    unawaited(widget.onPeekEdgeChanged(widget.peekEdge));
    _scheduleAutoHide();
  }

  @override
  void didUpdateWidget(covariant IslandWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.peekEdge != widget.peekEdge) {
      unawaited(widget.onPeekEdgeChanged(widget.peekEdge));
    }
  }

  void _onWindowChanged() {
    final WindowUiState current = _window!.value;
    if (!current.visible) return;
    if (current.islandPeeked) {
      // La ventana no se oculta: solo se aparta. Cancelamos el temporizador
      // para no encadenar otro apartado mientras asoma por el borde.
      _hideTimer?.cancel();
      if (_dismissing && mounted) setState(() => _dismissing = false);
      return;
    }
    if (_dismissing) {
      _dismissTimer?.cancel();
      if (mounted) setState(() => _dismissing = false);
    }
    _scheduleAutoHide();
  }

  @override
  void dispose() {
    _window?.removeListener(_onWindowChanged);
    _hideTimer?.cancel();
    _dismissTimer?.cancel();
    super.dispose();
  }

  /// Contrae la cápsula antes de apartarla al borde para que el cambio se lea
  /// como una transición y no como una desaparición brusca.
  void _requestHide() {
    if (_dismissing || !mounted) return;
    _hideTimer?.cancel();
    setState(() => _dismissing = true);
    _dismissTimer?.cancel();
    final Duration delay = context.motion.duration(
      const Duration(milliseconds: 220),
      category: MotionCategory.island,
    );
    if (delay == Duration.zero) {
      widget.onHide();
      if (mounted) setState(() => _dismissing = false);
      return;
    }
    _dismissTimer = Timer(delay, () {
      if (!mounted) return;
      widget.onHide();
      // La isla sigue visible: devolvemos la opacidad para que se vea la
      // franja asomando en el borde superior.
      setState(() => _dismissing = false);
    });
  }

  void _scheduleAutoHide() {
    _hideTimer?.cancel();
    if (!mounted ||
        _hovering ||
        _dismissing ||
        _window?.value.islandPeeked == true) {
      return;
    }
    final CompactStyleConfig style = ref.read(
      compactStyleProvider(CompactSurface.island),
    );
    if (!style.autoHide) return;
    final int seconds = style.autoHideSeconds.clamp(2, 60).toInt();
    _hideTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted ||
          _hovering ||
          _dismissing ||
          _window?.value.islandPeeked == true ||
          _persistentlyExpanded) {
        return;
      }
      _requestHide();
    });
  }

  /// Un aviso o una expansión explícita mantienen la isla abierta aunque el
  /// ratón salga: el auto-ocultado solo aplica al estado puramente temporal.
  bool get _persistentlyExpanded {
    final DynamicIslandState island = ref.read(dynamicIslandControllerProvider);
    return island.expanded || island.message != null;
  }

  void _setHovering(bool value) {
    if (_dismissing ||
        _window?.value.islandPeeked == true ||
        _hovering == value) {
      return;
    }
    setState(() => _hovering = value);
    if (value) {
      _hideTimer?.cancel();
    } else if (!_persistentlyExpanded) {
      _scheduleAutoHide();
    }
  }

  /// Solo avisa cuando cambia la geometría: el tamaño de la región nativa no
  /// debe recalcularse en cada frame de progreso de la canción.
  void _syncCapsuleGeometry(Size size, double radius) {
    if (_capsuleSize == size && _capsuleRadius == radius) return;
    _capsuleSize = size;
    _capsuleRadius = radius;
    widget.onCapsuleGeometryChanged?.call(size, radius);
  }

  @override
  Widget build(BuildContext context) {
    final CompactStyleConfig style = ref.watch(
      compactStyleProvider(CompactSurface.island),
    );
    ref.listen<CompactStyleConfig>(
      compactStyleProvider(CompactSurface.island),
      (CompactStyleConfig? previous, CompactStyleConfig next) {
        if (previous?.autoHide != next.autoHide ||
            previous?.autoHideSeconds != next.autoHideSeconds) {
          _scheduleAutoHide();
        }
      },
    );
    ref.listen<DynamicIslandState>(dynamicIslandControllerProvider, (
      DynamicIslandState? previous,
      DynamicIslandState next,
    ) {
      final bool wasHeld =
          previous != null && (previous.expanded || previous.message != null);
      final bool held = next.expanded || next.message != null;
      if (wasHeld && !held && !_hovering) _scheduleAutoHide();
    });

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
    // Posición y progreso se suscriben en hijos aislados: observarlos aquí
    // reconstruiría el `CompactPanel` (con BackdropFilter) 5 veces por segundo.

    final PlayerController controller = ref.read(
      playerControllerProvider.notifier,
    );
    final DynamicIslandState island = ref.watch(
      dynamicIslandControllerProvider,
    );
    final bool expanded =
        _hovering || island.expanded || island.message != null;
    final String? message = island.message;
    final PolarisTokens tokens = context.tokens;
    final ResolvedCompactStyle resolved = style.resolve(tokens);
    final Duration introDuration = context.motion.duration(
      const Duration(milliseconds: 380),
      category: MotionCategory.island,
    );
    final Duration dismissDuration = context.motion.duration(
      const Duration(milliseconds: 220),
      category: MotionCategory.island,
    );

    final Size capsuleSize = expanded
        ? WindowService.islandExpandedCapsule
        : WindowService.islandCompactCapsule;
    // La región nativa se ajusta al terminar la animación de tamaño: aplicarla
    // en post-frame recortaba la cápsula a mitad de expansión y disparaba un
    // onExit del MouseRegion que la volvía a contraer.
    if (_capsuleSize == null) {
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (!mounted) return;
        _syncCapsuleGeometry(capsuleSize, resolved.radius);
      });
    }

    return Material(
      color: Colors.transparent,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.82, end: 1),
          duration: introDuration,
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double scale, Widget? child) {
            return Opacity(
              opacity: scale.clamp(0.0, 1.0),
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: AnimatedScale(
            scale: _dismissing ? 0.68 : 1,
            duration: dismissDuration,
            curve: Curves.easeInCubic,
            child: AnimatedOpacity(
              opacity: _dismissing ? 0 : 1,
              duration: dismissDuration,
              curve: Curves.easeInCubic,
              child: MouseRegion(
                onEnter: (_) => _setHovering(true),
                onExit: (_) => _setHovering(false),
                child: _Capsule(
                  track: track,
                  playing: playing,
                  buffering: buffering,
                  hovering: expanded,
                  message: message,
                  style: resolved,
                  controller: controller,
                  onRestore: widget.onRestore,
                  onHide: _requestHide,
                  onGeometrySettled: () =>
                      _syncCapsuleGeometry(capsuleSize, resolved.radius),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Único hijo de la isla que sigue el tick de posición.
class _IslandProgress extends ConsumerWidget {
  const _IslandProgress({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double progress = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.progress),
    );
    // Sin progreso real no se dibuja nada: evita la línea huérfana en el borde.
    if (progress <= 0) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 3,
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: 3,
        backgroundColor: color.withValues(alpha: 0.12),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

class _Capsule extends StatelessWidget {
  const _Capsule({
    required this.track,
    required this.playing,
    required this.buffering,
    required this.hovering,
    required this.message,
    required this.style,
    required this.controller,
    required this.onRestore,
    required this.onHide,
    required this.onGeometrySettled,
  });

  final Track? track;
  final bool playing;
  final bool buffering;
  final bool hovering;
  final String? message;
  final ResolvedCompactStyle style;
  final PlayerController controller;
  final VoidCallback onRestore;
  final VoidCallback onHide;
  final VoidCallback onGeometrySettled;

  @override
  Widget build(BuildContext context) {
    final double artworkSize = hovering ? 68 : 44;
    final Duration capsuleDuration = context.motion.duration(
      const Duration(milliseconds: 320),
      category: MotionCategory.island,
    );
    final Duration switchDuration = context.motion.duration(
      const Duration(milliseconds: 240),
      category: MotionCategory.island,
    );
    return CompactPanel(
      style: style,
      padding: EdgeInsets.zero,
      child: AnimatedContainer(
        duration: capsuleDuration,
        curve: Curves.easeOutCubic,
        onEnd: onGeometrySettled,
        width: hovering
            ? WindowService.islandExpandedCapsule.width
            : WindowService.islandCompactCapsule.width,
        height: hovering
            ? WindowService.islandExpandedCapsule.height
            : WindowService.islandCompactCapsule.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(style.radius),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Sin progreso real no se dibuja nada: evita la línea huérfana
              // en el borde de la cápsula cuando no hay pista o está parada.
              RepaintBoundary(
                child: _IslandProgress(color: style.progressColor),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  hovering ? 12 : 8,
                  hovering ? 12 : 10,
                  hovering ? 10 : 8,
                  hovering ? 14 : 12,
                ),
                child: Row(
                  children: <Widget>[
                    AnimatedContainer(
                      key: ValueKey<String>('island-artwork-${track?.id ?? 0}'),
                      duration: capsuleDuration,
                      curve: Curves.easeOutCubic,
                      width: artworkSize,
                      height: artworkSize,
                      child: track == null
                          ? PolarisLogo(size: artworkSize)
                          : TrackArtwork(
                              path: track!.artworkPath,
                              size: artworkSize,
                              radius: style.artworkRadius(style.radius * 0.42),
                            ),
                    ),
                    SizedBox(width: hovering ? 12 : 8),
                    Expanded(
                      child: _draggable(
                        AnimatedSwitcher(
                          duration: switchDuration,
                          child: hovering
                              ? _ExpandedInfo(
                                  key: ValueKey<String>(
                                    'expanded-${track?.id ?? 0}',
                                  ),
                                  track: track,
                                  message: message,
                                  playing: playing,
                                )
                              : _CompactInfo(
                                  key: ValueKey<String>(
                                    'compact-${track?.id ?? 0}',
                                  ),
                                  track: track,
                                ),
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: switchDuration,
                      transitionBuilder: (
                        Widget child,
                        Animation<double> animation,
                      ) => FadeTransition(opacity: animation, child: child),
                      child: hovering
                          ? _Controls(
                              key: const ValueKey<String>('controls'),
                              playing: playing,
                              buffering: buffering,
                              accent: style.accent,
                              controller: controller,
                              onRestore: onRestore,
                              onHide: onHide,
                            )
                          : _Action(
                              key: const ValueKey<String>('hide'),
                              tooltip: 'Esconder isla en el borde',
                              icon: Icons.visibility_off_rounded,
                              color: context.inkAlpha(0.54),
                              onTap: onHide,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _draggable(Widget child) =>
      Platform.isWindows ? DragToMoveArea(child: child) : child;
}

class _CompactInfo extends StatelessWidget {
  const _CompactInfo({super.key, required this.track});

  final Track? track;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          track?.title ?? 'Polaris Music',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          track?.artist ?? 'Nada en reproducción',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: context.inkAlpha(0.60)),
        ),
        if (track == null)
          Text(
            'Pasa el ratón para ver controles',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 8.5, color: context.inkAlpha(0.38)),
          ),
      ],
    );
  }
}

/// Solo se monta mientras la isla está expandida; sus selectores de posición
/// no arrastran el resto de la cápsula.
class _ExpandedInfo extends ConsumerWidget {
  const _ExpandedInfo({
    super.key,
    required this.track,
    required this.message,
    required this.playing,
  });

  final Track? track;
  final String? message;
  final bool playing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Duration position = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.position),
    );
    final Duration duration = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.duration),
    );
    final String title = message ?? track?.title ?? 'Polaris Music';
    final String subtitle = message != null
        ? 'Aviso de Polaris'
        : (track?.artist ?? 'Elige una canción para empezar');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: context.inkAlpha(0.60)),
        ),
        if (message == null) ...<Widget>[
          const SizedBox(height: 5),
          Text(
            '${Formatters.duration(position)} / ${Formatters.duration(duration)}'
            '${playing ? '  ·  En reproducción' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: context.inkAlpha(0.38)),
          ),
        ],
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    super.key,
    required this.playing,
    required this.buffering,
    required this.accent,
    required this.controller,
    required this.onRestore,
    required this.onHide,
  });

  final bool playing;
  final bool buffering;
  final Color accent;
  final PlayerController controller;
  final VoidCallback onRestore;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Action(
          tooltip: 'Anterior',
          icon: Icons.skip_previous_rounded,
          color: context.inkAlpha(0.70),
          onTap: controller.previous,
        ),
        if (buffering)
          _LoadingAction(color: accent, onTap: controller.togglePlay)
        else
          _Action(
            tooltip: playing ? 'Pausar' : 'Reproducir',
            icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: accent,
            onTap: controller.togglePlay,
          ),
        _Action(
          tooltip: 'Siguiente',
          icon: Icons.skip_next_rounded,
          color: context.inkAlpha(0.70),
          onTap: controller.next,
        ),
        _Action(
          tooltip: 'Abrir ventana principal',
          icon: Icons.open_in_full_rounded,
          color: context.inkAlpha(0.54),
          onTap: onRestore,
        ),
        _Action(
          tooltip: 'Esconder isla en el borde',
          icon: Icons.visibility_off_rounded,
          color: context.inkAlpha(0.54),
          onTap: onHide,
        ),
      ],
    );
  }
}

/// Igual que [_Action] pero con spinner, para el estado de carga. Mantiene el
/// mismo tamaño y área táctil que el resto de acciones.
class _LoadingAction extends StatelessWidget {
  const _LoadingAction({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Cargando…',
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
