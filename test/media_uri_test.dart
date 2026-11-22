import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_music/core/utils/media_uri.dart';

void main() {
  group('normalizeMediaUri', () {
    test('convierte las barras de una ruta de Windows en barras normales', () {
      expect(
        normalizeMediaUri(r'C:\Music\cancion.mp3'),
        'C:/Music/cancion.mp3',
      );
    });

    test('no altera rutas POSIX ni URLs remotas', () {
      expect(
        normalizeMediaUri('/home/Usuario/music/song.mp3'),
        '/home/Usuario/music/song.mp3',
      );
      expect(
        normalizeMediaUri('https://ejemplo.com/audio/cancion.mp3'),
        'https://ejemplo.com/audio/cancion.mp3',
      );
    });

    test('Track.path y Media.uri coinciden tras normalizar', () {
      const String trackPath = r'C:\Music\cancion.mp3';
      const String mediaUri = 'C:/Music/cancion.mp3';

      expect(normalizeMediaUri(trackPath), normalizeMediaUri(mediaUri));
    });
  });
}
