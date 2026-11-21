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

    test('descarta caracteres de control y espacios invisibles', () {
      expect(MetadataText.repair('\u0080Café'), 'Café');
      expect(MetadataText.repair('Café\u00A0Opus'), 'Café Opus');
      expect(MetadataText.repair('Caf\uFEFFé\u200B'), 'Café');
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

    test('cae al respaldo con U+FFFD o su versión mal decodificada', () {
      expect(MetadataText.clean('ï¿½', 'pista-01'), 'pista-01');
      expect(MetadataText.clean('ï¿½Música', 'pista-01'), 'pista-01');
    });

    test('limpia glifos de reemplazo sin perder texto legible', () {
      expect(MetadataText.clean('Café ■', 'pista-01'), 'Café');
      expect(MetadataText.clean('■', 'pista-01'), 'pista-01');
      expect(MetadataText.clean('Café\u00A0Opus', 'pista-01'), 'Café Opus');
    });
  });
}
