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
  late final CurvedAnimation _position;
  MotionConfig? _motion;
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion = context.motion;
    final Duration duration = _motion!.duration(
      const Duration(milliseconds: 520),
      category: MotionCategory.gestures,
    );
    _controller.duration = duration == Duration.zero
        ? const Duration(microseconds: 1)
        : duration;
  }

  @override
  void didUpdateWidget(covariant LiquidNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    _from = _visualIndex;
    _to = widget.selected.index;
    if (_motion?.gestures ?? true) {
      _controller.forward(from: 0);
    } else {
      _from = _to;
      _controller.value = 1;
    }
  }

  /// Índice que se está mostrando ahora mismo, incluso a mitad de viaje.
  int get _visualIndex {
    final double t = _position.value.clamp(0.0, 1.0);
    return (_from + (_to - _from) * t).round().clamp(0, _count - 1).toInt();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PolarisTokens tokens = context.tokens;
    final Color accent = tokens.accent;
    final bool top = widget.layout == LiquidNavLayout.top;

    return Container(
      width: widget.width,
      height: top ? 52 : 66,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: tokens
          .panelDecoration(radius: top ? 20 : 26, glow: accent)
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
                  repaint: _controller,
                  position: _position,
                  raw: _controller,
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
                  border: tokens.panelBorder.withValues(alpha: 0.85),
                  glow: accent.withValues(alpha: top ? 0.14 : 0.20),
                  accent: accent,
                ),
              ),
              Row(
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
            ],
          );
        },
      ),
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

/// Dibuja una cápsula con el borde delantero estirado y el trasero rezagado.
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
    required this.border,
    required this.glow,
    required this.accent,
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
  final Color border;
  final Color glow;
  final Color accent;

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

    final double travel = (end - start).abs();
    final double stretch =
        math.sin(math.pi * p) * math.min<double>(travel * 0.42, 36);
    final double lead = stretch * (end >= start ? 1 : -1);
    final Path blob = _blobPath(Offset(x, centerY), baseWidth, height, lead);

    // Resplandor del acento dibujado como trazo ancho y translúcido: evita
    // filtros de desenfoque y sigue siendo barato en móvil.
    canvas.drawPath(
      blob,
      Paint()
        ..color = glow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );
    canvas.drawPath(blob, Paint()..color = fill);
    canvas.drawPath(
      blob,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Brillo breve en el borde delantero: refuerza la dirección del viaje.
    if (lead.abs() > 2) {
      final Offset edge = Offset(x + lead * 0.62, centerY - height * 0.16);
      canvas.drawCircle(
        edge,
        2.6,
        Paint()..color = accent.withValues(alpha: 0.55),
      );
    }
  }

  Path _blobPath(Offset center, double w, double h, double lead) {
    final double left = center.dx - w / 2;
    final double right = center.dx + w / 2;
    final double top = center.dy - h / 2;
    final double bottom = center.dy + h / 2;
    final double radius = h / 2;

    return Path()
      ..moveTo(left + radius, top)
      ..lineTo(right - radius, top)
      ..cubicTo(
        right + lead * 0.65,
        top,
        right + lead,
        center.dy - h * 0.22,
        right + lead,
        center.dy,
      )
      ..cubicTo(
        right + lead,
        center.dy + h * 0.22,
        right + lead * 0.65,
        bottom,
        right - radius,
        bottom,
      )
      ..lineTo(left + radius, bottom)
      ..cubicTo(
        left + lead * 0.35,
        bottom,
        left + lead,
        center.dy + h * 0.22,
        left + lead,
        center.dy,
      )
      ..cubicTo(
        left + lead,
        center.dy - h * 0.22,
        left + lead * 0.35,
        top,
        left + radius,
        top,
      )
      ..close();
  }

  @override
  bool shouldRepaint(covariant _LiquidIndicatorPainter old) =>
      position.isAnimating ||
      raw.isAnimating ||
      old.position != position ||
      old.raw != raw ||
      old.centers.length != centers.length ||
      old.from != from ||
      old.to != to ||
      old.width != width ||
      old.fill != fill ||
      old.border != border ||
      old.glow != glow;
}
