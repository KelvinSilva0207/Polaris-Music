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

  static Future<Directory> artwork() => _sub('artwork');

  static Future<Directory> backups() => _sub('backups');

  static Future<Directory> lyrics() => _sub('lyrics');

  static Future<Directory> downloads() async {
    // Descargas del updater: junto al resto de datos para no pedir permisos
    // extra de almacenamiento. En escritorio se puede abrir la carpeta.
    return _sub('downloads');
  }

  static Future<Directory> _sub(String name) async {
    final Directory base = await root();
    final Directory dir = Directory(p.join(base.path, name));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
