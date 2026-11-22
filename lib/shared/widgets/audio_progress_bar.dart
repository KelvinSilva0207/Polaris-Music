import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/motion_config.dart';
import '../../core/theme/theme_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../features/player/domain/player_controller.dart';
import '../../features/player/presentation/player_providers.dart';
import 'motion_scope.dart';

/// Barra de progreso de la música.
///
/// Es la barra protagonista del reproductor: gruesa, redondeada y con un
/// resplandor del acento activo. El indicador es una píldora vertical que
/// crece al pasar el ratón o arrastrar, y sobre ella aparece un tooltip con el
/// tiempo exacto de la posición apuntada (no la posición actual).
class AudioProgressBar extends ConsumerStatefulWidget {
  const AudioProgressBar({
    super.key,
    this.onSeekFraction,
    this.accent,
    this.compact = false,
  });

  /// Se dispara al tocar o arrastrar, con una fracción de 0 a 1.
  final ValueChanged<double>? onSeekFraction;
  final Color? accent;

  /// Versión reducida para el mini reproductor y el modo teléfono.
  final bool compact;

  @override
  ConsumerState<AudioProgressBar> createState() => _AudioProgressBarState();
}

class _AudioProgressBarState extends ConsumerState<AudioProgressBar> {
  /// Fracción bajo el cursor, si lo hay.
  double? _hoverFraction;

  /// Fracción seleccionada durante el arrastre.
  double? _dragFraction;

