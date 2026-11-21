import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

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
///
/// El feedback ya no dibuja círculos ni flechas: la carátula se desplaza con un
/// resorte, se inclina en 3D, crece apenas y su aura cambia de tono al confirmar.
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
    this.accent,
    this.seekEnabled = false,
    this.playing = false,
    this.paused = false,
  });

  final double size;
  final Widget child;
  final ValueChanged<double> onSeekFraction;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLyrics;
  final VoidCallback onMinimize;
  final Color? accent;

  /// Solo se activa con `ProgressBarType.circularAroundArtwork`.
  final bool seekEnabled;

  /// Permite mantener una aura ambiental suave mientras reproduce.
  final bool playing;

  /// Ventana minimizada/en segundo plano: detiene todo feedback continuo.
  final bool paused;

  @override
  State<ArtworkGestures> createState() => _ArtworkGesturesState();
}

enum _SwipeAction { next, previous, lyrics, minimize }

class _ArtworkGesturesState extends State<ArtworkGestures>
    with TickerProviderStateMixin {
  Offset? _start;
  bool _seeking = false;

  final ValueNotifier<double> _intensity = ValueNotifier<double>(0);
  final ValueNotifier<Offset> _direction = ValueNotifier<Offset>(Offset.zero);
  late final AnimationController _pulse;
  late final AnimationController _spring;
  late final Listenable _motion;

  Offset _lastDirection = Offset.zero;
  bool _releasing = false;

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
    if (_intensity.value != 0) _intensity.value = 0;
  }

  void _onDown(PointerDownEvent event) {
    _resetMotion();
    _start = event.localPosition;
    final Offset center = Offset(widget.size / 2, widget.size / 2);
    _seeking =
        widget.seekEnabled &&
        (event.localPosition - center).distance > widget.size * 0.40;
    if (_seeking) _seekAt(event.localPosition);
  }

  void _onMove(PointerMoveEvent event) {
    final Offset? start = _start;
    if (start == null) return;
    if (_seeking) {
      _seekAt(event.localPosition);
      return;
    }
    if (!context.motion.gestures || widget.paused) return;

    final Offset delta = event.localPosition - start;
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

    final bool wasSeeking = _seeking;
    _seeking = false;
    if (wasSeeking) {
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
                  final double shift = widget.size * 0.022 * e;
                  final double tilt = 0.10 * e;
                  final double scale = (1 + 0.025 * e).clamp(0.94, 1.05);

                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0015)
                      ..rotateX(-dir.dy * tilt)
                      ..rotateY(dir.dx * tilt),
                    child: Transform.scale(
                      scale: scale,
                      child: Transform.translate(
                        offset: dir * shift,
                        child: child,
                      ),
                    ),
                  );
                },
                child: widget.child,
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
