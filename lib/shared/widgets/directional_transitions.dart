import 'package:flutter/material.dart';

/// Cambio direccional que mantiene **todas** las pantallas montadas.
///
/// Es el sustituto animado del `IndexedStack`: el contenido inactivo queda en
/// `Offstage` (sin ticks), pero conserva su estado, scroll y controladores.
/// Solo se pintan la pantalla saliente y la entrante durante la transición.
class DirectionalSectionStack extends StatefulWidget {
  const DirectionalSectionStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 320),
    this.distance = 0.10,
  });

  final int index;
  final List<Widget> children;
  final Duration duration;

  /// Fraction of the viewport travelled by the incoming/outgoing section.
  final double distance;

  @override
  State<DirectionalSectionStack> createState() =>
      _DirectionalSectionStackState();
}

class _DirectionalSectionStackState extends State<DirectionalSectionStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final CurvedAnimation _incoming = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final CurvedAnimation _outgoing = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInCubic,
  );

  int _current = 0;
  int? _previous;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    _current = _bounded(widget.index);
  }

  @override
  void didUpdateWidget(covariant DirectionalSectionStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    final int next = _bounded(widget.index);
    if (next == _current) return;

    if (widget.duration == Duration.zero) {
      _controller.stop();
      setState(() {
        _previous = null;
        _current = next;
      });
      return;
    }

    setState(() {
      _previous = _current;
      _current = next;
      _forward = next > _previous!;
    });
    _controller
      ..stop()
      ..forward(from: 0);
  }

  int _bounded(int value) {
    if (widget.children.isEmpty) return 0;
    return value.clamp(0, widget.children.length - 1);
  }

  @override
  void dispose() {
    _incoming.dispose();
    _outgoing.dispose();
    _controller.dispose();
    super.dispose();
  }

  Offset _offset(double progress) =>
      Offset((_forward ? progress : -progress) * widget.distance, 0);

  Widget _decorate(int index, Widget child) {
    if (_previous == null || index != _current && index != _previous) {
      return child;
    }

    if (index == _current) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: _offset(1),
          end: Offset.zero,
        ).animate(_incoming),
        child: FadeTransition(opacity: _incoming, child: child),
      );
    }

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: _offset(-1),
      ).animate(_outgoing),
      child: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0).animate(_outgoing),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        for (int i = 0; i < widget.children.length; i++)
          Positioned.fill(
            child: Offstage(
              offstage: i != _current && i != _previous,
              child: TickerMode(
                enabled: i == _current,
                child: _decorate(i, widget.children[i]),
              ),
            ),
          ),
      ],
    );
  }
}

/// Cambio direccional para contenido que sí puede desmontarse (modos de
/// ventana, mini-reproductor, puerta de onboarding).
class DirectionalContentSwitcher extends StatefulWidget {
  const DirectionalContentSwitcher({
    super.key,
    required this.child,
    required this.direction,
    this.duration = const Duration(milliseconds: 320),
    this.distance = 0.10,
    this.axis = Axis.horizontal,
  });

  final Widget child;
  final int direction;
  final Duration duration;
  final double distance;
  final Axis axis;

  @override
  State<DirectionalContentSwitcher> createState() =>
      _DirectionalContentSwitcherState();
}

class _DirectionalContentSwitcherState
    extends State<DirectionalContentSwitcher> {
  bool _forward = true;

  @override
  void didUpdateWidget(covariant DirectionalContentSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.direction != oldWidget.direction) {
      _forward = widget.direction > oldWidget.direction;
    }
  }

  Offset get _begin {
    final double value = _forward ? widget.distance : -widget.distance;
    return widget.axis == Axis.horizontal ? Offset(value, 0) : Offset(0, value);
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = widget.child;
    if (widget.duration == Duration.zero) return child;

    return AnimatedSwitcher(
      duration: widget.duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // Pintar solo la entrante evita el "ghost" de capas superpuestas.
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) =>
          currentChild ?? const SizedBox.shrink(),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: _begin,
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: child,
    );
  }
}
