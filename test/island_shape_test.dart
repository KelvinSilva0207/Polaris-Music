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
  });
}
