import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

const double _gestureSwipeThreshold = 48;

/// Gestos de carátula estilo Poweramp:
///
/// * Deslizar a la **derecha** → canción anterior.
/// * Deslizar a la **izquierda** → canción siguiente.
/// * Deslizar **arriba** → letras inmersivas.
/// * Deslizar **abajo** → minimizar el reproductor.
///
/// El anillo exterior mantiene su búsqueda por ángulo: si el gesto empieza en
/// la franja del anillo se busca; si empieza en la carátula se interpreta como
/// deslizamiento. Usamos [Listener] en lugar de [GestureDetector] para decidir
/// el modo en el instante del toque y que la búsqueda no robe los deslizamientos.
///
/// El feedback es físico y sin texto: la carátula sigue el dedo con un tilted
/// 3D sutil, vuelve con un resorte (spring) al soltar y un anillo cromático
/// confirma la acción. No se dibujan flechas ni etiquetas sobre la portada.
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
  });

  final double size;
  final Widget child;
  final ValueChanged<double> onSeekFraction;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLyrics;
  final VoidCallback onMinimize;

  /// Color del tema RGB/HSL activo. Si no se entrega se usa el primario.
  final Color? accent;

  @override
  State<ArtworkGestures> createState() => _ArtworkGesturesState();
}

