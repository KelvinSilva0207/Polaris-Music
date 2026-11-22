import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_navigation.dart';
import '../../core/theme/motion_config.dart';
import '../../core/theme/theme_tokens.dart';
import 'motion_scope.dart';

/// Variante visual del mismo indicador líquido.
enum LiquidNavLayout { bottom, top }

/// Barra de navegación con un indicador que se comporta como una gota.
///
/// La burbuja se estira mientras viaja y se acopla con un rebote suave gracias
/// a [Curves.easeOutBack]. El mismo componente se usa abajo en móvil y arriba
/// en escritorio: solo cambia la distribución de iconos y etiquetas.
///
/// Solo se repinta el [CustomPainter] durante la animación; las etiquetas se
/// reconstruyen una sola vez por cambio de sección para no competir con
/// `media_kit` por CPU.
class LiquidNavBar extends StatefulWidget {
  const LiquidNavBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.layout = LiquidNavLayout.bottom,
    this.width,
    this.compact = false,
  });

  final AppSection selected;
  final ValueChanged<AppSection> onChanged;
  final LiquidNavLayout layout;

  /// Ancho explícito para la barra superior; en móvil lo da el padre.
  final double? width;

  /// Oculta las etiquetas en la variante superior cuando hay poco espacio.
  final bool compact;

  @override
  State<LiquidNavBar> createState() => _LiquidNavBarState();
}

