import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/equalizer_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/frequency_response.dart';

/// Curva de respuesta en frecuencia del ecualizador.
///
/// Se recalcula en cada `paint`, así que refleja al instante el arrastre de
/// cualquier deslizador sin necesidad de reconstruir el reproductor.
class EqCurvePainter extends CustomPainter {
  const EqCurvePainter({
    required this.config,
    required this.accent,
    this.gridColor = const Color(0x1AFFFFFF),
  });

  final EqualizerConfig config;
  final Color accent;
  final Color gridColor;

  static const double _dbSpan = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect area = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(area, const Radius.circular(14)),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    final Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final double hz in <double>[100, 1000, 10000]) {
      final double x = FrequencyResponse.xFor(hz, size.width);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (final double db in <double>[
      AppConstants.eqMaxGain,
      0,
      AppConstants.eqMinGain,
    ]) {
      final double y = _yFor(db, size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final Path line = Path();
    final int steps = size.width <= 0 ? 1 : size.width.round();
    for (int i = 0; i <= steps; i++) {
      final double x = i.toDouble();
      final double hz = FrequencyResponse.frequencyForX(x, size.width);
      final double y = _yFor(
        FrequencyResponse.dbAt(frequencyHz: hz, config: config),
        size.height,
      );
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }

    final Paint fill = Paint()
      ..color = accent.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final Path areaPath = Path()
      ..addPath(line, Offset.zero)
      ..lineTo(size.width, _yFor(0, size.height))
      ..lineTo(0, _yFor(0, size.height))
      ..close();
    canvas.drawPath(areaPath, fill);

    canvas.drawPath(
      line,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.25
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  static double _yFor(double db, double height) {
    final double clamped = db.clamp(-_dbSpan, _dbSpan);
    return height / 2 - (clamped / _dbSpan) * (height / 2);
  }

  @override
  bool shouldRepaint(covariant EqCurvePainter oldDelegate) =>
      oldDelegate.config != config ||
      oldDelegate.accent != accent ||
      oldDelegate.gridColor != gridColor;
}

/// Panel con la curva y sus etiquetas de frecuencia.
class EqCurveView extends StatelessWidget {
  const EqCurveView({super.key, required this.config});

  final EqualizerConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 128,
          child: CustomPaint(
            painter: EqCurvePainter(
              config: config,
              accent: context.tokens.accent,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const <Widget>[
            Text('20', style: TextStyle(fontSize: 10, color: Colors.white38)),
            Text('100', style: TextStyle(fontSize: 10, color: Colors.white38)),
            Text('1k', style: TextStyle(fontSize: 10, color: Colors.white38)),
            Text('10k', style: TextStyle(fontSize: 10, color: Colors.white38)),
            Text('20k', style: TextStyle(fontSize: 10, color: Colors.white38)),
          ],
        ),
      ],
    );
  }
}
