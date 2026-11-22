import 'package:flutter/material.dart';

import '../../core/theme/motion_config.dart';
import 'motion_scope.dart';

/// Cambio direccional que mantiene **todas** las pantallas montadas.
///
/// Es el sustituto animado del `IndexedStack`: el contenido inactivo queda en
/// `Offstage` (sin ticks), pero conserva su estado, scroll y controladores.
/// Solo se pintan la pantalla saliente y la entrante durante la transición.
///
/// El recorrido y el rebote se derivan del perfil de movimiento activo. La
/// opacidad usa una curva monótona aparte: las curvas elásticas pueden pasar de
/// 1.0 y `FadeTransition` exige valores en 0..1.
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
  late final CurvedAnimation _incomingMotion = CurvedAnimation(
    parent: _controller,
    curve: MotionConfig.defaults.sectionInCurve,
  );
  late final CurvedAnimation _incomingFade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final CurvedAnimation _outgoingMotion = CurvedAnimation(
    parent: _controller,
    curve: MotionConfig.defaults.sectionOutCurve,
  );
  late final CurvedAnimation _outgoingFade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInCubic,
  );

  int _current = 0;
  int? _previous;
  bool _forward = true;
  bool _allowed = true;
  double _travel = 0.10;
  double _intensity = 0.65;

  @override
  void initState() {
    super.initState();
    _current = _bounded(widget.index);
    // Sin este listener la pantalla saliente permanece en escena para siempre:
    // con opacity 0 seguía recibiendo toques y robaba eventos a la entrante.
    _controller.addStatusListener((AnimationStatus status) {
      if (status != AnimationStatus.completed &&
          status != AnimationStatus.dismissed) {
        return;
      }
      if (!mounted || _previous == null) return;
      setState(() => _previous = null);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final MotionConfig motion = context.motion;
    _allowed = context.motionAllowed(MotionCategory.transitions);
    _intensity = motion.intensity;
    _travel = widget.distance * motion.travelScale;
    // La duración ya llega escalada desde el padre; volver a aplicar
    // `motion.duration` aquí duplicaría el factor de velocidad.
    _incomingMotion.curve = motion.sectionInCurve;
    _outgoingMotion.curve = motion.sectionOutCurve;
  }

  @override
  void didUpdateWidget(covariant DirectionalSectionStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
      if (widget.distance != oldWidget.distance) {
        _travel = widget.distance * context.motion.travelScale;
      }
    }
    final int next = _bounded(widget.index);
    if (next == _current) return;

    if (!_allowed || widget.duration == Duration.zero) {
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
    _incomingMotion.dispose();
    _incomingFade.dispose();
    _outgoingMotion.dispose();
    _outgoingFade.dispose();
    _controller.dispose();
    super.dispose();
  }

  Offset _offset(double progress) =>
      Offset((_forward ? progress : -progress) * _travel, 0);

  Widget _decorate(int index, Widget child) {
    if (_previous == null || index != _current && index != _previous) {
      return child;
    }

    if (index == _current) {
      return ScaleTransition(
        scale: Tween<double>(
          begin: 1 - 0.035 * _intensity,
          end: 1,
        ).animate(_incomingFade),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: _offset(1),
            end: Offset.zero,
          ).animate(_incomingMotion),
          child: FadeTransition(opacity: _incomingFade, child: child),
        ),
      );
    }

    // La saliente se ignora: con opacity 0 sigue siendo hit-testable y podía
    // interceptar toques de la sección entrante según el orden del Stack.
    return IgnorePointer(
      ignoring: true,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 1,
          end: 1 - 0.02 * _intensity,
        ).animate(_outgoingFade),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: _offset(-1),
          ).animate(_outgoingMotion),
          child: FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0).animate(_outgoingFade),
            child: child,
          ),
        ),
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
                // La saliente conserva sus tickers durante la transición; al
                // terminar, `_previous` se limpia y solo queda la activa.
                enabled: i == _current || i == _previous,
                child: _decorate(i, widget.children[i]),
              ),
            ),
          ),
      ],
    );
  }
}

