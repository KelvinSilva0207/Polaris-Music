import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  });

  final double size;
  final Widget child;
  final ValueChanged<double> onSeekFraction;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLyrics;
  final VoidCallback onMinimize;

  @override
  State<ArtworkGestures> createState() => _ArtworkGesturesState();
}

class _ArtworkGesturesState extends State<ArtworkGestures> {
  static const double _swipeThreshold = 48;
  static const double _hintThreshold = 22;
  static const double _seekBand = 0.40;

  Offset? _start;
  bool _seeking = false;
  String? _hint;
  Timer? _hintTimer;

  @override
  void dispose() {
    _hintTimer?.cancel();
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

  void _onDown(PointerDownEvent event) {
    _hintTimer?.cancel();
    _start = event.localPosition;
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
      _showHint('');
      return;
    }

    final Offset delta = event.localPosition - start;
    String action = _directionHint(delta.dx, delta.dy);
    if (delta.distance < _swipeThreshold) {
      _showHint('');
      return;
    }
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
    _showHint('');
  }

  @override
  Widget build(BuildContext context) {
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
            IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: _hint == null || _hint!.isEmpty
                    ? const SizedBox.shrink()
                    : Container(
                        key: ValueKey<String>(_hint!),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
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
                                fontWeight: FontWeight.w700,
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