class _ArtworkGesturesState extends State<ArtworkGestures>
    with TickerProviderStateMixin {
  static const double _swipeThreshold = _gestureSwipeThreshold;
  static const double _hintThreshold = 22;
  static const double _seekBand = 0.40;

  Offset? _start;
  bool _seeking = false;

  final ValueNotifier<Offset> _drag = ValueNotifier<Offset>(Offset.zero);
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
      duration: const Duration(milliseconds: 380),
    );
    // Los límites permiten el overshoot del resorte sin asserts.
    _spring = AnimationController(
      vsync: this,
      lowerBound: -0.45,
      upperBound: 1.45,
      duration: const Duration(milliseconds: 1),
    );
    _spring.addListener(() {
      if (!_spring.isAnimating && _releasing) {
        _releasing = false;
        _drag.value = Offset.zero;
      }
    });
    _motion = Listenable.merge(<Listenable>[_drag, _pulse, _spring]);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spring.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _seekAt(Offset local) {
    final Offset center = Offset(widget.size / 2, widget.size / 2);
    final double angle = math.atan2(local.dy - center.dy, local.dx - center.dx);
    widget.onSeekFraction(((angle + math.pi / 2) / (2 * math.pi)) % 1);
  }

  String _directionHint(double dx, double dy) {
    if (dx.abs() > dy.abs()) {
      return dx < 0 ? 'Siguiente' : 'Anterior';
    }
    return dy < 0 ? 'Letras' : 'Minimizar';
  }

  Offset _directionFor(String hint) => switch (hint) {
    'Siguiente' => const Offset(-1, 0),
    'Anterior' => const Offset(1, 0),
    'Letras' => const Offset(0, -1),
    _ => const Offset(0, 1),
  };

  void _resetMotion() {
    _spring.stop();
    _releasing = false;
    if (_drag.value != Offset.zero) _drag.value = Offset.zero;
  }

  void _onDown(PointerDownEvent event) {
    _start = event.localPosition;
    _resetMotion();
    final Offset center = Offset(widget.size / 2, widget.size / 2);
    _seeking =
        (event.localPosition - center).distance > widget.size * _seekBand;
    if (_seeking) _seekAt(event.localPosition);
  }

  void _onMove(PointerMoveEvent event) {
    final Offset? start = _start;
    if (start == null) return;
    if (_seeking) {
      _seekAt(event.localPosition);
      return;
    }
    final Offset delta = event.localPosition - start;
    if (delta.distance > _hintThreshold) _drag.value = delta;
  }

  /// Resorte: la carátula sigue el dedo y vuelve con inercia elástica.
  void _release(Offset delta) {
    _releasing = true;
    final double velocity = -(delta.distance / 0.16).clamp(0, 6).toDouble();
    _spring.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1.1, stiffness: 210, damping: 15),
        1,
        0,
        velocity,
      ),
    );
    _pulse.forward(from: 0);
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
    if (delta.distance < _swipeThreshold) {
      _resetMotion();
      return;
    }

    final String action = _directionHint(delta.dx, delta.dy);
    _lastDirection = _directionFor(action);
    _release(delta);
    switch (action) {
      case 'Siguiente':
        widget.onNext();
      case 'Anterior':
        widget.onPrevious();
      case 'Letras':
        widget.onLyrics();
      default:
        widget.onMinimize();
    }
  }

  void _onCancel(PointerCancelEvent _) {
    _start = null;
    _seeking = false;
    _resetMotion();
  }

  Offset _effectiveOffset() =>
      _releasing ? _drag.value * _spring.value : _drag.value;

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.accent ?? Theme.of(context).colorScheme.primary;
    // El reproductor compacto vive dentro de un ListView. Este detector gana
    // la arena de gestos para que deslizar la carátula no desplace la lista.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {},
      onVerticalDragStart: (_) {},
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onPointerCancel: _onCancel,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            AnimatedBuilder(
              animation: _motion,
              builder: (BuildContext context, Widget? child) {
                final Offset offset = _effectiveOffset();
                // Tilt 3D sutil y dependiente del gesto, sobre la perspectiva
                // base que ya tiene la carátula. El resorte puede overshoot.
                final double tiltX = (offset.dy / widget.size)
                    .clamp(-0.10, 0.10)
                    .toDouble();
                final double tiltY = (offset.dx / widget.size)
                    .clamp(-0.10, 0.10)
                    .toDouble();
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..rotateX(-tiltX)
                    ..rotateY(tiltY),
                  child: Transform.translate(
                    offset: Offset(offset.dx * 0.22, offset.dy * 0.22),
                    child: child,
                  ),
                );
              },
              child: widget.child,
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ChromaticGesturePainter(
                    repaint: _motion,
                    drag: _drag,
                    pulse: _pulse,
                    accent: accent,
                    direction: _lastDirection,
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

/// Resplandor cromático reactivo: tres anillos desplazados en la dirección del
/// gesto y un pulso de confirmación al soltar. Sin filtros de desenfoque.
class _ChromaticGesturePainter extends CustomPainter {
  _ChromaticGesturePainter({
    required Listenable repaint,
    required this.drag,
    required this.pulse,
    required this.accent,
    required this.direction,
  }) : super(repaint: repaint);

  final ValueNotifier<Offset> drag;
  final Animation<double> pulse;
  final Color accent;
  final Offset direction;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset current = drag.value;
    final double distance = current.distance;
    final double strength = (distance / _gestureSwipeThreshold)
        .clamp(0, 1.35)
        .toDouble();
    final Offset dir = distance > 0.5 ? current / distance : direction;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final HSVColor base = HSVColor.fromColor(accent);
    final List<Color> channels = <Color>[
      base.withHue((base.hue + 34) % 360).toColor(),
      accent,
      base.withHue((base.hue - 34 + 360) % 360).toColor(),
    ];

    if (strength > 0) {
      final double radius = size.width * 0.32 + 5 * strength;
      for (int i = 0; i < channels.length; i++) {
        final double shift = (i - 1) * (2 + 6 * strength);
        canvas.drawCircle(
          center + dir * shift,
          radius,
          Paint()
            ..color = channels[i].withValues(
              alpha: (0.08 + 0.26 * strength).clamp(0, 1).toDouble(),
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = i == 1 ? 2.2 : 1.3,
        );
      }
    }

    if (pulse.value > 0 && pulse.value < 1) {
      final double eased = Curves.easeOutCubic.transform(pulse.value);
      final double radius = size.width * 0.30 + 38 * eased;
      for (int i = 0; i < channels.length; i++) {
        canvas.drawCircle(
          center + dir * ((i - 1) * 5),
          radius,
          Paint()
            ..color = channels[i].withValues(
              alpha: (1 - eased) * (i == 1 ? 0.55 : 0.28),
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = i == 1 ? 2.4 : 1.4,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChromaticGesturePainter old) =>
      old.drag != drag ||
      old.pulse != pulse ||
      old.accent != accent ||
      old.direction != direction;
}