class _LiquidNavBarState extends State<LiquidNavBar>
    with SingleTickerProviderStateMixin {
  static const int _count = 4;

  late final AnimationController _controller;

  /// Despliegue de la barra flotante al entrar en un modo/panel nuevo.
  late final AnimationController _reveal;
  late final CurvedAnimation _revealMotion;

  late final CurvedAnimation _position;
  bool _allowed = true;
  bool _revealAllowed = true;
  double _intensity = 1;
  int _from = 0;
  int _to = 0;

  @override
  void initState() {
    super.initState();
    _to = widget.selected.index;
    _from = _to;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _position = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      value: 1,
    );
    _revealMotion = CurvedAnimation(parent: _reveal, curve: Curves.easeOutBack);
    _reveal.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final MotionConfig motion = context.motion;
    _allowed = context.motionAllowed(MotionCategory.gestures);
    _revealAllowed = context.motionAllowed(MotionCategory.transitions);
    _intensity = motion.intensity;
    final Duration duration = motion.duration(
      const Duration(milliseconds: 520),
      category: MotionCategory.gestures,
    );
    _controller.duration = duration == Duration.zero
        ? const Duration(microseconds: 1)
        : duration;
    _position.curve = motion.indicatorCurve;
    final Duration revealDuration = motion.duration(
      const Duration(milliseconds: 420),
      category: MotionCategory.transitions,
    );
    _reveal.duration = revealDuration == Duration.zero
        ? const Duration(microseconds: 1)
        : revealDuration;
    _revealMotion.curve = motion.indicatorCurve;
  }

  @override
  void didUpdateWidget(covariant LiquidNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    _from = _visualIndex;
    _to = widget.selected.index;
    if (_allowed) {
      _controller.forward(from: 0);
    } else {
      _from = _to;
      _controller.value = 1;
    }
    if (_revealAllowed) _reveal.forward(from: 0);
  }

  /// Índice que se está mostrando ahora mismo, incluso a mitad de viaje.
  int get _visualIndex {
    final double t = _position.value.clamp(0.0, 1.0);
    return (_from + (_to - _from) * t).round().clamp(0, _count - 1).toInt();
  }

  @override
  void dispose() {
    _controller.dispose();
    _revealMotion.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _reveal,
      builder: (BuildContext context, Widget? child) {
        final PolarisTokens tokens = context.tokens;
        final Color accent = tokens.accent;
        final bool top = widget.layout == LiquidNavLayout.top;

        // El panel flotante se despliega con un pequeño muelle al aparecer; el
        // indicador usa su propia animación para perseguir la selección activa.
        final double reveal = _revealAllowed ? _revealMotion.value : 1;
        final double lift = (1 - reveal.clamp(0.0, 1.0)) * 16 * _intensity;

        return Container(
          width: widget.width,
          height: top ? 52 : 66,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: tokens
              .panelDecoration(
                radius: top ? 20 : 26,
                glow: accent,
                // Sin contorno: el borde especular de los paneles se percibe
                // como un recuadro alrededor de los iconos. El halo radial del
                // indicador es la única guía visual del ítem activo.
                borderColor: Colors.transparent,
              )
              .copyWith(
                color: tokens.panelOverlay.withValues(alpha: top ? 0.94 : 0.96),
              ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth;
              final double itemWidth = width / _count;
              final List<double> centers = List<double>.generate(
                _count,
                (int i) => itemWidth * (i + 0.5),
              );
              final double centerY = constraints.maxHeight / 2;
              final double baseWidth = top
                  ? math.min<double>(itemWidth - 18, 132)
                  : math.min<double>(itemWidth - 12, 72);

              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  CustomPaint(
                    painter: _LiquidIndicatorPainter(
                      repaint: Listenable.merge(<Listenable>[
                        _controller,
                        _reveal,
                      ]),
                      position: _position,
                      raw: _controller,
                      reveal: _revealMotion,
                      centers: centers,
                      from: _from,
                      to: _to,
                      width: width,
                      centerY: centerY,
                      baseWidth: baseWidth,
                      height: math.min<double>(
                        constraints.maxHeight - 8,
                        top ? 38 : 42,
                      ),
                      fill: accent.withValues(alpha: top ? 0.18 : 0.22),
                      glow: accent.withValues(alpha: top ? 0.14 : 0.20),
                      accent: accent,
                      intensity: _intensity,
                      enabled: _revealAllowed,
                    ),
                  ),
                  FractionalTranslation(
                    translation: Offset(0, top ? -lift / 52 : lift / 66),
                    child: FadeTransition(
                      opacity: AlwaysStoppedAnimation<double>(
                        reveal.clamp(0.0, 1.0).toDouble(),
                      ),
                      child: Row(
                        children: AppSection.values
                            .map(
                              (AppSection section) => Expanded(
                                child: _LiquidNavItem(
                                  section: section,
                                  selected: section == widget.selected,
                                  accent: accent,
                                  compact: widget.compact,
                                  layout: widget.layout,
                                  onTap: () => widget.onChanged(section),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _LiquidNavItem extends StatelessWidget {
  const _LiquidNavItem({
    required this.section,
    required this.selected,
    required this.accent,
    required this.compact,
    required this.layout,
    required this.onTap,
  });

  final AppSection section;
  final bool selected;
  final Color accent;
  final bool compact;
  final LiquidNavLayout layout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final IconData icon = selected ? section.activeIcon : section.icon;
    final bool top = layout == LiquidNavLayout.top;
    final bool showLabel = !top || !compact;

    final Widget iconWidget = TweenAnimationBuilder<Color?>(
      duration: context.motion.duration(
        const Duration(milliseconds: 280),
        category: MotionCategory.gestures,
      ),
      tween: ColorTween(
        begin: selected ? context.inkAlpha(0.60) : accent,
        end: selected ? accent : context.inkAlpha(0.60),
      ),
      builder: (BuildContext context, Color? color, Widget? _) =>
          Icon(icon, size: top ? 18 : 22, color: color),
    );
    final Widget label = AnimatedDefaultTextStyle(
      duration: context.motion.duration(
        const Duration(milliseconds: 280),
        category: MotionCategory.gestures,
      ),
      curve: Curves.easeOutCubic,
      style: TextStyle(
        fontSize: top ? 12.5 : 10.5,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        color: selected ? context.ink : context.inkAlpha(0.70),
      ),
      child: Text(section.label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );

    final Widget content = top
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              iconWidget,
              if (showLabel) ...<Widget>[const SizedBox(width: 7), label],
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[iconWidget, const SizedBox(height: 3), label],
          );

    return Semantics(
      button: true,
      selected: selected,
      label: section.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(top ? 18 : 22),
          // El splash/hover de Material dibuja un rectángulo alrededor del
          // icono al pasar el ratón. La interacción se conserva, pero sin
          // ninguna marca visible que compita con el halo del indicador.
          splashFactory: NoSplash.splashFactory,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          focusColor: Colors.transparent,
          onTap: onTap,
          child: AnimatedScale(
            scale: selected ? 1.08 : 1,
            duration: context.motion.duration(
              const Duration(milliseconds: 460),
              category: MotionCategory.gestures,
            ),
            curve: Curves.easeOutBack,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: top ? 6 : 2,
                  vertical: top ? 6 : 4,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dibuja el brillo del ítem activo como un halo sin bordes, desplazado en la
/// dirección del viaje para mantener la sensación de gota al cambiar de sección.
class _LiquidIndicatorPainter extends CustomPainter {
  _LiquidIndicatorPainter({
    required Listenable repaint,
    required this.position,
    required this.raw,
    required this.centers,
    required this.from,
    required this.to,
    required this.width,
    required this.centerY,
    required this.baseWidth,
    required this.height,
    required this.fill,
    required this.glow,
    required this.accent,
    required this.intensity,
    required this.reveal,
    required this.enabled,
  }) : super(repaint: repaint);

  final Animation<double> position;
  final Animation<double> raw;
  final List<double> centers;
  final int from;
  final int to;
  final double width;
  final double centerY;
  final double baseWidth;
  final double height;
  final Color fill;
  final Color glow;
  final Color accent;
  final double intensity;
  final Animation<double> reveal;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final int a = from.clamp(0, centers.length - 1).toInt();
    final int b = to.clamp(0, centers.length - 1).toInt();
    final double start = centers[a];
    final double end = centers[b];

    final double t = position.value;
    final double p = raw.value.clamp(0.0, 1.0);
    final double half = baseWidth / 2;
    final double x = (start + (end - start) * t)
        .clamp(half + 2, math.max<double>(half + 2, width - half - 2))
        .toDouble();

    // Durante el despliegue la muesca nace estrecha y se expande; al cambiar de
    // sección se estira en la dirección del viaje como una gota.
    final double revealValue = enabled ? reveal.value.clamp(0.0, 1.0) : 1;
    final double revealScale = 0.55 + 0.45 * revealValue;
    final double pillWidth = baseWidth * revealScale;
    final double pillHeight = height * (0.72 + 0.28 * revealValue);
    final double travel = (end - start).abs();
    final double stretch =
        math.sin(math.pi * p) *
        math.min<double>(travel * 0.42, 12 + 24 * intensity);
    final double lead = stretch * (end >= start ? 1 : -1);

    // Indicador sin recuadro: un halo elíptico con degradado radial que se
    // desvanece a transparente. No hay trazos ni capas con bordes definidos,
    // así que el ítem activo no queda encerrado en ninguna píldora.
    // El acento del tema tiñe el brillo (Glass/Liquid/Mate/Claro/RGB) y el
    // centro se desplaza con `lead` para conservar la sensación líquida.
    // El tamaño se limita al hueco real de la barra para no cortarse en móvil
    // ni en la variante superior de escritorio.
    final double roomY = (centerY * 2) / height;
    final double roomX = (width / centers.length) / baseWidth;
    final double spread = math.max<double>(
      1,
      math.min<double>(1.3, math.min(roomX, roomY)),
    );
    final Offset center = Offset(x + lead * 0.22, centerY);
    final Rect glowRect = Rect.fromCenter(
      center: center,
      width: pillWidth * spread * 2.1 + lead.abs() * 0.5,
      height: pillHeight * spread * 2.3,
    );
    canvas.drawOval(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            accent.withValues(alpha: fill.a + glow.a * 0.35),
            accent.withValues(alpha: glow.a * 0.22),
            accent.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.45, 1],
        ).createShader(glowRect),
    );

    // Brillo breve en el borde delantero: refuerza la dirección del viaje.
    if (lead.abs() > 2) {
      final Offset edge = Offset(x + lead * 0.62, centerY - pillHeight * 0.16);
      canvas.drawCircle(
        edge,
        2.6,
        Paint()..color = accent.withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidIndicatorPainter old) =>
      position.isAnimating ||
      raw.isAnimating ||
      reveal.isAnimating ||
      old.position != position ||
      old.raw != raw ||
      old.centers.length != centers.length ||
      old.from != from ||
      old.to != to ||
      old.width != width ||
      old.fill != fill ||
      old.glow != glow ||
      old.intensity != intensity ||
      old.reveal != reveal ||
      old.enabled != enabled;
}
