import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/motion_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/motion_scope.dart';

const double _gestureSwipeThreshold = 48;
const double _gestureHintThreshold = 18;

/// Gestos físicos de carátula:
///
/// * Deslizar a la **derecha** → canción anterior.
/// * Deslizar a la **izquierda** → canción siguiente.
/// * Deslizar **arriba** → letras.
/// * Deslizar **abajo** → minimizar.
/// * Deslizar vertical en el **borde derecho** → volumen (estilo Poweramp).
/// * Deslizar vertical en el **borde izquierdo** → brillo (solo Android).
///
/// Las zonas laterales solo se activan si se pasa el callback correspondiente,
/// así que el reproductor sigue teniendo los cuatro gestos centrales de siempre.
///
/// El feedback ya no dibuja círculos ni flechas: al deslizar, la carátula se
/// aparta suavemente y asoma un **preview real** de la pista vecina desde el
/// borde, siguiendo el dedo desde los primeros píxeles. Al soltar, un resorte
/// devuelve la carátula si no se pasó el umbral. No hay inclinación 3D.
/// Solo el anillo de progreso circular (cuando está activo) busca por ángulo.
class ArtworkGestures extends StatefulWidget {
  const ArtworkGestures({
    super.key,
    required this.size,
    required this.child,
    required this.onSeekFraction,
    required this.onPrevious,
    required this.onNext,
    required this.onLyrics,
    required this.onMinimize,
    this.onVolumeDelta,
    this.onBrightnessDelta,
    this.accent,
    this.seekEnabled = false,
    this.playing = false,
    this.paused = false,
    this.nextPreview,
    this.previousPreview,
  });

  final double size;
  final Widget child;
  final ValueChanged<double> onSeekFraction;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLyrics;
  final VoidCallback onMinimize;

  /// Fracción de carátula arrastrada hacia arriba en el borde derecho.
  final ValueChanged<double>? onVolumeDelta;

  /// Fracción de carátula arrastrada hacia arriba en el borde izquierdo.
  final ValueChanged<double>? onBrightnessDelta;

  final Color? accent;

  /// Solo se activa con `ProgressBarType.circularAroundArtwork`.
  final bool seekEnabled;

  /// Permite mantener una aura ambiental suave mientras reproduce.
  final bool playing;

  /// Ventana minimizada/en segundo plano: detiene todo feedback continuo.
  final bool paused;

  /// Adelanto de la pista siguiente/anterior. Se montan siempre (con opacidad
  /// 0) para que la imagen ya esté decodificada cuando empiece el arrastre.
  /// Si son `null` el gesto conserva solo el aura, como hasta ahora.
  final Widget? nextPreview;
  final Widget? previousPreview;

  @override
  State<ArtworkGestures> createState() => _ArtworkGesturesState();
}

enum _SwipeAction { next, previous, lyrics, minimize }

enum _Edge { brightness, volume }

