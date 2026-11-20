import 'package:flutter_test/flutter_test.dart';

import 'package:polaris_music/core/utils/metadata_text.dart';

void main() {
  group('MetadataText.repair', () {
    test('repara UTF-8 leído como Latin-1', () {
      expect(MetadataText.repair('MÃºsica'), 'Música');
      expect(MetadataText.repair('CafÃ©'), 'Café');
      expect(MetadataText.repair('Rock Â©'), 'Rock ©');
    });

    test('repara secuencias CP1252 como â€™', () {
      expect(MetadataText.repair('Rock â€™ roll'), 'Rock ’ roll');
    });

    test('repara doble mojibake', () {
      expect(MetadataText.repair('ÃƒÂ©'), 'é');
    });

    test('no altera texto correcto', () {
      expect(MetadataText.repair('Café'), 'Café');
      expect(MetadataText.repair('Rock ’ roll'), 'Rock ’ roll');
      expect(MetadataText.repair('Desconocido'), 'Desconocido');
    });
  });

  group('MetadataText.clean', () {
    test('usa el fallback cuando no queda texto', () {
      expect(MetadataText.clean(null, 'pista-01'), 'pista-01');
      expect(MetadataText.clean('', 'pista-01'), 'pista-01');
      expect(MetadataText.clean('\x00   ', 'pista-01'), 'pista-01');
      expect(MetadataText.clean('\uFFFDtexto', 'pista-01'), 'pista-01');
    });

    test('repara antes de aplicar el fallback', () {
      expect(MetadataText.clean('MÃºsica', 'pista-01'), 'Música');
    });

    test('conserva el fallback Desconocido de la base de datos', () {
      expect(MetadataText.clean('', 'Desconocido'), 'Desconocido');
      expect(MetadataText.clean('Desconocido', 'pista-01'), 'Desconocido');
    });
  });
}
