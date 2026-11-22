import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/services/island_shape.dart';
import 'package:polaris_music/core/services/window_service.dart';
import 'package:polaris_music/core/theme/compact_style_config.dart';

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

    test('cada borde deja asomar solo la franja elegida de la cápsula', () {
      // Ventana centrada arriba en un área de trabajo de 1000 x 800.
      const Offset normal = Offset(300, 0);
      const Rect display = Rect.fromLTWH(0, 0, 1000, 800);
      final Size windowSize = WindowService.islandSize;
      final Size capsule = WindowService.islandCompactCapsule;

      final Offset top = IslandShape.peekPosition(
        normalTopLeft: normal,
        windowSize: windowSize,
        capsuleSize: capsule,
        displayBounds: display,
        edge: IslandPeekEdge.top,
      );
      expect(top.dx, 300);
      expect(top.dy, closeTo(-84, 0.01));
      expect(
        top.dy + (windowSize.height + capsule.height) / 2,
        closeTo(IslandShape.defaultPeekHeight, 0.01),
      );

      final Offset bottom = IslandShape.peekPosition(
        normalTopLeft: normal,
        windowSize: windowSize,
        capsuleSize: capsule,
        displayBounds: display,
        edge: IslandPeekEdge.bottom,
      );
      expect(bottom.dx, 300);
      expect(
        bottom.dy + (windowSize.height - capsule.height) / 2,
        closeTo(display.bottom - IslandShape.defaultPeekHeight, 0.01),
      );

      final Offset left = IslandShape.peekPosition(
        normalTopLeft: normal,
        windowSize: windowSize,
        capsuleSize: capsule,
        displayBounds: display,
        edge: IslandPeekEdge.left,
      );
      expect(left.dy, 0);
      expect(
        left.dx + (windowSize.width + capsule.width) / 2,
        closeTo(IslandShape.defaultPeekHeight, 0.01),
      );

      final Offset right = IslandShape.peekPosition(
        normalTopLeft: normal,
        windowSize: windowSize,
        capsuleSize: capsule,
        displayBounds: display,
        edge: IslandPeekEdge.right,
      );
      expect(right.dy, 0);
      expect(
        right.dx + (windowSize.width - capsule.width) / 2,
        closeTo(display.right - IslandShape.defaultPeekHeight, 0.01),
      );
    });

    test(
      'la zona de cada borde cubre la franja sin abarcar toda la pantalla',
      () {
        const Offset normal = Offset(300, 0);
        const Rect display = Rect.fromLTWH(0, 0, 1000, 800);
        final Size windowSize = WindowService.islandSize;

        final Rect top = IslandShape.peekActivationZone(
          normalTopLeft: normal,
          windowSize: windowSize,
          displayBounds: display,
          edge: IslandPeekEdge.top,
        );
        expect(top.left, 160);
        expect(top.right, 840);
        expect(top.top, -4);
        expect(top.bottom, 44);

        final Rect bottom = IslandShape.peekActivationZone(
          normalTopLeft: normal,
          windowSize: windowSize,
          displayBounds: display,
          edge: IslandPeekEdge.bottom,
        );
        expect(bottom.left, 160);
        expect(bottom.right, 840);
        expect(bottom.top, 756);
        expect(bottom.bottom, 804);

        final Rect left = IslandShape.peekActivationZone(
          normalTopLeft: normal,
          windowSize: windowSize,
          displayBounds: display,
          edge: IslandPeekEdge.left,
        );
        expect(left.left, -4);
        expect(left.right, 44);
        expect(left.top, -140);
        expect(left.bottom, 268);

        final Rect right = IslandShape.peekActivationZone(
          normalTopLeft: normal,
          windowSize: windowSize,
          displayBounds: display,
          edge: IslandPeekEdge.right,
        );
        expect(right.left, 956);
        expect(right.right, 1004);
        expect(right.top, -140);
        expect(right.bottom, 268);

        expect(top.contains(const Offset(500, 10)), isTrue);
        expect(top.contains(const Offset(500, 120)), isFalse);
        expect(left.contains(const Offset(10, 20)), isTrue);
        expect(right.contains(const Offset(990, 20)), isTrue);
        expect(bottom.contains(const Offset(500, 790)), isTrue);
        expect(left.contains(const Offset(500, 20)), isFalse);
      },
    );
  });

  group('IslandShape (isla apartada legible)', () {
    const Offset normal = Offset(300, 0);
    const Rect display = Rect.fromLTWH(0, 0, 1000, 800);

    for (final IslandPeekEdge edge in IslandPeekEdge.values) {
      test('${edge.name}: la cápsula sigue completamente en pantalla', () {
        final Size windowSize = WindowService.islandSize;
        final Size capsule = WindowService.islandCompactCapsule;
        final double visible = IslandShape.visibleSpan(
          edge: edge,
          capsuleSize: capsule,
        );
        final Offset position = IslandShape.peekPosition(
          normalTopLeft: normal,
          windowSize: windowSize,
          capsuleSize: capsule,
          displayBounds: display,
          edge: edge,
          visibleHeight: visible,
        );
        final Rect capsuleRect = Rect.fromLTWH(
          position.dx + (windowSize.width - capsule.width) / 2,
          position.dy + (windowSize.height - capsule.height) / 2,
          capsule.width,
          capsule.height,
        );

        expect(display.contains(capsuleRect.topLeft), isTrue);
        expect(display.contains(capsuleRect.bottomRight), isTrue);
      });
    }

    test('visibleSpan usa el lado de la cápsula y respeta el mínimo', () {
      final Size capsule = WindowService.islandCompactCapsule;
      expect(
        IslandShape.visibleSpan(edge: IslandPeekEdge.top, capsuleSize: capsule),
        closeTo(capsule.height + 8, 0.01),
      );
      expect(
        IslandShape.visibleSpan(
          edge: IslandPeekEdge.left,
          capsuleSize: capsule,
        ),
        closeTo(capsule.width + 8, 0.01),
      );
      expect(
        IslandShape.visibleSpan(
          edge: IslandPeekEdge.top,
          capsuleSize: capsule,
          minimum: 500,
        ),
        500,
      );
    });
  });
}
