import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/equalizer_config.dart';
import '../../../core/theme/app_theme_config.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/frequency_response.dart';

/// Curva de respuesta en frecuencia del ecualizador.
///
/// Se dibuja con un número fijo de muestras (no una por píxel) y solo se
/// repinta cuando cambia la configuración o el estado de bypass. Así el
/// deslizador responde al instante sin reconstruir el reproductor ni el motor.
class EqCurvePainter extends CustomPainter {
  const EqCurvePainter({
    required this.config,
    required this.accent,
    required this.surfaceColor,
    this.active = true,
    this.gridColor = const Color(0x1AFFFFFF),
    this.gridStyle = EqGridStyle.lines,
    this.radius = 14,
  });

  final EqualizerConfig config;
  final Color accent;
  final Color surfaceColor;

  /// `false` cuando el DSP está apagado o en modo puro: la curva se atenúa
  /// para que la UI no muestre un refuerzo que no está sonando.
  final bool active;
  final Color gridColor;
  final EqGridStyle gridStyle;
  final double radius;

  static const double dbSpan = AppConstants.eqMaxGain;
  static const int _curveSamples = 192;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect area = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(area, Radius.circular(radius)),
      Paint()..color = surfaceColor,
    );

    _drawGrid(canvas, size);

    final Color curveColor = active ? accent : accent.withValues(alpha: 0.32);
    final Path line = Path();
    for (int i = 0; i <= _curveSamples; i++) {
      final double x = size.width * i / _curveSamples;
      final double hz = FrequencyResponse.frequencyForX(x, size.width);
      final double y = yForDb(
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
      ..color = curveColor.withValues(alpha: active ? 0.16 : 0.05)
      ..style = PaintingStyle.fill;
    final Path areaPath = Path()
      ..addPath(line, Offset.zero)
      ..lineTo(size.width, yForDb(0, size.height))
      ..lineTo(0, yForDb(0, size.height))
      ..close();
    canvas.drawPath(areaPath, fill);

    canvas.drawPath(
      line,
      Paint()
        ..color = curveColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.25
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (active && config.mode == EqMode.graphic) {
      // Puntos en cada banda con ganancia: sirven de medidor rápido de qué
      // frecuencias están realmente reforzadas o atenuadas.
      final Paint marker = Paint()..color = accent;
      final Paint markerEdge = Paint()..color = surfaceColor;
      final int count = config.bands.length < config.frequencies.length
          ? config.bands.length
          : config.frequencies.length;
      for (int i = 0; i < count; i++) {
        final double gain = config.bands[i];
        if (gain.abs() < 0.05) continue;
        final Offset point = Offset(
          FrequencyResponse.xFor(config.frequencies[i], size.width),
          yForDb(gain, size.height),
        );
        canvas.drawCircle(point, 4.2, markerEdge);
        canvas.drawCircle(point, 2.6, marker);
      }
    }
  }

  /// Rejilla del panel: líneas, puntos, malla densa o sin rejilla según el
  /// lenguaje visual del preset activo.
  void _drawGrid(Canvas canvas, Size size) {
    if (gridStyle == EqGridStyle.none) return;
    final Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final List<double> columns = <double>[
      100,
      1000,
      10000,
    ].map((double hz) => FrequencyResponse.xFor(hz, size.width)).toList();
    final List<double> rows = <double>[
      AppConstants.eqMaxGain,
      0,
      AppConstants.eqMinGain,
    ].map((double db) => yForDb(db, size.height)).toList();

    switch (gridStyle) {
      case EqGridStyle.lines:
        for (final double x in columns) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
        }
        for (final double y in rows) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
        }
      case EqGridStyle.dots:
        for (final double x in columns) {
          for (final double y in rows) {
            canvas.drawCircle(Offset(x, y), 1.6, grid);
          }
        }
      case EqGridStyle.dense:
        const int steps = 16;
        final Paint fine = Paint()
          ..color = gridColor.withValues(alpha: 0.55)
          ..strokeWidth = 0.6;
        for (int i = 1; i < steps; i++) {
          final double x = size.width * i / steps;
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), fine);
        }
        for (int i = 1; i < 8; i++) {
          final double y = size.height * i / 8;
          canvas.drawLine(Offset(0, y), Offset(size.width, y), fine);
        }
      case EqGridStyle.none:
        break;
    }
  }

  static double yForDb(double db, double height) {
    final double clamped = db.clamp(-dbSpan, dbSpan);
    return height / 2 - (clamped / dbSpan) * (height / 2);
  }

  @override
  bool shouldRepaint(covariant EqCurvePainter oldDelegate) =>
      oldDelegate.config != config ||
      oldDelegate.active != active ||
      oldDelegate.accent != accent ||
      oldDelegate.surfaceColor != surfaceColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.gridStyle != gridStyle ||
      oldDelegate.radius != radius;
}

/// Panel con la curva, la escala en dB y las etiquetas de frecuencia.
class EqCurveView extends StatelessWidget {
  const EqCurveView({super.key, required this.config, this.active = true});

  final EqualizerConfig config;
  final bool active;

  @override
  Widget build(BuildContext context) {
    // Las etiquetas viven fuera del painter: reciben la tinta del tema aquí.
    final Color labelColor = context.inkAlpha(0.54);
    final DesignLanguage language = context.tokens.designLanguage;
    const double height = 128;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Stack(
          children: <Widget>[
            SizedBox(
              height: height,
              child: CustomPaint(
                painter: EqCurvePainter(
                  config: config,
                  accent: context.tokens.accent,
                  surfaceColor: context.tokens.panelColor,
                  gridColor: context.inkAlpha(0.12),
                  gridStyle: language.eqGrid,
                  radius: language.tileRadius,
                  active: active,
                ),
              ),
            ),
            for (final double db in <double>[
              AppConstants.eqMaxGain,
              0,
              AppConstants.eqMinGain,
            ])
              Positioned(
                left: 6,
                top: (EqCurvePainter.yForDb(db, height) - 6)
                    .clamp(0.0, 116.0)
                    .toDouble(),
                child: Text(
                  db > 0
                      ? '+12 dB'
                      : db == 0
                      ? '0'
                      : '-12 dB',
                  style: TextStyle(fontSize: 9, color: labelColor),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // Etiquetas colocadas sobre la misma escala logarítmica que la curva:
        // una fila de celdas equalizadas ponía "1 kHz" lejos de la rejilla.
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const List<double> marks = <double>[20, 100, 1000, 10000, 20000];
            const List<String> labels = <String>[
              '20 Hz',
              '100 Hz',
              '1 kHz',
              '10 kHz',
              '20 kHz',
            ];
            return SizedBox(
              height: 12,
              child: Stack(
                children: <Widget>[
                  for (int i = 0; i < marks.length; i++)
                    Positioned(
                      left: FrequencyResponse.xFor(
                        marks[i],
                        constraints.maxWidth,
                      ),
                      child: FractionalTranslation(
                        translation: Offset(
                          i == 0
                              ? 0
                              : i == marks.length - 1
                              ? -1
                              : -0.5,
                          0,
                        ),
                        child: Text(
                          labels[i],
                          style: TextStyle(fontSize: 9, color: labelColor),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
