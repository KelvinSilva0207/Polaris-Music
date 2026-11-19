import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

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
/// Durante el arrastre se dibuja una flecha que crece en la dirección elegida y,
/// al soltar, un anillo de pulso confirma la acción. Ambos usan el acento del
/// tema activo y se pintan con [CustomPainter] sin capas de desenfoque.
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
    with SingleTickerProviderStateMixin {
  static const double _swipeThreshold = _gestureSwipeThreshold;
  static const double _hintThreshold = 22;
  static const double _seekBand = 0.40;

  Offset? _start;
  bool _seeking = false;
  String? _hint;
  Timer? _hintTimer;

  final ValueNotifier<Offset> _drag = ValueNotifier<Offset>(Offset.zero);
  late final AnimationController _pulse;
  late final Listenable _repaint;
  Offset _lastDirection = Offset.zero;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _repaint = Listenable.merge(<Listenable>[_drag, _pulse]);
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _pulse.dispose();
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

  IconData _hintIcon(String hint) => switch (hint) {
    'Siguiente' => Icons.skip_next_rounded,
    'Anterior' => Icons.skip_previous_rounded,
    'Letras' => Icons.lyrics_outlined,
    _ => Icons.expand_more_rounded,
  };

  void _showHint(String hint, {bool persistent = false}) {
    _hintTimer?.cancel();
    if (!persistent) {
      _hintTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() => _hint = null);
      });
    }
    if (_hint == hint) return;
    setState(() => _hint = hint);
  }

  void _clearDrag() {
    if (_drag.value != Offset.zero) _drag.value = Offset.zero;
  }

  void _onDown(PointerDownEvent event) {
    _hintTimer?.cancel();
    _start = event.localPosition;
    _clearDrag();
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
    if (delta.distance > _hintThreshold) {
      _drag.value = delta;
      _showHint(_directionHint(delta.dx, delta.dy), persistent: true);
    }
  }

  void _onUp(PointerUpEvent event) {
    final Offset? start = _start;
    _start = null;
    if (start == null) return;
    final bool wasSeeking = _seeking;
    _seeking = false;

    if (wasSeeking || _hint == null) {
      _clearDrag();
      _showHint('');
      return;
    }

    final Offset delta = event.localPosition - start;
    final String action = _directionHint(delta.dx, delta.dy);
    if (delta.distance < _swipeThreshold) {
      _clearDrag();
      _showHint('');
      return;
    }

    _lastDirection = _directionFor(action);
    _clearDrag();
    _pulse.forward(from: 0);
    _showHint(action);
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
    _clearDrag();
    _showHint('');
  }

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
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GestureFeedbackPainter(
                    repaint: _repaint,
                    drag: _drag,
                    pulse: _pulse,
                    accent: accent,
                    direction: _lastDirection,
                    hint: _hint,
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 170),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final Animation<double> scale =
                      Tween<double>(begin: 0.82, end: 1).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                      );
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: scale, child: child),
                  );
                },
                child: _hint == null || _hint!.isEmpty
                    ? const SizedBox.shrink()
                    : Container(
                        key: ValueKey<String>(_hint!),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              _hintIcon(_hint!),
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              _hint!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
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

/// Flecha direccional mientras se arrastra y anillo de confirmación al soltar.
class _GestureFeedbackPainter extends CustomPainter {
  _GestureFeedbackPainter({
    required Listenable repaint,
    required this.drag,
    required this.pulse,
    required this.accent,
    required this.direction,
    required this.hint,
  }) : super(repaint: repaint);

  final ValueNotifier<Offset> drag;
  final Animation<double> pulse;
  final Color accent;
  final Offset direction;
  final String? hint;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset current = drag.value;
    final double distance = current.distance;
    final bool dragging = distance > 0.5;
    final Offset dir = dragging ? current / distance : direction;
    if (dir.distanceSquared == 0) return;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double strength = dragging
        ? (distance / _gestureSwipeThreshold).clamp(0.0, 1.35).toDouble()
        : 0;

    final Paint paint = Paint()
      ..color = accent.withValues(
        alpha: (0.28 + 0.55 * strength).clamp(0, 1).toDouble(),
      )
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Offset start = center + dir * (size.width * 0.14);
    final Offset end = center + dir * (size.width * (0.27 + 0.07 * strength));
    canvas.drawLine(start, end, paint);

    final double head = 10 + 5 * strength;
    final Offset perp = Offset(-dir.dy, dir.dx);
    canvas.drawLine(end, end - dir * head + perp * head * 0.7, paint);
    canvas.drawLine(end, end - dir * head - perp * head * 0.7, paint);

    if (pulse.value > 0 && pulse.value < 1) {
      final double eased = Curves.easeOutCubic.transform(pulse.value);
      canvas.drawCircle(
        center,
        size.width * 0.30 + 38 * eased,
        Paint()
          ..color = accent.withValues(alpha: (1 - eased) * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GestureFeedbackPainter old) =>
      pulse.isAnimating ||
      old.drag != drag ||
      old.pulse != pulse ||
      old.accent != accent ||
      old.direction != direction ||
      old.hint != hint;
}
