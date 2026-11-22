import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/services/island_shape.dart';
import 'package:polaris_music/core/services/window_service.dart';

void main() {
  group('IslandShape (región de la isla en Windows)', () {
    test(
      'la cápsula compacta cabe en la ventana con margen para la sombra',
      () {
        final List<Offset> points = IslandShape.points(
          windowSize: WindowService.islandSize,
          capsuleSize: WindowService.islandCompactCapsule,
          radius: WindowService.islandDefaultRadius,
        );

        expect(points, hasLength(4 * (IslandShape.segmentsPerCorner + 1)));
        for (final Offset point in points) {
          expect(point.dx, greaterThanOrEqualTo(0));
          expect(point.dx, lessThanOrEqualTo(WindowService.islandSize.width));
          expect(point.dy, greaterThanOrEqualTo(0));
          expect(point.dy, lessThanOrEqualTo(WindowService.islandSize.height));
        }

        final double minX = points
            .map((Offset p) => p.dx)
            .reduce((a, b) => a < b ? a : b);
        final double maxX = points
            .map((Offset p) => p.dx)
            .reduce((a, b) => a > b ? a : b);
        final double minY = points
            .map((Offset p) => p.dy)
            .reduce((a, b) => a < b ? a : b);
        final double maxY = points
            .map((Offset p) => p.dy)
            .reduce((a, b) => a > b ? a : b);

        // 196 x 64 + 18 px de sombra por lado = 232 x 100, centrados en 400 x 128.
        expect(maxX - minX, closeTo(232, 0.01));
        expect(maxY - minY, closeTo(100, 0.01));
        expect((minX + maxX) / 2, closeTo(200, 0.01));
        expect((minY + maxY) / 2, closeTo(64, 0.01));
      },
    );

    test('la cápsula expandida no sobrepasa el tamaño de la ventana', () {
      final List<Offset> points = IslandShape.points(
        windowSize: WindowService.islandSize,
        capsuleSize: WindowService.islandExpandedCapsule,
        radius: WindowService.islandDefaultRadius,
      );

      for (final Offset point in points) {
        expect(point.dx, inInclusiveRange(0, WindowService.islandSize.width));
        expect(point.dy, inInclusiveRange(0, WindowService.islandSize.height));
      }
    });

    test('un radio enorme se limita al de la píldora y al de la ventana', () {
      final List<Offset> points = IslandShape.points(
        windowSize: WindowService.islandSize,
        capsuleSize: WindowService.islandCompactCapsule,
        radius: 500,
      );

      // Un radio mayor que la mitad de la altura de la cápsula (32) más el
      // margen (18) no debe sacar ningún punto del rectángulo interior.
      for (final Offset point in points) {
        expect(point.dx, inInclusiveRange(84, 316));
        expect(point.dy, inInclusiveRange(14, 114));
      }
    });

    test('al apartarse solo asoma la franja inferior de la cápsula', () {
      final double top = IslandShape.peekTop(
        windowTop: 0,
        windowHeight: WindowService.islandSize.height,
        capsuleHeight: WindowService.islandCompactCapsule.height,
      );
      final double capsuleBottom =
          top +
          (WindowService.islandSize.height +
                  WindowService.islandCompactCapsule.height) /
              2;

      expect(top, closeTo(-84, 0.01));
      expect(capsuleBottom, closeTo(IslandShape.defaultPeekHeight, 0.01));
    });

    test('la zona del borde cubre la isla sin abarcar toda la pantalla', () {
      // Ventana centrada arriba en una pantalla hipotética de 1000 px.
      final Rect zone = IslandShape.peekActivationZone(
        windowLeft: 300,
        windowTop: 0,
        windowWidth: WindowService.islandSize.width,
      );

      expect(zone.left, 160);
      expect(zone.right, 840);
      expect(zone.top, -4);
      expect(zone.bottom, IslandShape.defaultPeekHeight + 36 - 4);
      expect(zone.contains(const Offset(500, 10)), isTrue);
      expect(zone.contains(const Offset(500, 120)), isFalse);
      expect(zone.contains(const Offset(50, 10)), isFalse);
    });
  });
}
