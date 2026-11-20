import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/color_math.dart';
import '../../../core/theme/theme_tokens.dart';

/// Diálogo de color libre: rueda cromática HSV, deslizadores de tono,
/// saturación, brillo y opacidad, entrada HEX y campos RGB.
///
/// El estado es local mientras se edita; [onApply] se llama una sola vez al
/// aceptar para no escribir en Drift en cada frame del arrastre.
class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({
    super.key,
    required this.title,
    required this.initial,
    required this.onApply,
  });

  final String title;
  final Color initial;
  final ValueChanged<Color> onApply;

  static Future<Color?> show(
    BuildContext context, {
    required String title,
    required Color initial,
  }) {
    return showDialog<Color>(
      context: context,
      builder: (BuildContext context) => ColorPickerDialog(
        title: title,
        initial: initial,
        onApply: (Color color) => Navigator.of(context).pop(color),
      ),
    );
  }

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late HsvColor _hsv;
  late final TextEditingController _hex;
  late final TextEditingController _red;
  late final TextEditingController _green;
  late final TextEditingController _blue;

  @override
  void initState() {
    super.initState();
    _hsv = HsvColor.fromColor(widget.initial);
    _hex = TextEditingController(
      text: ColorMath.toHex(widget.initial, withAlpha: true),
    );
    _red = TextEditingController(text: '${_byte(widget.initial.r)}');
    _green = TextEditingController(text: '${_byte(widget.initial.g)}');
    _blue = TextEditingController(text: '${_byte(widget.initial.b)}');
  }

  @override
  void dispose() {
    _hex.dispose();
    _red.dispose();
    _green.dispose();
    _blue.dispose();
    super.dispose();
  }

  Color get _color => _hsv.toColor();

  void _update(HsvColor next) {
    setState(() => _hsv = next);
    _hex.text = ColorMath.toHex(_color, withAlpha: true);
    _red.text = '${_byte(_color.r)}';
    _green.text = '${_byte(_color.g)}';
    _blue.text = '${_byte(_color.b)}';
  }

  void _fromHex(String value) {
    final Color? parsed = ColorMath.tryParseHex(value);
    if (parsed == null) return;
    setState(() => _hsv = HsvColor.fromColor(parsed));
    _red.text = '${_byte(parsed.r)}';
    _green.text = '${_byte(parsed.g)}';
    _blue.text = '${_byte(parsed.b)}';
  }

  void _fromRgb() {
    final int? r = int.tryParse(_red.text);
    final int? g = int.tryParse(_green.text);
    final int? b = int.tryParse(_blue.text);
    if (r == null || g == null || b == null) return;
    final Color color = Color.fromRGBO(
      r.clamp(0, 255).toInt(),
      g.clamp(0, 255).toInt(),
      b.clamp(0, 255).toInt(),
      _hsv.a,
    );
    setState(() => _hsv = HsvColor.fromColor(color));
    _hex.text = ColorMath.toHex(color, withAlpha: true);
  }

  Widget _slider({
    required String label,
    required double value,
    required double max,
    required ValueChanged<double> onChanged,
    required String formatted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(label, style: const TextStyle(fontSize: 11)),
            const Spacer(),
            Text(
              formatted,
              style: TextStyle(fontSize: 10, color: context.inkAlpha(0.54)),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: max,
          activeColor: _color,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _channelField(String label, TextEditingController controller) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
        onChanged: (_) => _fromRgb(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.inkAlpha(0.24)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: _hex,
                      decoration: const InputDecoration(
                        labelText: 'HEX (#AARRGGBB)',
                        isDense: true,
                      ),
                      onChanged: _fromHex,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double size = math.min(constraints.maxWidth, 260);
                    return Center(
                      child: GestureDetector(
                        onTapDown: (TapDownDetails details) =>
                            _pick(details.localPosition, size),
                        onPanStart: (DragStartDetails details) =>
                            _pick(details.localPosition, size),
                        onPanUpdate: (DragUpdateDetails details) =>
                            _pick(details.localPosition, size),
                        child: CustomPaint(
                          size: Size.square(size),
                          painter: _ColorWheelPainter(
                            hsv: _hsv,
                            outlineColor: context.inkAlpha(0.24),
                            selectorColor: context.ink,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              _slider(
                label: 'Tono (Hue)',
                value: _hsv.h,
                max: 360,
                formatted: '${_hsv.h.round()}°',
                onChanged: (double value) => _update(_hsv.copyWith(h: value)),
              ),
              _slider(
                label: 'Saturación',
                value: _hsv.s,
                max: 1,
                formatted: '${(_hsv.s * 100).round()} %',
                onChanged: (double value) => _update(_hsv.copyWith(s: value)),
              ),
              _slider(
                label: 'Brillo (Value)',
                value: _hsv.v,
                max: 1,
                formatted: '${(_hsv.v * 100).round()} %',
                onChanged: (double value) => _update(_hsv.copyWith(v: value)),
              ),
              _slider(
                label: 'Opacidad',
                value: _hsv.a,
                max: 1,
                formatted: '${(_hsv.a * 100).round()} %',
                onChanged: (double value) => _update(_hsv.copyWith(a: value)),
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  _channelField('R', _red),
                  const SizedBox(width: 8),
                  _channelField('G', _green),
                  const SizedBox(width: 8),
                  _channelField('B', _blue),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => _update(HsvColor.fromColor(widget.initial)),
          child: const Text('Restablecer'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => widget.onApply(_color),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }

  void _pick(Offset local, double size) {
    final Offset center = Offset(size / 2, size / 2);
    final Offset delta = local - center;
    final double radius = size / 2;
    final double distance = delta.distance.clamp(0.0, radius);
    final double angle = math.atan2(delta.dy, delta.dx);
    final double hue = ((angle * 180 / math.pi) + 90) % 360;
    _update(_hsv.copyWith(h: hue, s: radius <= 0 ? 0 : distance / radius));
  }
}

/// Rueda cromática: el ángulo es el tono y el radio la saturación. El brillo
/// se aplica a todos los colores antes de dibujarlos.
class _ColorWheelPainter extends CustomPainter {
  const _ColorWheelPainter({
    required this.hsv,
    required this.outlineColor,
    required this.selectorColor,
  });

  final HsvColor hsv;
  final Color outlineColor;
  final Color selectorColor;

  static const List<Color> _spectrum = <Color>[
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
    Color(0xFFFF0000),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    final List<Color> shaded = _spectrum
        .map(
          (Color color) => Color.fromRGBO(
            (color.r * hsv.v * 255).round().clamp(0, 255).toInt(),
            (color.g * hsv.v * 255).round().clamp(0, 255).toInt(),
            (color.b * hsv.v * 255).round().clamp(0, 255).toInt(),
            1,
          ),
        )
        .toList(growable: false);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 3 / 2,
          colors: shaded,
        ).createShader(rect),
    );

    // El centro se acerca al gris del brillo elegido (saturación 0).
    final int grey = (hsv.v * 255).round().clamp(0, 255);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Color.fromRGBO(grey, grey, grey, 1),
            Color.fromRGBO(grey, grey, grey, 0),
          ],
          stops: const <double>[0, 1],
        ).createShader(rect),
    );
    canvas.restore();

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = outlineColor
        ..strokeWidth = 1.5,
    );

    final double angle = hsv.h * math.pi / 180 - math.pi / 2;
    final Offset selector =
        center +
        Offset(
          math.cos(angle) * hsv.s * radius,
          math.sin(angle) * hsv.s * radius,
        );
    canvas.drawCircle(
      selector,
      9,
      Paint()
        ..color = selectorColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(selector, 4, Paint()..color = hsv.toColor());
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) =>
      oldDelegate.hsv != hsv ||
      oldDelegate.outlineColor != outlineColor ||
      oldDelegate.selectorColor != selectorColor;
}

/// Canal RGB en bytes, usando los componentes normalizados de Flutter.
int _byte(double channel) => (channel * 255).round().clamp(0, 255).toInt();