class _ArtworkGesturesState extends State<ArtworkGestures>
    with TickerProviderStateMixin {
  Offset? _start;
  bool _seeking = false;
  bool _outerCandidate = false;
  _Edge? _edge;
  double _lastEdgeY = 0;
  bool _edgeStarted = false;

  final ValueNotifier<double> _intensity = ValueNotifier<double>(0);
  final ValueNotifier<Offset> _direction = ValueNotifier<Offset>(Offset.zero);
  late final AnimationController _pulse;
  late final AnimationController _spring;
  late final Listenable _motion;

  Offset _lastDirection = Offset.zero;
  bool _releasing = false;

  /// El swipe ya confirmó el cambio: ocultamos el preview para que no se vea
  /// la carátula vieja y la nueva a la vez durante la transición entrante.
  bool _committing = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _spring = AnimationController(
      vsync: this,
      lowerBound: -0.45,
      upperBound: 1.45,
      duration: const Duration(milliseconds: 1),
    );
    _spring.addListener(() {
      if (!_spring.isAnimating && _releasing) {
        _releasing = false;
        _intensity.value = 0;
      }
    });
    _motion = Listenable.merge(<Listenable>[
      _intensity,
      _direction,
      _pulse,
      _spring,
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Duration duration = context.motion.duration(
      const Duration(milliseconds: 420),
      category: MotionCategory.gestures,
    );
    _pulse.duration = duration == Duration.zero
        ? const Duration(microseconds: 1)
        : duration;
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spring.dispose();
    _intensity.dispose();
    _direction.dispose();
    super.dispose();
  }

  void _seekAt(Offset local) {
    final Offset center = Offset(widget.size / 2, widget.size / 2);
    final double angle = math.atan2(local.dy - center.dy, local.dx - center.dx);
    widget.onSeekFraction(((angle + math.pi / 2) / (2 * math.pi)) % 1);
  }

  _SwipeAction _actionFor(Offset delta) {
    if (delta.dx.abs() > delta.dy.abs()) {
      return delta.dx < 0 ? _SwipeAction.next : _SwipeAction.previous;
    }
    return delta.dy < 0 ? _SwipeAction.lyrics : _SwipeAction.minimize;
  }

  Offset _unitFor(_SwipeAction action) => switch (action) {
    _SwipeAction.next => const Offset(-1, 0),
    _SwipeAction.previous => const Offset(1, 0),
    _SwipeAction.lyrics => const Offset(0, -1),
    _SwipeAction.minimize => const Offset(0, 1),
  };

  void _resetMotion() {
    _spring.stop();
    _releasing = false;
    _committing = false;
    if (_intensity.value != 0) _intensity.value = 0;
  }

  /// Progreso visual del adelanto: a 20 px ya se ve el 30 % y a 48 px el 100 %.
  /// Se calcula sobre la distancia real del dedo, sin curvas que lo retrasen.
  double _revealFor(double draggedPixels) {
    if (draggedPixels <= 0) return 0;
    if (draggedPixels <= 20) return 0.30 * (draggedPixels / 20);
    final double rest = ((draggedPixels - 20) / (_gestureSwipeThreshold - 20))
        .clamp(0.0, 1.0);
    return 0.30 + 0.70 * rest;
  }

  void _onDown(PointerDownEvent event) {
    _resetMotion();
    _start = event.localPosition;
    _edge = null;
    _lastEdgeY = 0;
    _edgeStarted = false;
    final Offset center = Offset(widget.size / 2, widget.size / 2);
    // Con el anillo activo, el borde es candidato a búsqueda *y* a control
    // lateral. La dirección del primer arrastre decide: vertical manda volumen
    // o brillo; cualquier otro movimiento conserva la búsqueda por ángulo.
    _outerCandidate =
        widget.seekEnabled &&
        (event.localPosition - center).distance > widget.size * 0.40;
    _seeking = false;
    if (widget.paused || !context.motion.gestures) return;
    final double x = event.localPosition.dx;
    if (widget.onVolumeDelta != null && x > widget.size * 0.76) {
      _edge = _Edge.volume;
    } else if (widget.onBrightnessDelta != null && x < widget.size * 0.24) {
      _edge = _Edge.brightness;
    }
  }

  void _onMove(PointerMoveEvent event) {
    final Offset? start = _start;
    if (start == null) return;
    final Offset delta = event.localPosition - start;

    if (_outerCandidate) {
      final _Edge? candidate = _edge;
      final bool verticalIntent =
          candidate != null &&
          delta.dy.abs() > 10 &&
          delta.dy.abs() >= delta.dx.abs() * 1.3;
      if (verticalIntent) {
        _outerCandidate = false;
        _edgeStarted = true;
        unawaited(HapticFeedback.selectionClick());
      } else if (delta.distance > 6) {
        _outerCandidate = false;
        _edge = null;
        _seeking = true;
      }
    }

    if (_seeking) {
      _seekAt(event.localPosition);
      return;
    }
    final _Edge? edge = _edge;
    if (edge != null) {
      final double y = event.localPosition.dy - start.dy;
      final double step = _lastEdgeY - y;
      _lastEdgeY = y;
      if (!_edgeStarted && y.abs() > 12) {
        _edgeStarted = true;
        unawaited(HapticFeedback.selectionClick());
      }
      if (_edgeStarted && step.abs() > 0.5) {
        final double fraction = step / widget.size;
        if (edge == _Edge.volume) {
          widget.onVolumeDelta?.call(fraction);
        } else {
          widget.onBrightnessDelta?.call(fraction);
        }
      }
      return;
    }
    if (!context.motion.gestures || widget.paused) return;

    final double distance = delta.distance;
    if (distance < _gestureHintThreshold) return;

    _direction.value = distance > 0.5 ? delta / distance : _lastDirection;
    _intensity.value = (distance / _gestureSwipeThreshold).clamp(0, 1.35);
  }

  /// Vuelve elásticamente a la posición original sin dibujar indicadores.
  void _release(Offset delta) {
    final MotionConfig motion = context.motion;
    if (!motion.gestures || widget.paused) {
      _resetMotion();
      return;
    }

    final double speed = motion.speed.clamp(0.25, 2);
    _releasing = true;
    _spring.animateWith(
      SpringSimulation(
        SpringDescription(
          mass: 1.1,
          stiffness: 210 * speed * speed,
          damping: 15 * speed,
        ),
        1,
        0,
        -(math.min(delta.distance, _gestureSwipeThreshold * 1.35) / 0.16)
            .clamp(0, 6)
            .toDouble(),
      ),
    );
    final Duration? pulseDuration = _pulse.duration;
    if (pulseDuration != null && pulseDuration > Duration.zero) {
      _pulse.forward(from: 0);
    }
  }

  void _onUp(PointerUpEvent event) {
    final Offset? start = _start;
    _start = null;
    if (start == null) return;

    // Toque simple sobre el anillo: se mantiene el salto al segundo exacto.
    if (_outerCandidate) {
      _outerCandidate = false;
      _seekAt(start);
      _resetMotion();
      return;
    }

    final bool wasSeeking = _seeking;
    _seeking = false;
    if (_edge != null || wasSeeking) {
      _edge = null;
      _resetMotion();
      return;
    }

    final Offset delta = event.localPosition - start;
    if (delta.distance < _gestureSwipeThreshold) {
      _resetMotion();
      return;
    }

    final _SwipeAction action = _actionFor(delta);
    _lastDirection = _unitFor(action);
    _direction.value = _lastDirection;
    final bool hasPreview = switch (action) {
      _SwipeAction.next => widget.nextPreview != null,
      _SwipeAction.previous => widget.previousPreview != null,
      _ => false,
    };
    if (hasPreview) _committing = true;
    _release(delta);

    switch (action) {
      case _SwipeAction.next:
        widget.onNext();
      case _SwipeAction.previous:
        widget.onPrevious();
      case _SwipeAction.lyrics:
        widget.onLyrics();
      case _SwipeAction.minimize:
        widget.onMinimize();
    }
  }

  void _onCancel(PointerCancelEvent _) {
    _start = null;
    _seeking = false;
    _outerCandidate = false;
    _edge = null;
    _resetMotion();
  }

  double get _effectiveIntensity =>
      (_releasing ? _intensity.value * _spring.value : _intensity.value).clamp(
        -0.45,
        1.45,
      );

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.accent ?? context.tokens.accent;
    final double radius = widget.size / 2;
    // El gate visual no altera la lógica del swipe: con movimiento reducido el
    // preview no aparece, pero los callbacks siguen funcionando como siempre.
    final bool previewAllowed =
        context.motionAllowed(MotionCategory.gestures) && !widget.paused;
    final double travelScale = context.motion.travelScale.clamp(0.0, 1.0);

    return ClipPath(
      clipper: _CircleClipper(radius),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        // No robamos toques simples: solo las fricciones horizontales/verticales
        // toman la arena dentro del círculo de la carátula.
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) {},
        onVerticalDragStart: (_) {},
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onDown,
          onPointerMove: _onMove,
          onPointerUp: _onUp,
          onPointerCancel: _onCancel,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _motion,
                    builder: (BuildContext context, Widget? _) => CustomPaint(
                      painter: _AuraGesturePainter(
                        intensity: _effectiveIntensity,
                        pulse: _pulse,
                        direction: _direction.value,
                        accent: accent,
                        idle:
                            widget.playing &&
                            !widget.paused &&
                            context.ambientMotionAllowed(
                              playing: widget.playing,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _motion,
                builder: (BuildContext context, Widget? child) {
                  final double e = _effectiveIntensity;
                  final Offset dir = _direction.value;
                  // Sin perspectiva ni rotación: la carátula solo acompaña al
                  // dedo y cede un poco de sitio al preview que entra detrás.
                  final double shift = widget.size * 0.07 * e.clamp(0.0, 1.35);
                  final double scale = (1 - 0.04 * e).clamp(0.92, 1.04);

                  return Transform.translate(
                    offset: dir * shift,
                    child: Transform.scale(scale: scale, child: child),
                  );
                },
                child: widget.child,
              ),
              // Se dibuja encima de la carátula actual: al arrastrar, la
              // pista vecina entra por el borde y tapa progresivamente la
              // anterior, como un carrusel, sin ningún giro 3D.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _motion,
                    builder: (BuildContext context, Widget? _) {
                      final Offset direction = _direction.value;
                      final bool horizontal =
                          direction.dx.abs() > direction.dy.abs() &&
                          direction.dx != 0;
                      final Widget? preview = !horizontal
                          ? null
                          : direction.dx < 0
                          ? widget.nextPreview
                          : widget.previousPreview;
                      if (!previewAllowed || _committing || preview == null) {
                        return const SizedBox.shrink();
                      }
                      final double reveal = _revealFor(
                        _effectiveIntensity * _gestureSwipeThreshold,
                      );
                      if (reveal <= 0) return const SizedBox.shrink();
                      // Deslizar a la izquierda (siguiente) hace entrar la
                      // carátula por la derecha; el gesto inverso, por la
                      // izquierda. A 20 px ya asoma un 30 %.
                      final double side = -direction.dx;
                      final double offset =
                          side *
                          widget.size *
                          (0.95 - 0.70 * reveal * travelScale);
                      return Opacity(
                        opacity: (reveal * 1.6).clamp(0.0, 1.0),
                        child: FractionalTranslation(
                          translation: Offset(offset / widget.size, 0),
                          child: Transform.scale(
                            scale: 0.86 + 0.14 * reveal,
                            child: SizedBox(
                              width: widget.size,
                              height: widget.size,
                              child: preview,
                            ),
                          ),
                        ),
                      );
                    },
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

class _CircleClipper extends CustomClipper<Path> {
  const _CircleClipper(this.radius);

  final double radius;

  @override
  Path getClip(Size size) => Path()
    ..addOval(
      Rect.fromCircle(center: size.center(Offset.zero), radius: radius),
    );

  @override
  bool shouldReclip(_CircleClipper oldClipper) => oldClipper.radius != radius;
}

/// Aura radial que sustituye al antiguo círculo con flecha.
///
/// Dos halos cambian de tono al soltar; no hay trazos, iconos ni texto.
class _AuraGesturePainter extends CustomPainter {
  const _AuraGesturePainter({
    required this.intensity,
    required this.pulse,
    required this.direction,
    required this.accent,
    required this.idle,
  });

  final double intensity;
  final Animation<double> pulse;
  final Offset direction;
  final Color accent;
  final bool idle;

  void _halo(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double alpha,
  ) {
    if (alpha <= 0.002) return;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          color.withValues(alpha: 0),
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
        stops: const <double>[0.45, 0.78, 1],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;
    if (radius <= 2) return;

    final double e = intensity.clamp(0, 1.35).toDouble();
    final double dragAlpha = (e * 0.42).clamp(0, 0.62);
    final double cross = Curves.easeInOutCubic.transform(pulse.value);
    final HSVColor base = HSVColor.fromColor(accent);
    final Color hueA = base.withHue((base.hue + 26) % 360).toColor();
    final Color hueB = base.withHue((base.hue - 26 + 360) % 360).toColor();

    _halo(canvas, center, radius, hueA, dragAlpha * (1 - cross));
    _halo(
      canvas,
      center,
      radius * (1 + 0.04 * cross),
      hueB,
      dragAlpha * cross + 0.20 * cross * (1 - cross),
    );
    if (idle) _halo(canvas, center, radius, accent, 0.07);
  }

  @override
  bool shouldRepaint(covariant _AuraGesturePainter old) =>
      old.intensity != intensity ||
      old.pulse != pulse ||
      old.direction != direction ||
      old.accent != accent ||
      old.idle != idle;
}