  bool get _interacting => _hoverFraction != null || _dragFraction != null;

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final Color accent = widget.accent ?? tokens.progressColor;
    final double intensity = context.motion.intensity;
    final Duration position = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.position),
    );
    final Duration duration = ref.watch(
      playerControllerProvider.select((PlayerUiState s) => s.playback.duration),
    );

    final double totalMs = duration.inMilliseconds.toDouble();
    final double played = totalMs <= 0
        ? 0
        : (position.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final double shown = _dragFraction ?? played;
    final double? previewFraction = _dragFraction ?? _hoverFraction;

    final Duration previewTime = previewFraction == null || totalMs <= 0
        ? position
        : Duration(milliseconds: (previewFraction * totalMs).round());

    void seekTo(double localDx, double width) {
      if (width <= 0) return;
      final double fraction = (localDx / width).clamp(0.0, 1.0);
      setState(() => _dragFraction = fraction);
      widget.onSeekFraction?.call(fraction);
    }

    final double railHeight = widget.compact ? 6 : 9;
    final double thumbWidth = _dragFraction != null
        ? 8
        : (_interacting ? 7 : 5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: widget.compact ? 32 : 50,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth;
              final double railTop = widget.compact ? 13 : 34;
              final double growth = 4 + 8 * intensity;
              final double thumbHeight = _dragFraction != null
                  ? (widget.compact ? 22 : 22 + growth)
                  : (_interacting
                        ? (widget.compact ? 18 : 18 + growth * 0.75)
                        : 18);
              final double thumbLeft = width <= 0
                  ? 0
                  : (shown * width - thumbWidth / 2).clamp(
                      0.0,
                      math.max(0.0, width - thumbWidth),
                    );

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                onHover: (PointerHoverEvent event) {
                  if (_dragFraction != null || width <= 0) return;
                  setState(
                    () => _hoverFraction = (event.localPosition.dx / width)
                        .clamp(0.0, 1.0),
                  );
                },
                onExit: (_) {
                  if (_dragFraction == null && _hoverFraction != null) {
                    setState(() => _hoverFraction = null);
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // El toque busca de inmediato; el arrastre mantiene el pulgar
                  // pegado al cursor aunque la posición real tarde en llegar.
                  onTapDown: (TapDownDetails details) =>
                      seekTo(details.localPosition.dx, width),
                  onHorizontalDragStart: (DragStartDetails details) =>
                      seekTo(details.localPosition.dx, width),
                  onHorizontalDragUpdate: (DragUpdateDetails details) =>
                      seekTo(details.localPosition.dx, width),
                  onHorizontalDragEnd: (_) {
                    if (mounted) setState(() => _dragFraction = null);
                  },
                  onHorizontalDragCancel: () {
                    if (mounted) setState(() => _dragFraction = null);
                  },
                  onTapUp: (_) {
                    if (mounted) setState(() => _dragFraction = null);
                  },
                  onTapCancel: () {
                    if (mounted) setState(() => _dragFraction = null);
                  },
                  child: RepaintBoundary(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        // Riel de fondo: apenas visible para dar profundidad.
                        Positioned(
                          left: 0,
                          right: 0,
                          top: railTop,
                          height: railHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(railHeight),
                              color: context.inkAlpha(0.10),
                              border: Border.all(color: context.inkAlpha(0.06)),
                            ),
                          ),
                        ),
                        // Resplandor sin blur: una franja translúcida más ancha
                        // cuesta mucho menos de rasterizar que un BoxShadow.
                        Positioned(
                          left: 0,
                          top: railTop - 3,
                          height: railHeight + 6,
                          width: math.max(railHeight, shown * width),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                railHeight + 3,
                              ),
                              color: accent.withValues(alpha: 0.16),
                            ),
                          ),
                        ),
                        // Riel reproducido con degradado del acento.
                        Positioned(
                          left: 0,
                          top: railTop,
                          height: railHeight,
                          width: math.max(railHeight, shown * width),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(railHeight),
                              gradient: LinearGradient(
                                colors: <Color>[
                                  accent.withValues(alpha: 0.85),
                                  Color.lerp(accent, context.ink, 0.28) ??
                                      accent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Pulgar: la posición salta con la pista (sin animar),
                        // solo tamaño y color se interpolan al interactuar.
                        // AnimatedContainer con `left` reiniciaba su controlador
                        // cada tick y generaba interpolaciones innecesarias.
                        Positioned(
                          left: thumbLeft,
                          top: railTop + (railHeight - thumbHeight) / 2,
                          child: AnimatedContainer(
                            duration: context.motion.duration(
                              const Duration(milliseconds: 160),
                              category: MotionCategory.gestures,
                            ),
                            curve: Curves.easeOutCubic,
                            width: thumbWidth,
                            height: thumbHeight,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(thumbWidth),
                              color: context.ink,
                              border: Border.all(
                                color: accent.withValues(alpha: 0.65),
                                width: _interacting ? 2 : 1,
                              ),
                            ),
                          ),
                        ),
                        // Tooltip con el tiempo exacto apuntado.
                        if (previewFraction != null && !widget.compact)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            child: Align(
                              alignment: Alignment(previewFraction * 2 - 1, 0),
                              child: _TimePill(
                                label: Formatters.duration(previewTime),
                                accent: accent,
                                glass: tokens.isGlass,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _TimeLabel(
                Formatters.duration(previewTime),
                active: _interacting,
                accent: accent,
              ),
              _TimeLabel(
                Formatters.duration(duration),
                active: false,
                accent: accent,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({
    required this.label,
    required this.accent,
    required this.glass,
  });

  final String label;
  final Color accent;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: glass
            ? context.inkAlpha(0.16)
            : context.tokens.panelOverlay.withValues(alpha: 0.94),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: 10),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: context.onPanel,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel(this.label, {required this.active, required this.accent});

  final String label;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: context.motion.duration(const Duration(milliseconds: 180)),
      style: TextStyle(
        fontSize: 11,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        color: active ? accent : context.inkAlpha(0.54),
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
      child: Text(label),
    );
  }
}

/// Control de volumen, deliberadamente distinto a la barra de música.
///
/// Es un riel segmentado, fino y minimalista: cada segmento se enciende con el
/// acento. El altavoz silencia/restaura el volumen con un clic y la rueda del
/// ratón ajusta el nivel cuando el cursor está encima.
class VolumeSlider extends ConsumerStatefulWidget {
  const VolumeSlider({
    super.key,
    required this.controller,
    this.accent,
    this.compact = false,
  });

  final PlayerController controller;
  final Color? accent;

  /// Reduce solo los huecos internos; el icono, el riel y el porcentaje
  /// conservan su tamaño para que la lectura no se degrade en ventanas
  /// estrechas.
  final bool compact;

  @override
  ConsumerState<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends ConsumerState<VolumeSlider> {
  static const int _segments = 28;

  /// Último volumen audible, para restaurarlo al desmutear.
  double _lastAudible = 50;
  bool _hovering = false;

  void _setVolume(double percent) {
    final double value = percent.clamp(0.0, 100.0);
    unawaited(widget.controller.setVolume(value));
  }

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final Color accent = widget.accent ?? tokens.volumeColor;
    final double innerGap = widget.compact ? 6 : 10;
    final double volume = ref
        .watch(
          playerControllerProvider.select(
            (PlayerUiState s) => s.playback.volume,
          ),
        )
        .clamp(0.0, 100.0);
    final bool muted = volume <= 0.01;
    if (!muted) _lastAudible = volume;
    final int litSegments = (volume / 100 * _segments).round();

    void seekTo(double localDx, double width) {
      if (width <= 0) return;
      _setVolume(localDx / width * 100);
    }

    return Row(
      children: <Widget>[
        Tooltip(
          message: muted ? 'Activar sonido' : 'Silenciar',
          waitDuration: const Duration(milliseconds: 600),
          child: InkResponse(
            radius: 20,
            onTap: () =>
                _setVolume(muted ? (_lastAudible <= 0 ? 50 : _lastAudible) : 0),
            child: AnimatedContainer(
              duration: context.motion.duration(
                const Duration(milliseconds: 220),
                category: MotionCategory.gestures,
              ),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: muted
                    ? Colors.redAccent.withValues(alpha: 0.16)
                    : accent.withValues(alpha: _hovering ? 0.20 : 0.12),
                border: Border.all(
                  color: muted
                      ? Colors.redAccent.withValues(alpha: 0.45)
                      : accent.withValues(alpha: 0.35),
                ),
              ),
              child: AnimatedSwitcher(
                duration: context.motion.duration(
                  const Duration(milliseconds: 180),
                  category: MotionCategory.gestures,
                ),
                transitionBuilder: (
                  Widget child,
                  Animation<double> animation,
                ) => ScaleTransition(scale: animation, child: child),
                child: Icon(
                  muted
                      ? Icons.volume_off_rounded
                      : (volume < 45
                            ? Icons.volume_down_rounded
                            : Icons.volume_up_rounded),
                  key: ValueKey<bool>(muted),
                  size: 17,
                  color: muted ? Colors.redAccent : accent,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: innerGap),
        Expanded(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child: Listener(
              onPointerSignal: (PointerSignalEvent event) {
                if (event is! PointerScrollEvent || !_hovering) return;
                final double delta = -event.scrollDelta.dy;
                if (delta == 0) return;
                _setVolume(volume + delta.sign * 2);
              },
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double width = constraints.maxWidth;
                  final double dotLeft = width <= 0
                      ? 0
                      : (volume / 100 * width - 6).clamp(
                          0.0,
                          math.max(0.0, width - 12),
                        );
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (TapDownDetails details) =>
                        seekTo(details.localPosition.dx, width),
                    onHorizontalDragUpdate: (DragUpdateDetails details) =>
                        seekTo(details.localPosition.dx, width),
                    child: SizedBox(
                      height: 26,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: <Widget>[
                          Row(
                            children: List<Widget>.generate(_segments, (
                              int index,
                            ) {
                              final bool lit = index < litSegments;
                              return Expanded(
                                child: AnimatedContainer(
                                  duration: context.motion.duration(
                                    const Duration(milliseconds: 140),
                                    category: MotionCategory.gestures,
                                  ),
                                  height: lit ? 7 : 3,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    color: lit
                                        ? accent.withValues(alpha: 0.85)
                                        : context.inkAlpha(
                                            _hovering ? 0.22 : 0.12,
                                          ),
                                    boxShadow: lit
                                        ? <BoxShadow>[
                                            BoxShadow(
                                              color: accent.withValues(
                                                alpha: 0.30,
                                              ),
                                              blurRadius: 5,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              );
                            }),
                          ),
                          // Punto de referencia minimalista.
                          if (_hovering)
                            Positioned(
                              left: dotLeft,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: context.ink,
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.7),
                                    width: 2,
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        SizedBox(width: innerGap),
        SizedBox(
          width: 36,
          child: Text(
            '${volume.round()}%',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 11,
              fontWeight: _hovering ? FontWeight.w700 : FontWeight.w500,
              color: _hovering ? accent : context.inkAlpha(0.54),
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
