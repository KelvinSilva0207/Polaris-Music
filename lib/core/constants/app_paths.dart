import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Rutas de datos de la aplicación (carátulas, backups, letras).
class AppPaths {
  AppPaths._();

  static Directory? _root;

  static Future<Directory> root() async {
    final Directory? cached = _root;
    if (cached != null) return cached;

    final Directory base = await getApplicationSupportDirectory();
    final Directory dir = Directory(p.join(base.path, 'polaris_music'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _root = dir;
    return dir;
  }

  static Directory? _artworkDir;

  static Future<Directory> artwork() async {
    final Directory dir = await _sub('artwork');
    _artworkDir = dir;
    return dir;
  }

  /// Ruta del caché ya resuelta tras el bootstrap; permite recuperar carátulas
  /// sin volver a pedir `path_provider` desde el modelo de pista.
  static String? get artworkPathSync => _artworkDir?.path;

  static Future<Directory> backups() => _sub('backups');

  static Future<Directory> lyrics() => _sub('lyrics');

  /// Copias internas de las fuentes importadas por el usuario.
  ///
  /// Viven junto al resto de datos de la app: si el archivo original se mueve
  /// o se borra, Polaris sigue teniendo su propia copia para registrar la
  /// familia en cada arranque.
  static Future<Directory> fonts() => _sub('fonts');

  static Future<Directory> downloads() async {
    // Descargas del updater: junto al resto de datos para no pedir permisos
    // extra de almacenamiento. En escritorio se puede abrir la carpeta.
    return _sub('downloads');
  }

  /// Pistas descargadas desde el catálogo online.
  ///
  /// Vive en la carpeta de datos de la app para no requerir permisos extra en
  /// Android; la biblioteca las registra en Drift y las muestra al instante.
  static Future<Directory> music() => _sub(p.join('downloads', 'music'));

  static Future<Directory> _sub(String name) async {
    final Directory base = await root();
    final Directory dir = Directory(p.join(base.path, name));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