/// Cambio direccional para contenido que sí puede desmontarse (modos de
/// ventana, mini-reproductor, puerta de onboarding, vistas de biblioteca).
///
/// Se detecta el cambio por la [Key] del hijo, igual que hacía `AnimatedSwitcher`,
/// pero con un único controlador: eso permite dar al muelle la curva del perfil
/// activo sin exponer la opacidad a valores fuera de 0..1.
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

class _DirectionalContentSwitcherState extends State<DirectionalContentSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  late final CurvedAnimation _incomingMotion = CurvedAnimation(
    parent: _controller,
    curve: MotionConfig.defaults.sectionInCurve,
  );
  late final CurvedAnimation _incomingFade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final CurvedAnimation _outgoingMotion = CurvedAnimation(
    parent: _controller,
    curve: MotionConfig.defaults.sectionOutCurve,
  );
  late final CurvedAnimation _outgoingFade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInCubic,
  );

  Widget? _current;
  Widget? _previous;
  Key? _currentKey;
  bool _forward = true;
  bool _allowed = true;
  double _travel = 0.10;
  double _intensity = 0.65;

  @override
  void initState() {
    super.initState();
    _current = widget.child;
    _currentKey = widget.child.key;
    _controller.addStatusListener((AnimationStatus status) {
      if (status != AnimationStatus.completed &&
          status != AnimationStatus.dismissed) {
        return;
      }
      if (!mounted || _previous == null) return;
      setState(() => _previous = null);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final MotionConfig motion = context.motion;
    _allowed = context.motionAllowed(MotionCategory.transitions);
    _intensity = motion.intensity;
    _travel = widget.distance * motion.travelScale;
    _incomingMotion.curve = motion.sectionInCurve;
    _outgoingMotion.curve = motion.sectionOutCurve;
  }

  @override
  void didUpdateWidget(covariant DirectionalContentSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.distance != oldWidget.distance) {
      _travel = widget.distance * context.motion.travelScale;
    }

    final bool keyChanged = widget.child.key != _currentKey;
    if (!keyChanged) {
      // Misma clave pero contenido nuevo (estado interno, tema, cola...).
      _current = widget.child;
      return;
    }

    if (widget.direction != oldWidget.direction) {
      _forward = widget.direction > oldWidget.direction;
    }
    _previous = _current;
    _current = widget.child;
    _currentKey = widget.child.key;

    if (!_allowed || widget.duration == Duration.zero) {
      _controller.stop();
      _previous = null;
      _controller.value = 1;
      return;
    }
    _controller
      ..stop()
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _incomingMotion.dispose();
    _incomingFade.dispose();
    _outgoingMotion.dispose();
    _outgoingFade.dispose();
    _controller.dispose();
    super.dispose();
  }

  Offset _offset(double progress) {
    final double value = (_forward ? progress : -progress) * _travel;
    return widget.axis == Axis.horizontal ? Offset(value, 0) : Offset(0, value);
  }

  @override
  Widget build(BuildContext context) {
    final Widget current = _current ?? widget.child;
    final Widget? previous = _previous;
    if (previous == null) return current;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 1,
                end: 1 - 0.025 * _intensity,
              ).animate(_outgoingFade),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset.zero,
                  end: _offset(-1),
                ).animate(_outgoingMotion),
                child: FadeTransition(
                  opacity: Tween<double>(
                    begin: 1,
                    end: 0,
                  ).animate(_outgoingFade),
                  child: previous,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 1 - 0.03 * _intensity,
              end: 1,
            ).animate(_incomingFade),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: _offset(1),
                end: Offset.zero,
              ).animate(_incomingMotion),
              child: FadeTransition(opacity: _incomingFade, child: current),
            ),
          ),
        ),
      ],
    );
  }
}
