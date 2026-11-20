import 'dart:math' as math;
import 'dart:ui';

/// Geometría de la región de la ventana cuando la app se convierte en isla.
///
/// Windows recorta tanto el dibujo como el área que recibe clics a la región
/// de la ventana (`SetWindowRgn`). La cápsula la dibuja Flutter con su propio
/// borde y sombra; aquí solo calculamos un rectángulo redondeado concéntrico
/// que la envuelve con un pequeño margen para no cortar el resplandor.
abstract final class IslandShape {
  /// Margen alrededor de la cápsula reservado para la sombra de
  /// `CompactPanel` (blur de hasta 26 px en el tema actual).
  static const double shadowPadding = 18;

  /// Puntos por esquina. 8 es suficiente para que el arco se vea redondo y
  /// mantiene la región ligera (36 puntos para la cápsula completa).
  static const int segmentsPerCorner = 8;

  /// Devuelve los vértices, en píxeles lógicos y relativos al área cliente,
  /// de la región que debe adoptar la ventana de la isla.
  static List<Offset> points({
    required Size windowSize,
    required Size capsuleSize,
    required double radius,
  }) {
    // Nunca sobrepasamos el tamaño de la ventana: `SetWindowRgn` no dibuja
    // fuera de ella y unos puntos extra solo añadirían coste.
    final double halfWidth = math.min(
      capsuleSize.width / 2 + shadowPadding,
      windowSize.width / 2,
    );
    final double halfHeight = math.min(
      capsuleSize.height / 2 + shadowPadding,
      windowSize.height / 2,
    );
    // Flutter limita el radio de `ClipRRect` a la mitad de la altura, así que
    // la región usa la misma regla antes de añadir el margen de sombra.
    final double capsuleRadius = math.min(
      math.max(radius, 0),
      capsuleSize.height / 2,
    );
    final double outerRadius = math.min(
      capsuleRadius + shadowPadding,
      math.min(halfWidth, halfHeight),
    );

    final Rect rect = Rect.fromCenter(
      center: Offset(windowSize.width / 2, windowSize.height / 2),
      width: halfWidth * 2,
      height: halfHeight * 2,
    );
    final double left = rect.left;
    final double top = rect.top;
    final double right = rect.right;
    final double bottom = rect.bottom;

    final List<Offset> result = <Offset>[];
    for (int corner = 0; corner < 4; corner++) {
      final double centerX = corner == 0 || corner == 1
          ? right - outerRadius
          : left + outerRadius;
      final double centerY = corner == 0 || corner == 3
          ? top + outerRadius
          : bottom - outerRadius;
      final double start = math.pi * (-0.5 + corner * 0.5);
      for (int step = 0; step <= segmentsPerCorner; step++) {
        final double angle = start + (math.pi / 2) * (step / segmentsPerCorner);
        result.add(
          Offset(
            centerX + outerRadius * math.cos(angle),
            centerY + outerRadius * math.sin(angle),
          ),
        );
      }
    }
    return result;
  }
}
