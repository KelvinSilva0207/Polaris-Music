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

  /// Altura de la franja de la cápsula que queda visible al apartar la isla
  /// hacia el borde superior de la pantalla.
  static const double defaultPeekHeight = 12;

  /// Posición Y que debe adoptar la ventana para que solo asome la parte
  /// inferior de la cápsula. La cápsula está centrada dentro de la ventana,
  /// así que su borde inferior queda en `(windowHeight + capsuleHeight) / 2`.
  static double peekTop({
    required double windowTop,
    required double windowHeight,
    required double capsuleHeight,
    double visibleHeight = defaultPeekHeight,
  }) => windowTop - ((windowHeight + capsuleHeight) / 2 - visibleHeight);

  /// Zona del borde superior que detecta al usuario acercándose para devolver
  /// la isla. Es más ancha que la ventana para que no haga falta apuntar justo
  /// a la franja visible.
  static Rect peekActivationZone({
    required double windowLeft,
    required double windowTop,
    required double windowWidth,
    double visibleHeight = defaultPeekHeight,
    double horizontalPadding = 140,
    double verticalPadding = 36,
  }) => Rect.fromLTWH(
    windowLeft - horizontalPadding,
    windowTop - 4,
    windowWidth + horizontalPadding * 2,
    visibleHeight + verticalPadding,
  );

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
