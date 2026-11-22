import 'dart:math' as math;
import 'dart:ui';

import '../theme/compact_style_config.dart';

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

  /// Altura/ancho de la franja de la cápsula que queda visible al apartar la
  /// isla hacia cualquiera de los bordes de la pantalla.
  static const double defaultPeekHeight = 12;

  /// Margen longitudinal de la zona de detección (a lo largo del borde).
  static const double peekAlongPadding = 140;

  /// Profundidad de la zona de detección hacia el interior de la pantalla.
  static const double peekDepthPadding = 36;

  /// Pequeño margen fuera de la pantalla para no perder el primer píxel.
  static const double peekEdgeInset = 4;

  /// Posición que debe adoptar la ventana para que solo asoma [visibleHeight]
  /// de la cápsula por el borde elegido. La cápsula está centrada en la
  /// ventana, así que el offset depende de ese centro, no del tamaño total.
  static Offset peekPosition({
    required Offset normalTopLeft,
    required Size windowSize,
    required Size capsuleSize,
    required Rect displayBounds,
    required IslandPeekEdge edge,
    double visibleHeight = defaultPeekHeight,
  }) {
    final double halfWindowWidth = windowSize.width / 2;
    final double halfWindowHeight = windowSize.height / 2;
    final double halfCapsuleWidth = capsuleSize.width / 2;
    final double halfCapsuleHeight = capsuleSize.height / 2;
    return switch (edge) {
      // La cápsula se va arriba: su borde inferior queda a `visibleHeight`.
      IslandPeekEdge.top => Offset(
        normalTopLeft.dx,
        displayBounds.top +
            visibleHeight -
            halfWindowHeight -
            halfCapsuleHeight,
      ),
      // Abajo: su borde superior queda a `visibleHeight` del borde inferior.
      IslandPeekEdge.bottom => Offset(
        normalTopLeft.dx,
        displayBounds.bottom -
            visibleHeight -
            halfWindowHeight +
            halfCapsuleHeight,
      ),
      // Izquierda: su borde derecho queda a `visibleHeight` del borde izquierdo.
      IslandPeekEdge.left => Offset(
        displayBounds.left + visibleHeight - halfWindowWidth - halfCapsuleWidth,
        normalTopLeft.dy,
      ),
      // Derecha: su borde izquierdo queda a `visibleHeight` del borde derecho.
      IslandPeekEdge.right => Offset(
        displayBounds.right -
            visibleHeight -
            halfWindowWidth +
            halfCapsuleWidth,
        normalTopLeft.dy,
      ),
    };
  }

  /// Zona del borde elegido que detecta al usuario acercándose para devolver
  /// la isla. Es más ancha que la ventana para que no haga falta apuntar justo
  /// a la franja visible, pero no cubre toda la pantalla.
  static Rect peekActivationZone({
    required Offset normalTopLeft,
    required Size windowSize,
    required Rect displayBounds,
    required IslandPeekEdge edge,
    double visibleHeight = defaultPeekHeight,
    double alongPadding = peekAlongPadding,
    double depthPadding = peekDepthPadding,
  }) {
    const double inset = peekEdgeInset;
    return switch (edge) {
      IslandPeekEdge.top => Rect.fromLTWH(
        normalTopLeft.dx - alongPadding,
        displayBounds.top - inset,
        windowSize.width + alongPadding * 2,
        visibleHeight + depthPadding,
      ),
      IslandPeekEdge.bottom => Rect.fromLTWH(
        normalTopLeft.dx - alongPadding,
        displayBounds.bottom - visibleHeight - depthPadding + inset,
        windowSize.width + alongPadding * 2,
        visibleHeight + depthPadding,
      ),
      IslandPeekEdge.left => Rect.fromLTWH(
        displayBounds.left - inset,
        normalTopLeft.dy - alongPadding,
        visibleHeight + depthPadding,
        windowSize.height + alongPadding * 2,
      ),
      IslandPeekEdge.right => Rect.fromLTWH(
        displayBounds.right - visibleHeight - depthPadding + inset,
        normalTopLeft.dy - alongPadding,
        visibleHeight + depthPadding,
        windowSize.height + alongPadding * 2,
      ),
    };
  }

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
